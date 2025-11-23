//
//  SearchHistoryManager.swift
//  Vole
//
//  Created by 杨权 on 11/23/25.
//

import Foundation

class SearchHistory: ObservableObject {
    static let shared = SearchHistory()

    @Published var keywords: [String] = []

    private let key = "search_history"

    init() {
        load()
    }

    func add(_ keyword: String) {
        // 去重并置顶
        if let index = keywords.firstIndex(of: keyword) {
            keywords.remove(at: index)
        }
        keywords.insert(keyword, at: 0)
        // 限制数量，例如只存前 20 个
        if keywords.count > 20 { keywords.removeLast() }
        save()
    }

    func remove(at offsets: IndexSet) {
        keywords.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        keywords.removeAll()
        save()
    }

    private func save() {
        UserDefaults.standard.set(keywords, forKey: key)
    }

    private func load() {
        if let array = UserDefaults.standard.stringArray(forKey: key) {
            keywords = array
        }
    }
}
