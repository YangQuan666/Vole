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
    @Published private(set) var blockedTopicIds: Set<Int> = []
    private let storageKey = "app_blocked_usernames"
    private let topicStorageKey = "app_blocked_topic_ids"

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: storageKey) {
            blockedUsernames = Set(saved)
        }
        if let saved = UserDefaults.standard.array(forKey: topicStorageKey) as? [Int] {
            blockedTopicIds = Set(saved)
        }
    }

    func block(_ username: String) {
        blockedUsernames.insert(username)
        UserDefaults.standard.set(Array(blockedUsernames), forKey: storageKey)
    }
    func unblock(_ username: String) {
        blockedUsernames.remove(username)
        UserDefaults.standard.set(Array(blockedUsernames), forKey: storageKey)
    }
    func isBlocked(_ username: String) -> Bool {
        blockedUsernames.contains(username)
    }

    func blockTopic(_ topicId: Int) {
        blockedTopicIds.insert(topicId)
        UserDefaults.standard.set(Array(blockedTopicIds), forKey: topicStorageKey)
    }

    /// 被屏蔽的话题，或作者已被屏蔽的话题
    func isHidden(_ topic: Topic) -> Bool {
        if blockedTopicIds.contains(topic.id) { return true }
        if let username = topic.member?.username {
            return blockedUsernames.contains(username)
        }
        return false
    }

    func visible(_ topics: [Topic]) -> [Topic] {
        topics.filter { !isHidden($0) }
    }
}
