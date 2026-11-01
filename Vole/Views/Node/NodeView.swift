//
//  Home.swift
//  Vole
//
//  Created by 杨权 on 5/25/25.
//

import Kingfisher
import SwiftUI

struct NodeView: View {
    @StateObject private var collectionManager = NodeCollectionManager.shared
    @StateObject private var favoriteNodeManager = FavoriteNodeManager.shared
    @State private var showProfile = false
    @State private var showCreateTopic = false
    @State private var createdTopicID: Int?
    @StateObject private var nodeManager = NodeManager.shared
    @ObservedObject private var userManager = UserManager.shared
    @EnvironmentObject var navManager: NavigationManager

    private let cardWidth: CGFloat = 320
    private let maxRows = 3

    var body: some View {
        NavigationStack(path: $navManager.nodePath) {

            Group {
                if nodeManager.groups.isEmpty {
                    NodeLoadingStateView()
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            // 分类横向滚动
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(
                                        collectionManager.collections,
                                        id: \.self
                                    ) {
                                        collection in
                                        HStack(spacing: 8) {
                                            Image(
                                                systemName: collection
                                                    .systemIcon
                                            )
                                            .foregroundColor(collection.color)
                                            Text(collection.name)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            Capsule().fill(
                                                Color.secondary.opacity(0.1)
                                            )
                                        )
                                        .onTapGesture {
                                            navManager.nodePath.append(
                                                Route.nodeCollect(collection)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }

                            favoriteNodesSection

                            // 分组内容
                            ForEach(nodeManager.groups) { group in
                                groupSection(group)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }

            .navigationTitle("节点")
            .modifier(HomeTitleDisplayModeModifier())
            .task {
                if nodeManager.groups.isEmpty {
                    await nodeManager.refreshNodes(force: true)
                }
            }
            .refreshable {
                await nodeManager.refreshNodes(force: true)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .topicId(let topicId):
                    DetailView(topicId: topicId, path: $navManager.nodePath)
                case .topic(let topic):
                    DetailView(
                        topicId: nil,
                        topic: topic,
                        path: $navManager.nodePath
                    )
                case .node(let node):
                    NodeDetailView(node: node, path: $navManager.nodePath)
                case .nodeName(let nodeName):
                    NodeDetailView(
                        nodeName: nodeName,
                        path: $navManager.nodePath
                    )
                case .nodeCollect(let nodeCollection):
                    NodeCollectionView(
                        path: $navManager.nodePath,
                        collection: nodeCollection
                    )
                case .favoriteNodes:
                    FavoriteNodeListView(path: $navManager.nodePath)
                case .moreNode(let group):
                    MoreNodeListView(group: group, path: $navManager.nodePath)
                default: EmptyView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if userManager.token?.token?.isEmpty == false {
                            showCreateTopic = true
                        } else {
                            showProfile = true
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("创建主题")
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showCreateTopic, onDismiss: {
                if let createdTopicID {
                    navManager.nodePath.append(Route.topicId(createdTopicID))
                    self.createdTopicID = nil
                }
            }) {
                NavigationStack {
                    CreateTopicView { topic in
                        createdTopicID = topic.id
                        showCreateTopic = false
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // 单独抽出 group section，减少 body 复杂度
    @ViewBuilder
    private func groupSection(_ group: NodeGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: Route.moreNode(group)) {
                HStack {
                    Text(group.root.title ?? "")
                        .font(.title3.bold())
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    let limitedNodes = Array(group.nodes.prefix(15))
                    let columns = stride(
                        from: 0,
                        to: limitedNodes.count,
                        by: maxRows
                    ).map {
                        Array(
                            limitedNodes[
                                $0..<min($0 + maxRows, limitedNodes.count)
                            ]
                        )
                    }

                    ForEach(columns.indices, id: \.self) { i in
                        LazyVStack(spacing: 0) {
                            ForEach(columns[i].indices, id: \.self) { j in
                                let node = columns[i][j]
                                Button {
                                    navManager.nodePath.append(Route.node(node))
                                } label: {
                                    NodeRowView(node: node)
                                        .frame(width: cardWidth)
                                        .padding()
                                }
                                .buttonStyle(.plain)

                                if j < columns[i].count - 1 {
                                    Divider().padding(.leading, 60)
                                }
                            }
                        }
                        .frame(width: cardWidth)
                    }
                }
                .scrollTargetLayout()
            }
            .safeAreaPadding(.horizontal, 16)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    @ViewBuilder
    private var favoriteNodesSection: some View {
        if !favoriteNodeManager.favoriteNodes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink(value: Route.moreNode(favoriteNodeGroup)) {
                    HStack {
                        Text("收藏")
                            .font(.title3.bold())

                        Image(systemName: "chevron.right")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(favoriteNodeManager.favoriteNodes, id: \.name) { node in
                            Button {
                                openNode(node)
                            } label: {
                                VStack(spacing: 8) {
                                    favoriteNodeIcon(for: node)

                                    Text(node.title ?? node.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 72)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .safeAreaPadding(.horizontal, 16)
            }
        }
    }

    private func openNode(_ node: Node) {
        navManager.nodePath.append(Route.node(node))
    }

    private var favoriteNodeGroup: NodeGroup {
        NodeGroup(
            root: Node.createVirtual(name: "favorites", title: "收藏节点"),
            nodes: favoriteNodeManager.favoriteNodes,
            weight: 0
        )
    }

    @ViewBuilder
    private func favoriteNodeIcon(for node: Node) -> some View {
        Group {
            if let avatarURL = node.getHighestQualityAvatar(),
                let url = SiteConfiguration.makeSiteURL(from: avatarURL)
            {
                KFImage(url)
                    .placeholder {
                        favoriteNodePlaceholder(for: node)
                    }
                    .resizable()
                    .scaledToFill()
            } else {
                favoriteNodePlaceholder(for: node)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func favoriteNodePlaceholder(for node: Node) -> some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.12))

            Text(String((node.title ?? node.name).prefix(1)))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

}

private struct MoreNodeListView: View {
    let group: NodeGroup
    @Binding var path: NavigationPath
    @State private var searchText = ""

    private var filteredNodes: [Node] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return group.nodes }

        return group.nodes.filter { node in
            node.name.localizedCaseInsensitiveContains(keyword)
                || (node.title?.localizedCaseInsensitiveContains(keyword) ?? false)
        }
    }

    var body: some View {
        let nodes = filteredNodes

        Group {
            if nodes.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "magnifyingglass",
                    description: Text(emptyDescription)
                )
            } else {
                nodeList(nodes)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(group.root.title ?? group.root.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索节点"
        )
    }

    private var emptyTitle: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "暂无节点"
            : "没有找到节点"
    }

    private var emptyDescription: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "这个分组里还没有节点。"
            : "换个节点名称试试看。"
    }

    private func nodeList(_ nodes: [Node]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(nodes.enumerated()), id: \.1.name) { index, node in
                    Button {
                        path.append(Route.node(node))
                    } label: {
                        NodeRowView(node: node)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)

                    if index < nodes.count - 1 {
                        Divider()
                            .padding(.leading, 82)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
}

private struct FavoriteNodeListView: View {
    @Binding var path: NavigationPath
    @StateObject private var favoriteNodeManager = FavoriteNodeManager.shared

    var body: some View {
        List {
            if favoriteNodeManager.favoriteNodes.isEmpty {
                ContentUnavailableView(
                    "暂无收藏节点",
                    systemImage: "star",
                    description: Text("在节点详情页点一下加号，就会出现在这里。")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(favoriteNodeManager.favoriteNodes, id: \.name) { node in
                    Button {
                        path.append(Route.node(node))
                    } label: {
                        NodeRowView(node: node)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(
                        EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("收藏")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NodeLoadingStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 52, height: 52)

                ProgressView()
                    .controlSize(.regular)
            }

            VStack(spacing: 5) {
                Text("正在加载节点")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("正在整理节点分类和常用入口。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct NodeGroup: Codable, Identifiable, Hashable, Sendable {
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
