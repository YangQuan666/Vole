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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: - 集合信息
                HStack(spacing: 12) {
                    Image(systemName: collection.systemIcon)
                        .font(.largeTitle)
                        .foregroundStyle(Color(collection.color))

                    VStack(alignment: .leading) {
                        Text(collection.name)
                            .font(.title.bold())
                        Text("共 \(collection.nodeNames.count) 个节点")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                Divider()

                // MARK: - 节点列表
                VStack(alignment: .leading, spacing: 8) {
                    Text("包含的节点")
                        .font(.title3.bold())
                    ForEach(collection.nodeNames, id: \.self) { nodeName in
                        Text(nodeName)
                            .font(.headline)
                    }
                }

                Divider()

                // MARK: - Topics 列表
                if isLoading {
                    ProgressView("加载中…")
                } else {
                    List(topics) { topic in
                        TopicRow(topic: topic) {
                            path.append(topic.id)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding()
        }
        .task {
            await loadTopics()
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
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
                            let topicsWithName = topics.map { t -> Topic in
                                var t = t

                                // 接口不返回 node，这里手动补
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

                            return topicsWithName
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

            // 按 created 字段倒序
            let sorted = all.sorted { ($0.created ?? 0) > ($1.created ?? 0) }

            await MainActor.run {
                self.topics = sorted
                self.isLoading = false
            }
        }
    }
}
