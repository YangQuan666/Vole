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
        notifications.filter { !readIds.contains($0.id) }.count
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
            // 确保更新 UI 的操作在主线程
            if let r = response, r.success, let n = r.result {
                self.notifications = n
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}
