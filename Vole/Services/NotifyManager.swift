//
//  NotifyManager.swift
//  Vole
//
//  Created by 杨权 on 11/19/25.
//

import Foundation
import SwiftUI

@MainActor
final class NotifyManager: ObservableObject {
    static let shared = NotifyManager()

    // 存储所有的通知数据
    @Published var notifications: [Notification] = []
    @Published var totalCount: Int = 0
    // 存储已读 ID
    @Published private(set) var readIds: Set<Int> = []

    private let key = "read_notification_ids"

    private init() {
        if let stored = UserDefaults.standard.array(forKey: key) as? [Int] {
            readIds = Set(stored)
        }
    }

    // 总通知 - 已读通知 = 未读通知
    var unreadCount: Int {
        // 防止本地累积的已读数超过服务端总数导致负数
        let count = totalCount - readIds.count
        return max(0, count)
    }

    func markRead(_ id: Int) {
        readIds.insert(id)
        save()
        // 此时 readIds 变了，unreadCount 会自动重新计算，UI 也会自动刷新
    }

    func markAllRead(_ ids: [Int]) {
        readIds.formUnion(ids)
        save()
    }

    func isRead(_ id: Int) -> Bool {
        readIds.contains(id)
    }

    private func save() {
        UserDefaults.standard.set(Array(readIds), forKey: key)
    }

    // 4. 修改：加载数据并存储到自身
    func loadNotifications() async {
        guard let t = UserManager.shared.token else {
            return
        }
        do {
            let response = try await V2exAPI().notifications(
                page: 1,
                token: t.token ?? ""
            )
            if let r = response, r.success {
                // 1. 更新列表数据
                if let n = r.result {
                    self.notifications = n
                }
                // 2. 解析 total (例如 "Notifications 1-10/41" -> 41)
                if let msg = r.message {
                    self.parseMessage(msg)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    /// 解析格式：Notifications {start}-{end}/{total}
    /// 例如：Notifications 1-10/41 -> 提取 41
    private func parseMessage(_ message: String) {
        // 正则表达式解释：
        // Notifications : 匹配字面量
        // \s+           : 匹配一个或多个空格
        // \d+-\d+       : 匹配 "数字-数字" (即 1-10)
        // /             : 匹配斜杠
        // (\d+)         : 捕获组，匹配最后的总数数字
        let pattern = #"Notifications\s+\d+-\d+/(\d+)"#

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = message as NSString
            let results = regex.matches(
                in: message,
                options: [],
                range: NSRange(location: 0, length: nsString.length)
            )

            if let match = results.first, match.numberOfRanges >= 2 {
                // 获取第一个捕获组的内容 (即 total 部分)
                let totalString = nsString.substring(with: match.range(at: 1))
                if let count = Int(totalString) {
                    self.totalCount = count
                    return
                }
            }
        } catch {
            print("正则解析出错: \(error)")
        }
    }
}
