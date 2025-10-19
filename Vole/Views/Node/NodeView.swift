//
//  Home.swift
//  Vole
//
//  Created by 杨权 on 5/25/25.
//

import SwiftUI

let categories = [
    NodeCategory(name: "技术", color: .indigo, systemIcon: "hammer.fill"),
    NodeCategory(name: "创意", color: .green, systemIcon: "sparkles.2"),
    NodeCategory(name: "好玩", color: .cyan, systemIcon: "puzzlepiece.fill"),
    NodeCategory(name: "Apple", color: .gray, systemIcon: "apple.logo"),
    NodeCategory(name: "酷工作", color: .brown, systemIcon: "briefcase.fill"),
    NodeCategory(name: "交易", color: .teal, systemIcon: "creditcard.fill"),
    NodeCategory(name: "城市", color: .blue, systemIcon: "building.2.fill"),
    NodeCategory(
        name: "问与答",
        color: .blue,
        systemIcon: "questionmark.bubble.fill"
    ),
]

struct NodeView: View {
    @State private var selectedCategory: NodeCategory? = nil
    @State private var path = NavigationPath()
//    @State private var nodes: [Node] = []
    @State private var groups: [NodeGroup] = []
    @State private var isLoading = false

    let sections = ["必玩游戏", "热门游戏"]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: 分类横向滚动
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.self) { category in
                                HStack(spacing: 8) {
                                    Image(systemName: category.systemIcon)
                                        .foregroundColor(category.color)
                                    Text(category.name)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.gray.opacity(0.1))
                                )
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // nodes 不为空的展示区（替换你原来的 LazyVStack 部分）
//                    let groups = buildGroups(from: nodes)

                    VStack(spacing: 16) {
                        ForEach(groups.indices, id: \.self) { gi in
                            let root = groups[gi].root
                            let descendants = groups[gi].descendants

                            VStack(alignment: .leading, spacing: 8) {
                                // 根节点标题
                                Text(root.title ?? root.name)
                                    .font(.headline)
                                    .padding(.horizontal)

                                // 如果没有后代，依然显示一个单列（根节点下无子，显示 root 自己或空）
                                if descendants.isEmpty {
                                    ScrollView(
                                        .horizontal,
                                        showsIndicators: false
                                    ) {
                                        HStack(spacing: 16) {
                                            VStack(spacing: 8) {
                                                NodeRowView(node: root)
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                } else {
                                    // 把 descendants 切成每列最多 3 个
                                    let columns: [[Node]] = stride(
                                        from: 0,
                                        to: descendants.count,
                                        by: 3
                                    ).map {
                                        Array(
                                            descendants[
                                                $0..<min(
                                                    $0 + 3,
                                                    descendants.count
                                                )
                                            ]
                                        )
                                    }

                                    
                                    ScrollView(.horizontal) {
                                        HStack(spacing: 16) {
                                            ForEach(columns.indices, id: \.self) { ci in
                                                VStack(spacing: 8) {
                                                    ForEach(columns[ci], id: \.id) { node in
                                                        NodeRowView(node: node)
                                                    }
                                                }
                                                .frame(width: UIScreen.main.bounds.width * 0.8)
                                                .background(Color(.systemBackground))
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                                .shadow(color: .black.opacity(0.05), radius: 2)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .scrollTargetBehavior(.paging) // ✅ 自动分页滚动
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Node")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                }
            }
            .refreshable {
                await refreshNodes(force: true)
            }
            .task {
                // 首次进入页面时加载
                if groups.isEmpty {
                    await refreshNodes(force: false)
                }
            }
            .background(Color(.systemBackground))
        }
    }

    private func refreshNodes(force: Bool) async {
        /// ① 优先加载本地缓存
        if !force, let cached = loadCachedGroups(), !cached.isEmpty {
            groups = cached
            print("✅ 从本地缓存加载节点: \(cached.count)")
            return
        }

        /// ② 若本地为空或强制刷新，则重新请求网络
        let nodes = await loadNodes()
        groups = buildGroups(from: nodes)
    }

    private func loadNodes() async -> [Node] {
        guard !isLoading else { return [] }
        isLoading = true
        defer { isLoading = false }

        do {
            let nodes = try await V2exAPI.shared.nodesList() ?? []
            let groups = buildGroups(from: nodes)
            saveGroupsToCache(groups)
            return nodes
        } catch {
            if error is CancellationError { return [] }
            print("❌ 加载节点失败:", error)
            return []
        }
    }

    // 本地缓存逻辑
    private func saveGroupsToCache(_ groups: [NodeGroup]) {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: "cachedGroups")
        }
    }

    private func loadCachedGroups() -> [NodeGroup]? {
        guard let data = UserDefaults.standard.data(forKey: "cachedGroups") else {
            return nil
        }
        return try? JSONDecoder().decode([NodeGroup].self, from: data)
    }

    // MARK: - 辅助：构建树并把每个根节点的后代展平成数组
    private func buildGroups(from nodes: [Node]) -> [NodeGroup] {
        // 建 map：name -> Node
        var nameMap: [String: Node] = [:]
        for n in nodes {
            if let name = n.name as String? { nameMap[name] = n }
        }

        // 建 children map：parentName -> [Node]
        var childrenMap: [String: [Node]] = [:]
        for n in nodes {
            if let parent = n.parentNodeName {
                childrenMap[parent, default: []].append(n)
            }
        }

        // 找根节点：parentNodeName == nil 或 parent 不存在于 nameMap（保险）
        let roots: [Node] = nodes.filter {
            $0.parentNodeName == nil || nameMap[$0.parentNodeName ?? ""] == nil
        }

        // DFS 展平后代（排除根自己）
        func collectDescendants(of root: Node) -> [Node] {
            var result: [Node] = []
            var visited: Set<String> = []
            // 使用栈做迭代 DFS，或者递归也可以
            func dfs(_ node: Node) {
                guard let nName = node.name as String? else { return }
                if visited.contains(nName) { return }  // 防环
                visited.insert(nName)
                let children = childrenMap[node.name] ?? []
                for child in children {
                    result.append(child)  // 先把 child 放入结果
                    dfs(child)  // 再遍历 child 的子孙
                }
            }
            dfs(root)
            return result
        }

        // 返回顺序：按 roots 原数组顺序
        var groups: [NodeGroup] = []
        for root in roots {
            let desc = collectDescendants(of: root)
            groups.append(NodeGroup(root: root, descendants: desc))
        }
        return groups
    }
}

struct NodeCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
    let systemIcon: String
}

struct NodeGroup: Codable {
    let root: Node
    let descendants: [Node]
}
#Preview {
    NodeView()
}
