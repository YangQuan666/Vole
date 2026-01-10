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

    // 模糊搜索
    func search(name: String) async -> [Node] {
        guard !name.isEmpty else { return [] }
        let keyword = name.lowercased()
        do {
            let list = try await V2exAPI.shared.nodesList() ?? []
            return list.filter { node in
                node.name.lowercased().contains(keyword)
                || (node.title?.lowercased().contains(keyword) ?? false)
            }
        } catch {
            print("❌ 加载节点失败:", error)
            return []
        }
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
        // --- 1. 基础字典映射 ---
        var allNodesDict: [String: Node] = [:]
        for n in nodes { allNodesDict[n.name] = n }

        // --- 2. 补全缺失的父节点 (跳过自引用) ---
        for n in nodes {
            if let pName = n.parentNodeName, !pName.isEmpty,
                pName != n.name,  // 只有父亲不是自己时，才去补全
                allNodesDict[pName] == nil
            {
                allNodesDict[pName] = Node.createVirtual(name: pName)
            }
        }

        // --- 3. 建立子节点查找表 (排除自引用，防止死循环) ---
        var childrenMap: [String: [Node]] = [:]
        for n in allNodesDict.values {
            if let pName = n.parentNodeName, !pName.isEmpty, pName != n.name {
                childrenMap[pName, default: []].append(n)
            }
        }

        // --- 4. 确定顶级根节点 ---
        let rootNodes = allNodesDict.values.filter { node in
            let pName = node.parentNodeName ?? ""
            // 根节点的条件：
            // 1. 没有父亲
            // 2. 父亲是自己 (处理 v2ex -> v2ex 的情况)
            // 3. 父亲在字典里找不到 (这种其实在 Step 2 补全后几乎不存在了)
            return pName.isEmpty || pName == node.name
                || allNodesDict[pName] == nil
        }

        var finalGroups: [NodeGroup] = []
        var otherNodes: [Node] = []
        var processedNames: Set<String> = []

        // --- 5. 递归函数 (后序遍历) ---
        @discardableResult
        func process(u: Node) -> [Node] {
            var currentCluster: [Node] = []

            // A. 递归处理真正的子节点
            if let children = childrenMap[u.name] {
                for child in children {
                    // 再次防御：防止任何形式的循环引用
                    if child.name == u.name { continue }

                    let leftover = process(u: child)
                    currentCluster.append(contentsOf: leftover)
                }
            }

            // B. 处理当前节点自己 (只有真实节点才计入数量)
            if u.id != nil && !processedNames.contains(u.name) {
                currentCluster.append(u)
            }

            // C. 超过 18 个拆分策略
            if currentCluster.count > 18 {
                let sorted = currentCluster.sorted {
                    ($0.topics ?? 0) > ($1.topics ?? 0)
                }
                let weight = sorted.reduce(0) { $0 + ($1.topics ?? 0) }
                finalGroups.append(
                    NodeGroup(root: u, nodes: sorted, weight: weight)
                )

                currentCluster.forEach { processedNames.insert($0.name) }
                return []
            }

            return currentCluster
        }

        // --- 6. 遍历根节点执行 ---
        for root in rootNodes {
            // 如果这个根节点已经在之前的递归中被作为子节点处理了，就跳过
            if processedNames.contains(root.name) { continue }

            let remaining = process(u: root)
            if remaining.isEmpty { continue }

            // --- 7. 合并“其他”逻辑 (< 3) ---
            if remaining.count < 3 {
                otherNodes.append(contentsOf: remaining)
            } else {
                let sorted = remaining.sorted {
                    ($0.topics ?? 0) > ($1.topics ?? 0)
                }
                let weight = sorted.reduce(0) { $0 + ($1.topics ?? 0) }
                finalGroups.append(
                    NodeGroup(root: root, nodes: sorted, weight: weight)
                )
                remaining.forEach { processedNames.insert($0.name) }
            }
        }

        // --- 8. 安全汇总所有漏掉的节点 ---
        let allProcessed = Set(finalGroups.flatMap { $0.nodes.map { $0.name } })
        let missed = nodes.filter {
            !allProcessed.contains($0.name) && !otherNodes.contains($0)
        }
        otherNodes.append(contentsOf: missed)

        if !otherNodes.isEmpty {
            let uniqueOthers = Array(Set(otherNodes))
            let otherRoot = Node.createVirtual(name: "other", title: "其他")
            let sorted = uniqueOthers.sorted {
                ($0.topics ?? 0) > ($1.topics ?? 0)
            }
            let weight = sorted.reduce(0) { $0 + ($1.topics ?? 0) }
            finalGroups.append(
                NodeGroup(root: otherRoot, nodes: sorted, weight: weight)
            )
        }

        return finalGroups.sorted { $0.weight > $1.weight }
    }

}
