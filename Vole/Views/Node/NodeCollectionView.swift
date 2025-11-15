//
//  NodeGroupView.swift
//  Vole
//
//  Created by 杨权 on 11/13/25.
//

import SwiftUI

struct NodeCollectionView: View {
    let title: String = "合集"
    let nodeNames: [String]
    @Binding var path: NavigationPath

    @State private var topics: [Topic] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中…")
            } else {
                List(topics) { topic in
                    TopicRow(topic: topic) {
                        path.append(Route.topicId(topic.id))
                    }
                }
            }
        }
        .task {
            await loadTopics()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // 并发加载
    private func loadTopics() async {
        isLoading = true

        await withTaskGroup(of: [Topic].self) { group in
            for name in nodeNames {  // ← 使用 nodeNames
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
