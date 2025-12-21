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

    @Published var notifications: [Notification] = []
    @Published var totalCount: Int = 0
    @Published private(set) var readIds: Set<Int> = []

    // 一键已读时的水位线 ID 和 当时的总数
    @Published private(set) var lastReadAllId: Int = 0
    @Published private(set) var allReadTotalCount: Int = 0

    // --- 分页状态属性 ---
    @Published var currentPage: Int = 1
    @Published var endIndex: Int = 0  // 当前加载到的末尾索引 (即 10 或 20)
    @Published var isLoading: Bool = false  // 是否正在加载中，用于防止重复请求

    private let keyReadIds = "read_notification_ids"
    private let keyLastReadId = "last_read_all_id"
    private let keyAllReadTotal = "all_read_total_count"

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()  // 用于存放订阅对象

    private init() {
        // 读取已读集合
        if let stored = UserDefaults.standard.array(forKey: keyReadIds)
            as? [Int]
        {
            readIds = Set(stored)
        }
        // 读取水位线
        lastReadAllId = UserDefaults.standard.integer(forKey: keyLastReadId)
        allReadTotalCount = UserDefaults.standard.integer(
            forKey: keyAllReadTotal
        )

        setupAuthListener()
    }

    private func setupAuthListener() {
        UserManager.shared.$currentMember
            .receive(on: RunLoop.main)
            .sink { [weak self] member in
                if member != nil {
                    // 1. 用户登录了：启动定时器，并立即刷新一次数据
                    print("NotifyManager: 检测到登录，启动服务")
                    self?.startTimer()
                    Task {
                        await self?.refresh()
                    }
                } else {
                    // 2. 用户登出了：停止定时器，清空旧数据
                    print("NotifyManager: 检测到登出，清理数据")
                    self?.stopTimer()
                    self?.notifications = []
                    self?.totalCount = 0
                }
            }
            .store(in: &cancellables)
    }

    // 启动定时器
    func startTimer() {
        // 先停止旧的，防止重复
        stopTimer()

        // 前置判断：如果用户未登录，直接返回，不启动定时器
        guard UserManager.shared.currentMember != nil else { return }
        // 每 60 秒执行一次
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                // 定时刷新通常只刷新第一页
                await self?.refresh()
            }
        }
    }

    // 停止定时器
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    var unreadCount: Int {
        // 1. 先算出一键已读后，新产生了多少条通知
        let newCountSinceAllRead = totalCount - allReadTotalCount

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
        if let latestId = notifications.first?.id {
            lastReadAllId = latestId
        }

        // 2. 记录当前服务器给出的总数
        allReadTotalCount = totalCount

        // 3. 清空旧的单点已读集合（因为它们已经都在 allReadTotalCount 范围里了）
        readIds.removeAll()

        save()
    }

    func isRead(_ id: Int) -> Bool {
        return id <= lastReadAllId || readIds.contains(id)
    }

    private func save() {
        UserDefaults.standard.set(Array(readIds), forKey: keyReadIds)
        UserDefaults.standard.set(lastReadAllId, forKey: keyLastReadId)
        UserDefaults.standard.set(allReadTotalCount, forKey: keyAllReadTotal)
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
        guard let t = UserManager.shared.token, !isLoading else { return }

        isLoading = true
        do {
            let response = try await V2exAPI().notifications(
                page: page,
                token: t.token ?? ""
            )
            isLoading = false

            if let r = response, r.success {
                if let newNotifications = r.result {
                    if isRefresh {
                        self.notifications = newNotifications
                    } else {
                        self.notifications.append(contentsOf: newNotifications)
                    }
                }
                if let msg = r.message {
                    self.parseMessage(msg)
                }
                self.currentPage = page
            }
        } catch {
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
        self.currentPage = 1
        self.endIndex = 0
        await loadNotifications(page: 1, isRefresh: true)
    }

    // MARK: - 正则解析逻辑（与之前版本保持一致）
    private func parseMessage(_ message: String) {
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
                if let endCount = Int(endString) {
                    self.endIndex = endCount
                }

                // 提取 Total
                let totalString = nsString.substring(with: match.range(at: 3))
                if let totalCount = Int(totalString) {
                    self.totalCount = totalCount
                }
            }
        } catch {
            print("正则解析出错: \(error)")
        }
    }
}
