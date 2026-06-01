//
//  NodeCollectionManager.swift
//  Vole
//
//  Created by 杨权 on 11/15/25.
//

import Foundation
import SwiftUI

@MainActor
final class NodeCollectionManager: ObservableObject {
    static let shared = NodeCollectionManager()

    @Published private(set) var collections: [NodeCollection] = []
    @Published private(set) var customCollections: [NodeCollection] = []

    private let saveKey = "node_collections_v1"
    private let customSaveKey = "home_node_collections_v1"

    init() {
        loadDefaultCollections()
        loadCustomCollections()
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
    @discardableResult
    func addCustomCollection(
        name: String,
        nodeNames: [String] = [],
        color: String = "blue",
        symbol: String = "list.bullet"
    ) -> NodeCollection {
        let new = NodeCollection(
            name: name,
            systemIcon: symbol,
            colorHex: color,
            nodeNames: Array(nodeNames.prefix(10))
        )
        customCollections.append(new)
        saveCustomCollections()
        return new
    }

    func removeCustomCollection(_ c: NodeCollection) {
        customCollections.removeAll { $0.id == c.id }
        saveCustomCollections()
    }

    func updateCustomCollection(_ c: NodeCollection) {
        var updated = c
        updated.nodeNames = Array(c.nodeNames.prefix(10))
        if let idx = customCollections.firstIndex(where: { $0.id == c.id }) {
            customCollections[idx] = updated
            saveCustomCollections()
        }
    }

    func setNode(_ nodeName: String, selected: Bool, in collection: NodeCollection)
        -> Bool
    {
        guard
            let idx = customCollections.firstIndex(where: {
                $0.id == collection.id
            })
        else { return false }

        if selected {
            guard !customCollections[idx].nodeNames.contains(nodeName) else {
                return true
            }
            guard customCollections[idx].nodeNames.count < 10 else {
                return false
            }
            customCollections[idx].nodeNames.append(nodeName)
        } else {
            customCollections[idx].nodeNames.removeAll { $0 == nodeName }
        }
        saveCustomCollections()
        return true
    }

    func customCollection(id: UUID) -> NodeCollection? {
        customCollections.first { $0.id == id }
    }

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

    private func saveCustomCollections() {
        if let data = try? JSONEncoder().encode(customCollections) {
            UserDefaults.standard.set(data, forKey: customSaveKey)
        }
    }

    private func loadCustomCollections() {
        guard let data = UserDefaults.standard.data(forKey: customSaveKey),
            let value = try? JSONDecoder().decode(
                [NodeCollection].self,
                from: data
            )
        else { return }
        customCollections = value
    }
}
