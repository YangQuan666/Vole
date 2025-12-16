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

    // --- 分页状态属性 ---
    @Published var currentPage: Int = 1
    @Published var endIndex: Int = 0  // 当前加载到的末尾索引 (即 10 或 20)
    @Published var isLoading: Bool = false  // 是否正在加载中，用于防止重复请求

    private let key = "read_notification_ids"
    private let pageSize = 10

    private init() {
        if let stored = UserDefaults.standard.array(forKey: key) as? [Int] {
            readIds = Set(stored)
        }
    }

    var unreadCount: Int {
        let count = totalCount - readIds.count
        return max(0, count)
    }

    func markRead(_ id: Int) {
        if !readIds.contains(id) {
            readIds.insert(id)
            save()
        }
    }

    func isRead(_ id: Int) -> Bool {
        readIds.contains(id)
    }

    private func save() {
        UserDefaults.standard.set(Array(readIds), forKey: key)
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

            await MainActor.run {
                isLoading = false

                if let r = response, r.success {
                    if let newNotifications = r.result {
                        if isRefresh {
                            self.notifications = newNotifications
                        } else {
                            self.notifications.append(
                                contentsOf: newNotifications
                            )
                        }
                    }

                    // 1. 解析 message 并更新 totalCount 和 endNotificationIndex
                    if let msg = r.message {
                        self.parseMessage(msg)
                    }

                    // 2. 更新页码
                    self.currentPage = page

                    // 3. hasNextPage 属性会自动根据 endNotificationIndex 和 totalCount 重新计算
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                print("加载通知失败: \(error.localizedDescription)")
            }
        }
    }

    func loadNextPage() async {
        guard hasNextPage else { return }
        await loadNotifications(page: currentPage + 1, isRefresh: false)
    }

    func refresh() async {
        // 刷新时重置状态，保证从第一页开始加载
        self.currentPage = 1
        self.endIndex = 0
        self.totalCount = 0
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
