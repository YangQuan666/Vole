//
//  Home.swift
//  Vole
//
//  Created by 杨权 on 5/25/25.
//

import SwiftUI

struct NodeView: View {
    @State private var selectedCategory: NodeCategory? = nil
    @State private var collections = NodeCollectionManager.shared.collections
    @State private var groups: [NodeGroup] = []
    @State private var isLoading = false

    @EnvironmentObject var navManager: NavigationManager

    private let cardWidth: CGFloat = 320
    private let maxRows = 3

    var body: some View {
        NavigationStack(path: $navManager.nodePath) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {

                    // 分类横向滚动
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(collections, id: \.self) { collection in
                                HStack(spacing: 8) {
                                    Image(systemName: collection.systemIcon)
                                        .foregroundColor(collection.color)
                                    Text(collection.name)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.gray.opacity(0.1))
                                )
                                .onTapGesture {
                                    navManager.nodePath.append(Route.nodeCollect(collection))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    ForEach(groups) { group in
                        LazyVStack(alignment: .leading, spacing: 12) {
                            NavigationLink(value: Route.moreNode(group)) {
                                HStack {
                                    Text(group.root.title ?? "")
                                        .font(.title3.bold())
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .contentShape(Rectangle()) // 整行可点
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)

                            // 横向滚动内容保持不变
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    let limitedNodes = Array(group.nodes.prefix(15))
                                    let columns = stride(from: 0, to: limitedNodes.count, by: maxRows).map {
                                        Array(limitedNodes[$0..<min($0 + maxRows, limitedNodes.count)])
                                    }

                                    ForEach(columns.indices, id: \.self) { i in
                                        VStack(spacing: 0) {
                                            ForEach(columns[i].indices, id: \.self) { j in
                                                let node = columns[i][j]
                                                Button {
                                                    navManager.nodePath.append(Route.node(node))
                                                } label: {
                                                    NodeCardView(node: node)
                                                        .frame(width: cardWidth)
                                                }
                                                .buttonStyle(.plain)
                                                if j < columns[i].count - 1 {
                                                    Divider().padding(.leading, 16)
                                                }
                                            }
                                        }
                                        .frame(width: cardWidth)
                                        .scrollTargetLayout()
                                    }

                                    // 加入一个透明 Spacer，让最后一页右对齐
                                    Color.clear
                                        .frame(width: (UIScreen.main.bounds.width - cardWidth) / 2)
                                        .scrollTargetLayout()
                                }
                                .padding(.leading, 16)  // 第一页贴左
                            }
                            .scrollTargetBehavior(.viewAligned)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("节点")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .topicId(let topicId):
                    DetailView(topicId: topicId, path: $navManager.nodePath)
                case .node(let node):
                    NodeDetailView(node: node, path: $navManager.nodePath)
                case .nodeName(let nodeName):
                    NodeDetailView(nodeName: nodeName, path: $navManager.nodePath)
                case .nodeCollect(let nodeCollection):
                    NodeCollectionView(collection: nodeCollection, path: $navManager.nodePath)
                case .moreNode(let group):
                    List(Array(group.nodes.enumerated()), id: \.1.id) { index, node in
                        NodeCardView(node: node)
                            .onTapGesture {
                                navManager.nodePath.append(Route.node(node))
                            }
                            .listRowSeparator(index == 0 ? .hidden : .visible, edges: .top)
                    }
                    .listStyle(.plain)
                    .navigationTitle(group.root.title ?? group.root.name)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
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
        guard let data = UserDefaults.standard.data(forKey: "cachedGroups")
        else {
            return nil
        }
        return try? JSONDecoder().decode([NodeGroup].self, from: data)
    }

    // MARK: - 辅助：构建树并把每个根节点的后代展平成数组
    private func buildGroups(from nodes: [Node]) -> [NodeGroup] {
        // 建立 name -> Node 映射
        var nameMap: [String: Node] = [:]
        for n in nodes {
            nameMap[n.name] = n
        }

        // 建立 children 映射：parentName -> [Node]
        var childrenMap: [String: [Node]] = [:]
        for n in nodes {
            if let parent = n.parentNodeName {
                childrenMap[parent, default: []].append(n)
            }
        }

        // 找出根节点（parentNodeName == nil 或 parent 不存在）
        let roots: [Node] = nodes.filter {
            $0.parentNodeName == nil || $0.name == "v2ex" || nameMap[$0.parentNodeName ?? ""] == nil
        }

        // BFS 展平所有后代（包括 root 自身）
        func collectDescendantsBFS(of root: Node) -> [Node] {
            var result: [Node] = []
            var visited: Set<String> = []
            var queue: [Node] = [root]

            while !queue.isEmpty {
                let node = queue.removeFirst()
                guard !visited.contains(node.name) else { continue }
                visited.insert(node.name)
                result.append(node)

                let children = childrenMap[node.name] ?? []
                queue.append(contentsOf: children)
            }

            return result
        }

        // 构建 groups
        var groups: [NodeGroup] = []
        var singleNodes: [Node] = []

        for root in roots {
            let flattened = collectDescendantsBFS(of: root)
            if flattened.isEmpty { continue }

            // 如果 group 只有 1 个节点 → 暂存到 singleNodes
            if flattened.count == 1 {
                singleNodes.append(flattened[0])
                continue
            }

            // group 内按 topics 降序排序
            let sortedNodes = flattened.sorted {
                ($0.topics ?? 0) > ($1.topics ?? 0)
            }

            // group 权重 = 所有 topics 之和
            let totalTopics = sortedNodes.reduce(0) { $0 + ($1.topics ?? 0) }

            groups.append(
                NodeGroup(root: root, nodes: sortedNodes, weight: totalTopics)
            )
        }

        // 如果有 single 节点，统一打包为一个“other”分组
        if !singleNodes.isEmpty {
            let sortedSingles = singleNodes.sorted {
                ($0.topics ?? 0) > ($1.topics ?? 0)
            }
            let totalTopics = sortedSingles.reduce(0) { $0 + ($1.topics ?? 0) }

            // 创建一个虚拟的 root 表示“other”组
            let otherRoot = Node(
                id: nil,
                name: "other",
                title: "其他",
                url: nil,
                topics: totalTopics,
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
                NodeGroup(
                    root: otherRoot,
                    nodes: sortedSingles,
                    weight: totalTopics
                )
            )
        }

        // 按权重倒序排列（topics 总和越高排越前）
        let sortedGroups = groups.sorted { $0.weight > $1.weight }

        return sortedGroups
    }
}

struct NodeCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
    let systemIcon: String
}

struct NodeGroup: Codable, Identifiable, Hashable {
    var id = UUID()
    let root: Node
    let nodes: [Node]
    let weight: Int

    static func == (lhs: NodeGroup, rhs: NodeGroup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
#Preview {
    @Previewable var navManager = NavigationManager()
    NodeView()
        .environmentObject(navManager)
}
