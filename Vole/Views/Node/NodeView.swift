//
//  Home.swift
//  Vole
//
//  Created by 杨权 on 5/25/25.
//

import Kingfisher
import SwiftUI

struct NodeView: View {
    @State private var collections = NodeCollectionManager.shared.collections
    @State private var showProfile = false
    @StateObject private var nodeManager = NodeManager.shared
    @ObservedObject private var userManager = UserManager.shared
    @EnvironmentObject var navManager: NavigationManager

    private let cardWidth: CGFloat = 320
    private let maxRows = 3

    var body: some View {
        NavigationStack(path: $navManager.nodePath) {

            Group {
                if nodeManager.groups.isEmpty {
                    VStack {
                        ProgressView("加载中…")
                            .progressViewStyle(.circular)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 24) {

                            // 分类横向滚动
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(collections, id: \.self) {
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
                case .moreNode(let group):
                    List(Array(group.nodes.enumerated()), id: \.1.id) {
                        index,
                        node in
                        NodeRowView(node: node)
                            .onTapGesture {
                                navManager.nodePath.append(Route.node(node))
                            }
                            .listRowSeparator(
                                index == 0 ? .hidden : .visible,
                                edges: .top
                            )
                    }
                    .listStyle(.plain)
                    .navigationTitle(group.root.title ?? group.root.name)
                    .navigationBarTitleDisplayMode(.inline)
                default: EmptyView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AvatarView {
                        showProfile = true
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
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
                HStack(spacing: 16) {
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
                        VStack(spacing: 0) {
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
