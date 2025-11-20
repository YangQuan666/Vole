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
        let tech = NodeCollection(
            name: "技术",
            systemIcon: "hammer.fill",
            colorHex: "indigo",
            nodeNames: ["programmer", "cloud", "idev", "rss", "nas", "android"]
        )
        let creative = NodeCollection(
            name: "创意",
            systemIcon: "sparkles.2",
            colorHex: "green",
            nodeNames: ["create", "design", "ideas"]
        )
        let fun = NodeCollection(
            name: "好玩",
            systemIcon: "puzzlepiece.fill",
            colorHex: "cyan",
            nodeNames: ["share", "bb", "music", "movie", "travel", "afterdark"]
        )
        let apple = NodeCollection(
            name: "Apple",
            systemIcon: "apple.logo",
            colorHex: "gray",
            nodeNames: [
                "apple", "iphone", "ipad", "mbp", "macos", "ios", "appletv",
                "idev",
            ]
        )
        let job = NodeCollection(
            name: "酷工作",
            systemIcon: "apple.logo",
            colorHex: "brown",
            nodeNames: [
                "jobs", "cv", "career", "meet", "outsourcing", "remote",
            ]
        )
        let exchange = NodeCollection(
            name: "交易",
            systemIcon: "creditcard.fill",
            colorHex: "teal",
            nodeNames: ["all4all", "exchange", "free", "dn", "tuan"]
        )
        let city = NodeCollection(
            name: "城市",
            systemIcon: "building.2.fill",
            colorHex: "blue",
            nodeNames: [
                "life", "beijing", "shanghai", "shenzhen", "guangzhou",
                "hangzhou", "chengdu",
            ]
        )
        let ask = NodeCollection(
            name: "问与答",
            systemIcon: "questionmark.bubble.fill",
            colorHex: "blue",
            nodeNames: ["qna"]
        )
        //        let xna = NodeCollection(
        //            name: "VXNA",
        //            systemIcon: "globe.fill",
        //            colorHex: "yellow",
        //            nodeNames: ["vxna"]
        //        )
        collections = [
            tech, creative, fun, apple, job, exchange, city, ask,
        ]
        save()
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
