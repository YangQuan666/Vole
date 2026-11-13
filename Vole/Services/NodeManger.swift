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
    @Published private(set) var isLoading = false
    @Published private(set) var didAttemptLoad = false
    @Published private(set) var loadErrorMessage: String?

    private var idMap: [Int: Node] = [:]
    private var nameMap: [String: Node] = [:]

    private var siteConfigurationObserver: NSObjectProtocol?
    private var cacheKey: String {
        "cachedGroups.\(SiteConfiguration.cacheKeySuffix)"
    }

    private init() {
        siteConfigurationObserver = NotificationCenter.default.addObserver(
            forName: SiteConfiguration.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.restoreCachedState()
            }
        }
        restoreCachedState()
    }

    isolated deinit {
        if let siteConfigurationObserver {
            NotificationCenter.default.removeObserver(siteConfigurationObserver)
        }
    }

    /// 刷新节点
    func refreshNodes(force: Bool) async {
        if !force, let cached = loadCachedGroups(), !cached.isEmpty {
            applyCachedGroups(cached)
            didAttemptLoad = true
            loadErrorMessage = nil
            return
        }

        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            didAttemptLoad = true
        }

        guard let fetched = await loadNodes(), !fetched.isEmpty else {
            loadErrorMessage = "节点列表加载失败，请检查网络后重试。"
            return
        }

        let builtGroups = await Self.buildGroupsInBackground(from: fetched)
        let indexedNodes = builtGroups.flatMap { $0.nodes }
        guard !indexedNodes.isEmpty else {
            loadErrorMessage = "节点列表为空，请稍后重试。"
            return
        }

        saveGroupsToCache(builtGroups)

        self.nodes = indexedNodes
        self.groups = builtGroups
        rebuildIndex(from: indexedNodes)
        loadErrorMessage = nil
    }

    private func restoreCachedState() {
        guard let cached = loadCachedGroups(), !cached.isEmpty else {
            groups = []
            nodes = []
            rebuildIndex(from: [])
            didAttemptLoad = false
            loadErrorMessage = nil
            return
        }

        applyCachedGroups(cached)
        didAttemptLoad = true
        loadErrorMessage = nil
        print("⭕️ NodeManager 已从缓存构建索引 (\(nodes.count) nodes)")
    }

    // 模糊搜索
    func search(name: String) async throws -> [Node] {
        guard !name.isEmpty else { return [] }
        let keyword = name.lowercased()
        let list = try await V2exAPI.shared.nodesList() ?? []
        return list.filter { node in
            node.name.lowercased().contains(keyword)
                || (node.title?.lowercased().contains(keyword) ?? false)
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

    private func applyCachedGroups(_ cached: [NodeGroup]) {
        let preparedGroups = cached.map { group in
            NodeGroup(
                root: group.root.withResolvedHeaderText(),
                nodes: group.nodes.map { $0.withResolvedHeaderText() },
                weight: group.weight
            )
        }

        groups = preparedGroups
        let allNodes = preparedGroups.flatMap { $0.nodes }
        nodes = allNodes
        rebuildIndex(from: allNodes)
    }

    // 加载节点（网络 + 本地缓存）
    private func loadNodes() async -> [Node]? {
        do {
            guard let list = try await V2exAPI.shared.nodesList(), !list.isEmpty else {
                return nil
            }
            print("成功加载\(list.count)个节点")
            return list
        } catch {
            print("❌ 加载节点失败:", error)
            return nil
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

    nonisolated private static func buildGroupsInBackground(
        from nodes: [Node]
    ) async -> [NodeGroup] {
        await Task.detached(priority: .userInitiated) {
            NodeGroupBuilder.buildGroups(from: nodes)
        }.value
    }

}

private enum NodeGroupBuilder {
    // 构建分组
    static func buildGroups(from nodes: [Node]) -> [NodeGroup] {
        let resolvedNodes = nodes.map { $0.withResolvedHeaderText() }

        // --- 1. 基础字典映射 ---
        var allNodesDict: [String: Node] = [:]
        for n in resolvedNodes { allNodesDict[n.name] = n }

        // --- 2. 补全缺失的父节点 (跳过自引用) ---
        for n in resolvedNodes {
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
        let missed = resolvedNodes.filter {
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
