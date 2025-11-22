//
//  NodeCollectionManager.swift
//  Vole
//
//  Created by 杨权 on 11/15/25.
//

import Foundation
import SwiftUI

class NodeCollectionManager {
    static let shared = NodeCollectionManager()

    @Published private(set) var collections: [NodeCollection] = []

    private let saveKey = "node_collections_v1"

    init() {
        //         UserDefaults.standard.removeObject(forKey: saveKey)
        loadDefaultCollections()
        //        load()
        //        if collections.isEmpty {
        //            loadDefaultCollections()
        //        }
    }

    // MARK: - 默认合集
    private func loadDefaultCollections() {
        guard
            let url = Bundle.main.url(
                forResource: "nodeCollection",
                withExtension: "json"
            )
        else {
            print("❌ nodes.json not found")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            collections = try JSONDecoder().decode(
                [NodeCollection].self,
                from: data
            )
        } catch {
            print("❌ Failed to decode nodes.json: \(error)")
        }
    }

    // MARK: - CRUD 集合
    func addCollection(name: String, color: String, symbol: String) {
        let new = NodeCollection(
            name: name,
            systemIcon: symbol,
            colorHex: color
        )
        collections.append(new)
        save()
    }

    func removeCollection(_ c: NodeCollection) {
        collections.removeAll { $0.id == c.id }
        save()
    }

    func updateCollection(_ c: NodeCollection) {
        if let idx = collections.firstIndex(where: { $0.id == c.id }) {
            collections[idx] = c
            save()
        }
    }

    // MARK: - 节点增删
    func addNode(_ nodeName: String, to collection: NodeCollection) {
        guard
            let idx = collections.firstIndex(where: { $0.id == collection.id })
        else { return }
        if !collections[idx].nodeNames.contains(nodeName) {
            collections[idx].nodeNames.append(nodeName)
            save()
        }
    }

    func removeNode(_ nodeName: String, from collection: NodeCollection) {
        guard
            let idx = collections.firstIndex(where: { $0.id == collection.id })
        else { return }
        collections[idx].nodeNames.removeAll { $0 == nodeName }
        save()
    }

    // MARK: - 持久化
    private func save() {
        if let data = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
            let value = try? JSONDecoder().decode(
                [NodeCollection].self,
                from: data
            )
        {
            self.collections = value
        }
    }
}
