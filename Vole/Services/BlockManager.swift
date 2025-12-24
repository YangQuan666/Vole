//
//  BlockManager.swift
//  Vole
//
//  Created by 杨权 on 12/24/25.
//

import Foundation

@MainActor
class BlockManager: ObservableObject {
    static let shared = BlockManager()
    
    @Published private(set) var blockedUsernames: Set<String> = []
    private let storageKey = "app_blocked_usernames"

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: storageKey) {
            blockedUsernames = Set(saved)
        }
    }

    func block(_ username: String) {
        blockedUsernames.insert(username)
        UserDefaults.standard.set(Array(blockedUsernames), forKey: storageKey)
        // 这里的 objectWillChange 会触发 UI 刷新
        objectWillChange.send()
    }
    
    func isBlocked(_ username: String) -> Bool {
        blockedUsernames.contains(username)
    }
}
