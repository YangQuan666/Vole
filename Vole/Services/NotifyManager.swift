//
//  NotifyManager.swift
//  Vole
//
//  Created by 杨权 on 11/19/25.
//

import Foundation

final class NotifyManager: ObservableObject {
    static let shared = NotifyManager()

    @Published private(set) var readIds: Set<Int> = []

    private let key = "read_notification_ids"

    private init() {
        if let stored = UserDefaults.standard.array(forKey: key) as? [Int] {
            readIds = Set(stored)
        }
    }

    func markRead(_ id: Int) {
        readIds.insert(id)
        save()
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
}
