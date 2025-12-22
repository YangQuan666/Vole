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

    // 加载节点（网络 + 本地缓存）
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
        // 1. 基础映射
        var nameMap: [String: Node] = [:]
        for n in nodes { nameMap[n.name] = n }

        // 2. 识别并创建虚拟父节点
        var virtualParents: [String: Node] = [:]
        for n in nodes {
            if let parentName = n.parentNodeName, nameMap[parentName] == nil {
                if virtualParents[parentName] == nil {
                    virtualParents[parentName] = Node.createVirtual(
                        name: parentName
                    )
                }
            }
        }

        // 3. 建立子节点关系映射
        var childrenMap: [String: [Node]] = [:]
        for n in nodes {
            if let parent = n.parentNodeName {
                childrenMap[parent, default: []].append(n)
            }
        }

        // 4. 确定所有的根（原始根 + 虚拟根）
        let roots: [Node] =
            nodes.filter { node in
                let isParentEmpty =
                    node.parentNodeName == nil
                    || node.parentNodeName?.isEmpty == true
                return isParentEmpty || node.name == "v2ex"
            } + Array(virtualParents.values)

        // BFS 展平函数（只收集真实存在的节点）
        func collectRealNodesBFS(of root: Node) -> [Node] {
            var result: [Node] = []
            var visited: Set<String> = []
            var queue: [Node] = [root]

            while !queue.isEmpty {
                let node = queue.removeFirst()
                guard !visited.contains(node.name) else { continue }
                visited.insert(node.name)

                // 关键：只有带 ID 的才是真实节点（排除掉我们伪造的虚拟父节点）
                if node.id != nil {
                    result.append(node)
                }

                if let children = childrenMap[node.name] {
                    queue.append(contentsOf: children)
                }
            }
            return result
        }

        var finalGroups: [NodeGroup] = []
        var singles: [Node] = []  // 用来存放那些“势单力薄”的单点节点
        var processedNames: Set<String> = []

        // 5. 开始构建分组
        for root in roots {
            let flatNodes = collectRealNodesBFS(of: root)

            // 过滤掉已经在其他组处理过的节点（防止环路或交叉引用）
            let uniqueNodes = flatNodes.filter {
                !processedNames.contains($0.name)
            }
            if uniqueNodes.isEmpty { continue }
            uniqueNodes.forEach { processedNames.insert($0.name) }

            // --- 核心逻辑判断 ---
            if uniqueNodes.count > 2 {
                // 如果节点数多于 1，形成独立分组
                let sorted = uniqueNodes.sorted {
                    ($0.topics ?? 0) > ($1.topics ?? 0)
                }
                let weight = sorted.reduce(0) { $0 + ($1.topics ?? 0) }
                finalGroups.append(
                    NodeGroup(root: root, nodes: sorted, weight: weight)
                )
            } else {
                // 如果只有 1 个节点，暂存到 singles
                singles.append(contentsOf: uniqueNodes)
            }
        }

        // 6. 处理所有的单点节点，打包成“其他”
        if !singles.isEmpty {
            let sortedSingles = singles.sorted {
                ($0.topics ?? 0) > ($1.topics ?? 0)
            }
            let totalWeight = sortedSingles.reduce(0) { $0 + ($1.topics ?? 0) }

            let otherRoot = Node.createVirtual(name: "other", title: "其他")
            finalGroups.append(
                NodeGroup(
                    root: otherRoot,
                    nodes: sortedSingles,
                    weight: totalWeight
                )
            )
        }

        // 7. 最后根据权重（活跃度）全局排序
        return finalGroups.sorted { $0.weight > $1.weight }
    }

}
