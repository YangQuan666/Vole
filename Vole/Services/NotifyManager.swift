//
//  NotifyManager.swift
//  Vole
//
//  Created by 杨权 on 11/19/25.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class NotifyManager: ObservableObject {
    static let shared = NotifyManager()

    private struct PendingRefreshPayload {
        let notifications: [Notification]
        let totalCount: Int
        let newCount: Int
    }

    private struct NotificationCache: Codable {
        let notifications: [Notification]
        let totalCount: Int
        let latestTotalCount: Int?
        let currentPage: Int
        let endIndex: Int
    }

    @Published var notifications: [Notification] = []
    @Published var totalCount: Int = 0
    @Published private var latestTotalCount: Int = 0
    @Published private(set) var readIds: Set<Int> = []
    @Published private(set) var hasPendingRefresh = false
    @Published private(set) var pendingNewCount = 0

    // 一键已读时的水位线 ID 和 当时的总数
    @Published private(set) var lastReadAllId: Int = 0
    @Published private(set) var allReadTotalCount: Int = 0

    // --- 分页状态属性 ---
    @Published var currentPage: Int = 1
    @Published var endIndex: Int = 0  // 当前加载到的末尾索引 (即 10 或 20)
    @Published var isLoading: Bool = false  // 是否正在加载中，用于防止重复请求

    private let readStateStore = NotificationReadStateStore()

    private let cacheDirectoryName = "NotificationCache"
    private var pollingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()  // 用于存放订阅对象
    private var pendingRefreshPayload: PendingRefreshPayload?
    private var isAppActive = true
    private var isNotificationServiceActive = false
    private var loadedCacheAccountID: String?
    private var activeReadStateAccountID: String?
    private var notificationServiceAccountID: String?

    private var canLoadNotifications: Bool {
        UserManager.shared.didValidateStoredToken
            && UserManager.shared.currentMember != nil
            && UserManager.shared.token?.token?.isEmpty == false
    }

    private init() {
        switchReadState(to: Self.readStateAccountID(for: UserManager.shared.currentMember))
        setupAuthListener()
    }

    private func setupAuthListener() {
        Publishers.CombineLatest3(
            UserManager.shared.$currentMember,
            UserManager.shared.$token,
            UserManager.shared.$didValidateStoredToken
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] member, token, didValidateStoredToken in
                guard let self else { return }
                self.switchReadState(to: Self.readStateAccountID(for: member))

                let canLoadNotifications =
                    didValidateStoredToken
                    && member != nil
                    && token?.token?.isEmpty == false

                if canLoadNotifications {
                    self.activateNotificationService()
                } else if didValidateStoredToken || member == nil || token == nil {
                    self.deactivateNotificationService()
                }
            }
            .store(in: &cancellables)
    }

    private func activateNotificationService() {
        guard let accountID = notificationCacheAccountID else { return }

        if isNotificationServiceActive {
            guard notificationServiceAccountID != accountID else { return }
            notificationServiceAccountID = accountID
            notifications = []
            totalCount = 0
            latestTotalCount = 0
            currentPage = 1
            endIndex = 0
            loadedCacheAccountID = nil
            clearPendingRefresh()
            loadCachedNotificationsIfNeeded()
            Task {
                await refresh()
            }
            return
        }

        isNotificationServiceActive = true
        notificationServiceAccountID = accountID
        print("NotifyManager: 认证状态可用，启动服务")
        loadCachedNotificationsIfNeeded()
        startPollingIfNeeded()
        Task {
            await refresh()
        }
    }

    private func deactivateNotificationService() {
        guard isNotificationServiceActive || !notifications.isEmpty
            || totalCount > 0 || latestTotalCount > 0 || hasPendingRefresh
        else { return }

        print("NotifyManager: 认证状态不可用，清理数据")
        isNotificationServiceActive = false
        notificationServiceAccountID = nil
        stopPolling()
        notifications = []
        totalCount = 0
        latestTotalCount = 0
        currentPage = 1
        endIndex = 0
        loadedCacheAccountID = nil
        clearPendingRefresh()
    }

    func updateScenePhase(_ scenePhase: ScenePhase) {
        let isActive = scenePhase == .active
        guard isAppActive != isActive else { return }

        isAppActive = isActive

        if isActive {
            startPollingIfNeeded()
            if canLoadNotifications {
                Task {
                    await pollLatestNotifications()
                }
            }
        } else {
            stopPolling()
        }
    }

    private func startPollingIfNeeded() {
        guard pollingTask == nil else { return }
        guard isAppActive else { return }
        guard canLoadNotifications else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break
                }

                guard !Task.isCancelled else { break }
                await self?.pollLatestNotifications()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    var unreadCount: Int {
        // 1. 先算出一键已读后，新产生了多少条通知
        let newCountSinceAllRead = latestTotalCount - allReadTotalCount

        // 2. 算出一键已读后，用户手动单条点读的数量
        // 注意：只有那些 ID 比水位线大的点读才算有效（水位线下的本来就是已读）
        let manualReadCount = readIds.filter { $0 > lastReadAllId }.count

        // 3. 最终未读 = 差值 - 单点
        return max(0, newCountSinceAllRead - manualReadCount)
    }

    // 单条已读
    func markRead(_ id: Int) {
        // 如果 ID 已经在水位线以下，没必要记录
        guard id > lastReadAllId else { return }
        if !readIds.contains(id) {
            readIds.insert(id)
            save()
        }
    }

    // 一键已读
    func markAllRead() {
        // 1. 记录当前最顶部的 ID 作为水位线
        if let latestId = pendingRefreshPayload?.notifications.first?.id
            ?? notifications.first?.id
        {
            lastReadAllId = latestId
        }

        // 2. 记录当前服务器给出的总数
        allReadTotalCount = latestTotalCount

        // 3. 清空旧的单点已读集合（因为它们已经都在 allReadTotalCount 范围里了）
        readIds.removeAll()

        save()
    }

    func isRead(_ id: Int) -> Bool {
        return id <= lastReadAllId || readIds.contains(id)
    }

    private func save() {
        guard let activeReadStateAccountID else { return }
        readStateStore.save(
            NotificationReadState(
                readIds: readIds,
                lastReadAllId: lastReadAllId,
                allReadTotalCount: allReadTotalCount
            ),
            for: activeReadStateAccountID
        )
    }

    private func switchReadState(to accountID: String?) {
        guard activeReadStateAccountID != accountID else { return }
        activeReadStateAccountID = accountID

        guard let accountID else {
            readIds = []
            lastReadAllId = 0
            allReadTotalCount = 0
            return
        }

        let state = readStateStore.load(for: accountID)
        readIds = state.readIds
        lastReadAllId = state.lastReadAllId
        allReadTotalCount = state.allReadTotalCount
    }

    private static func readStateAccountID(for member: Member?) -> String? {
        guard let member else { return nil }
        if let id = member.id {
            return "id-\(id)"
        }
        return "username-\(member.username.lowercased())"
    }

    // 是否还有下一页数据
    var hasNextPage: Bool {
        // 如果当前加载到的末尾索引小于总数，则有下一页
        // 且 totalCount 必须大于 0
        return totalCount > 0 && endIndex < totalCount
    }

    // 分页加载函数
    /// - Parameter page: 要加载的页码。
    /// - Parameter isRefresh: 是否是刷新（加载第一页）。
    func loadNotifications(page: Int, isRefresh: Bool) async {
        guard canLoadNotifications else { return }
        guard let t = UserManager.shared.token, !isLoading else { return }
        let requestAccountID = notificationCacheAccountID

        isLoading = true
        do {
            let response = try await fetchNotifications(page: page, token: t.token ?? "")
            guard requestAccountID == notificationCacheAccountID else {
                retryForCurrentNotificationAccount(after: requestAccountID)
                return
            }
            isLoading = false

            if let response {
                latestTotalCount = response.totalCount
                if isRefresh {
                    applyRefreshResult(
                        response.notifications,
                        totalCount: response.totalCount
                    )
                } else {
                    self.notifications = NotificationPagination.appendingUnique(
                        response.notifications,
                        to: self.notifications
                    )
                    self.totalCount = response.totalCount
                    self.endIndex = min(self.notifications.count, response.totalCount)
                    self.currentPage = page
                    self.saveNotificationCache()
                }
            }
        } catch {
            guard requestAccountID == notificationCacheAccountID else {
                retryForCurrentNotificationAccount(after: requestAccountID)
                return
            }
            isLoading = false
            print("加载通知失败: \(error)")
        }
    }

    func loadNextPage() async {
        guard hasNextPage && !isLoading else { return }
        await loadNotifications(page: currentPage + 1, isRefresh: false)
    }

    func refresh() async {
        guard !isLoading else { return }
        await loadNotifications(page: 1, isRefresh: true)
    }

    func applyPendingRefresh() {
        guard let pendingRefreshPayload else { return }
        applyRefreshResult(
            pendingRefreshPayload.notifications,
            totalCount: pendingRefreshPayload.totalCount
        )
    }

    private func pollLatestNotifications() async {
        guard canLoadNotifications else { return }
        guard let token = UserManager.shared.token?.token, !isLoading else { return }
        let requestAccountID = notificationCacheAccountID

        isLoading = true
        do {
            let response = try await fetchNotifications(page: 1, token: token)
            guard requestAccountID == notificationCacheAccountID else {
                retryForCurrentNotificationAccount(after: requestAccountID)
                return
            }
            isLoading = false

            guard let response else { return }
            let previousTotalCount = latestTotalCount
            latestTotalCount = response.totalCount

            guard !notifications.isEmpty else {
                applyRefreshResult(
                    response.notifications,
                    totalCount: response.totalCount
                )
                return
            }

            if hasIncomingChanges(response.notifications) {
                pendingRefreshPayload = PendingRefreshPayload(
                    notifications: response.notifications,
                    totalCount: response.totalCount,
                    newCount: pendingNotificationCount(
                        for: response.notifications,
                        incomingTotalCount: response.totalCount,
                        previousTotalCount: previousTotalCount
                    )
                )
                hasPendingRefresh = true
                pendingNewCount = pendingRefreshPayload?.newCount ?? 0
            }
        } catch {
            guard requestAccountID == notificationCacheAccountID else {
                retryForCurrentNotificationAccount(after: requestAccountID)
                return
            }
            isLoading = false
            print("轮询通知失败: \(error)")
        }
    }

    private func retryForCurrentNotificationAccount(after accountID: String?) {
        isLoading = false
        guard accountID != notificationCacheAccountID,
            isNotificationServiceActive,
            canLoadNotifications
        else { return }

        Task {
            await refresh()
        }
    }

    // MARK: - 正则解析逻辑（与之前版本保持一致）
    private func parseMessage(_ message: String) -> (endIndex: Int, totalCount: Int)? {
        // 正则表达式解释：
        // (\d+)-(\d+)\/(\d+) :
        // 捕获组 1 (\d+): Start
        // 捕获组 2 (\d+): End
        // 捕获组 3 (\d+): Total
        let pattern = #"Notifications\s+(\d+)-(\d+)\/(\d+)"#

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = message as NSString
            let results = regex.matches(
                in: message,
                options: [],
                range: NSRange(location: 0, length: nsString.length)
            )

            if let match = results.first, match.numberOfRanges >= 4 {

                // 提取 End
                let endString = nsString.substring(with: match.range(at: 2))
                let totalString = nsString.substring(with: match.range(at: 3))
                if let endCount = Int(endString),
                   let totalCount = Int(totalString) {
                    return (endCount, totalCount)
                }
            }
        } catch {
            print("正则解析出错: \(error)")
        }
        return nil
    }

    private func fetchNotifications(page: Int, token: String) async throws -> (
        notifications: [Notification], totalCount: Int
    )? {
        let response = try await V2exAPI().notifications(page: page, token: token)
        guard let response, response.success else { return nil }

        let notifications = response.result ?? []
        let pageInfo = response.message.flatMap(parseMessage)
        let totalCount = pageInfo?.totalCount
            ?? max(latestTotalCount, max(self.totalCount, notifications.count))

        return (notifications, totalCount)
    }

    private func hasIncomingChanges(_ newNotifications: [Notification]) -> Bool {
        guard !newNotifications.isEmpty else { return false }
        return !Array(notifications.prefix(newNotifications.count)).elementsEqual(newNotifications)
    }

    private func pendingNotificationCount(
        for newNotifications: [Notification],
        incomingTotalCount: Int,
        previousTotalCount: Int
    ) -> Int {
        let existingIDs = Set(notifications.map(\.id))
        let insertedCount = newNotifications.filter { !existingIDs.contains($0.id) }.count
        let totalDelta = max(0, incomingTotalCount - previousTotalCount)
        return max(insertedCount, totalDelta)
    }

    private func clearPendingRefresh() {
        pendingRefreshPayload = nil
        hasPendingRefresh = false
        pendingNewCount = 0
    }

    private func applyRefreshResult(
        _ newNotifications: [Notification],
        totalCount: Int
    ) {
        clearPendingRefresh()

        let uniqueIncoming = NotificationPagination.appendingUnique(
            newNotifications,
            to: []
        )
        let incomingIds = Set(uniqueIncoming.map(\.id))
        let preservedOlderNotifications = notifications.filter {
            !incomingIds.contains($0.id)
        }

        notifications = NotificationPagination.appendingUnique(
            preservedOlderNotifications,
            to: uniqueIncoming
        )
        self.totalCount = totalCount
        latestTotalCount = totalCount

        let loadedCount = min(notifications.count, totalCount)
        endIndex = loadedCount

        currentPage = NotificationPagination.lastFullyLoadedPage(
            loadedCount: loadedCount,
            pageSize: newNotifications.count
        )
        saveNotificationCache()
    }

    private func loadCachedNotificationsIfNeeded() {
        guard notifications.isEmpty else { return }
        guard let accountID = notificationCacheAccountID else { return }
        guard loadedCacheAccountID != accountID else { return }

        loadedCacheAccountID = accountID

        guard let cacheURL = notificationCacheURL(for: accountID) else { return }

        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }

        do {
            let data = try Data(contentsOf: cacheURL)
            let cache = try JSONDecoder().decode(NotificationCache.self, from: data)
            notifications = cache.notifications
            totalCount = cache.totalCount
            latestTotalCount = cache.latestTotalCount ?? cache.totalCount
            currentPage = max(1, cache.currentPage)
            endIndex = min(cache.endIndex, cache.totalCount)
        } catch {
            print("读取通知缓存失败: \(error)")
        }
    }

    private func saveNotificationCache() {
        guard let accountID = notificationCacheAccountID else { return }
        guard let cacheURL = notificationCacheURL(for: accountID) else { return }

        let cache = NotificationCache(
            notifications: notifications,
            totalCount: totalCount,
            latestTotalCount: latestTotalCount,
            currentPage: currentPage,
            endIndex: endIndex
        )

        do {
            let data = try JSONEncoder().encode(cache)
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            print("保存通知缓存失败: \(error)")
        }
    }

    private var notificationCacheAccountID: String? {
        guard let member = UserManager.shared.currentMember else { return nil }
        if let id = member.id {
            return "id-\(id)"
        }
        return "username-\(member.username)"
    }

    private func notificationCacheURL(for accountID: String) -> URL? {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let fileName = accountID.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()

        return applicationSupportURL
            .appendingPathComponent(cacheDirectoryName, isDirectory: true)
            .appendingPathComponent("\(fileName).json")
    }
}

