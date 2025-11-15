//
//  NodeGroupView.swift
//  Vole
//
//  Created by 杨权 on 11/13/25.
//

import SwiftUI

struct NodeCollectionView: View {
    @State var collection: NodeCollection
    @Binding var path: NavigationPath

    @State private var topics: [Topic] = []
    @State private var isLoading = true

    var body: some View {
        List {
            // MARK: - 横向 node 标签 Section
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(collection.nodeNames, id: \.self) { nodeName in
                            Text(nodeName)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule().fill(
                                        collection.color.opacity(0.5)
                                    )
                                )
                                .onTapGesture {
                                    path.append(Route.nodeName(nodeName))
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())  // 去掉默认左右间距
                .listRowSeparator(.hidden)  // 去掉分隔线
                .listRowBackground(Color.clear)
            }

            // MARK: - Topics 列表 Section
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("加载中…")
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(topics) { topic in
                        TopicRow(topic: topic) {
                            path.append(Route.topicId(topic.id))
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if topics.isEmpty {
                await loadTopics()
            }
        }
    }

    // MARK: - 并发加载所有节点的 topics
    private func loadTopics() async {
        isLoading = true

        await withTaskGroup(of: [Topic].self) { group in
            for name in collection.nodeNames {
                group.addTask {
                    do {
                        let response = try await V2exAPI().topics(
                            nodeName: name,
                            page: 1
                        )
                        if let r = response, r.success, let topics = r.result {
                            return topics.map { t -> Topic in
                                var t = t
                                if t.node == nil {
                                    t.node = Node(
                                        id: nil,
                                        name: name,
                                        title: name,
                                        url: nil,
                                        topics: nil,
                                        footer: nil,
                                        header: nil,
                                        titleAlternative: nil,
                                        avatar: nil,
                                        avatarMini: nil,
                                        avatarNormal: nil,
                                        avatarLarge: nil,
                                        stars: nil,
                                        aliases: nil,
                                        root: nil,
                                        parentNodeName: nil
                                    )
                                }
                                return t
                            }
                        }
                    } catch {
                        print("加载失败：\(name)", error)
                    }
                    return []
                }
            }

            var all: [Topic] = []
            for await list in group {
                all += list
            }

            let sorted = all.sorted { ($0.created ?? 0) > ($1.created ?? 0) }

            await MainActor.run {
                self.topics = sorted
                self.isLoading = false
            }
        }
    }
}
