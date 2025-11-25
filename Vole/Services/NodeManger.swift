//
//  NodeManger.swift
//  Vole
//
//  Created by 杨权 on 11/24/25.
//

import Foundation

@MainActor
class NodeManager: ObservableObject {

    static let shared = NodeManager()

    @Published private(set) var groups: [NodeGroup] = []
    @Published private(set) var nodes: [Node] = []

    private var idMap: [Int: Node] = [:]
    private var nameMap: [String: Node] = [:]

    private var isLoading = false
    private let cacheKey = "cachedGroups"

    private init() {
        // 启动时从缓存加载
        if let cached = loadCachedGroups(), !cached.isEmpty {
            let allNodes = cached.flatMap { $0.nodes }
            rebuildIndex(from: allNodes)
            print("⭕️ NodeManager 已从缓存构建索引 (\(allNodes.count) nodes)")
        }
    }

    /// 刷新节点
    func refreshNodes(force: Bool) async {
        if !force, let cached = loadCachedGroups(), !cached.isEmpty {
            self.groups = cached
            let allNodes = cached.flatMap { $0.nodes }
            self.nodes = allNodes
            rebuildIndex(from: allNodes)
            return
        }

        let fetched = await loadNodes()
        self.nodes = fetched
        self.groups = buildGroups(from: fetched)
        rebuildIndex(from: fetched)
    }

    /// 根据 id 查询 Node
    func getNode(_ id: Int?) -> Node? {
        guard let id else { return nil }
        return idMap[id]
    }

    /// 根据 name 查询 Node
    func getNode(_ name: String) -> Node? {
        return nameMap[name]
    }

    private func rebuildIndex(from nodes: [Node]) {
        idMap = [:]
        nameMap = [:]

        for n in nodes {
            if let id = n.id {
                idMap[id] = n
            }
            nameMap[n.name] = n
        }
    }

    // MARK: - 加载节点（网络 + 本地缓存）

    private func loadNodes() async -> [Node] {
        guard !isLoading else { return [] }
        isLoading = true
        defer { isLoading = false }

        do {
            let list = try await V2exAPI.shared.nodesList() ?? []
            let groups = buildGroups(from: list)
            saveGroupsToCache(groups)
            print("成功加载\(list.count)个节点")
            return list
        } catch {
            print("❌ 加载节点失败:", error)
            return []
        }
    }

    private func saveGroupsToCache(_ groups: [NodeGroup]) {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCachedGroups() -> [NodeGroup]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode([NodeGroup].self, from: data)
    }

    // 构建分组
    func buildGroups(from nodes: [Node]) -> [NodeGroup] {

        var nameMap: [String: Node] = [:]
        for n in nodes {
            nameMap[n.name] = n
        }

        // 建立 children 映射
        var childrenMap: [String: [Node]] = [:]
        for n in nodes {
            if let parent = n.parentNodeName {
                childrenMap[parent, default: []].append(n)
            }
        }

        // 找根节点
        let roots: [Node] = nodes.filter {
            $0.parentNodeName == nil || $0.name == "v2ex"
                || nameMap[$0.parentNodeName ?? ""] == nil
        }

        // BFS 展平
        func collectDescendantsBFS(of root: Node) -> [Node] {
            var result: [Node] = []
            var visited: Set<String> = []
            var queue: [Node] = [root]

            while !queue.isEmpty {
                let node = queue.removeFirst()
                guard !visited.contains(node.name) else { continue }
                visited.insert(node.name)
                result.append(node)
                queue.append(contentsOf: childrenMap[node.name] ?? [])
            }
            return result
        }

        var groups: [NodeGroup] = []
        var singles: [Node] = []

        for root in roots {
            let flat = collectDescendantsBFS(of: root)
            if flat.isEmpty { continue }

            if flat.count == 1 {
                singles.append(flat[0])
                continue
            }

            let sorted = flat.sorted { ($0.topics ?? 0) > ($1.topics ?? 0) }
            let weight = sorted.reduce(0) { $0 + ($1.topics ?? 0) }

            groups.append(NodeGroup(root: root, nodes: sorted, weight: weight))
        }

        // 单节点打包 other
        if !singles.isEmpty {
            let sorted = singles.sorted { ($0.topics ?? 0) > ($1.topics ?? 0) }
            let total = sorted.reduce(0) { $0 + ($1.topics ?? 0) }

            let otherRoot = Node(
                id: nil,
                name: "other",
                title: "其他",
                url: nil,
                topics: total,
                footer: nil,
                header: nil,
                titleAlternative: nil,
                avatar: nil,
                avatarMini: nil,
                avatarNormal: nil,
                avatarLarge: nil,
                stars: nil,
                aliases: nil,
                root: true,
                parentNodeName: nil
            )

            groups.append(
                NodeGroup(root: otherRoot, nodes: sorted, weight: total)
            )
        }

        return groups.sorted { $0.weight > $1.weight }
    }
}