enum NotificationPagination {
    static func lastFullyLoadedPage(loadedCount: Int, pageSize: Int) -> Int {
        max(1, loadedCount / max(pageSize, 1))
    }

    static func appendingUnique(
        _ page: [Notification],
        to notifications: [Notification]
    ) -> [Notification] {
        var knownIDs = Set<Int>()
        return (notifications + page).filter { knownIDs.insert($0.id).inserted }
    }
}

struct NotificationReadState: Codable, Equatable {
    var readIds: Set<Int> = []
    var lastReadAllId = 0
    var allReadTotalCount = 0
}

struct NotificationReadStateStore {
    private let defaults: UserDefaults

    private let legacyReadIdsKey = "read_notification_ids"
    private let legacyLastReadAllIdKey = "last_read_all_id"
    private let legacyAllReadTotalCountKey = "all_read_total_count"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(for accountID: String) -> NotificationReadState {
        let legacyKeys = [
            legacyReadIdsKey,
            legacyLastReadAllIdKey,
            legacyAllReadTotalCountKey,
        ]
        if legacyKeys.contains(where: { defaults.object(forKey: $0) != nil }) {
            for legacyKey in legacyKeys {
                defaults.removeObject(forKey: legacyKey)
            }
        }

        let key = storageKey(for: accountID)
        if let data = defaults.data(forKey: key),
            let state = try? JSONDecoder().decode(
                NotificationReadState.self,
                from: data
            )
        {
            return state
        }

        return NotificationReadState()
    }

    func save(_ state: NotificationReadState, for accountID: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey(for: accountID))
    }

    private func storageKey(for accountID: String) -> String {
        "notification_read_state_v1.\(accountID)"
    }
}
