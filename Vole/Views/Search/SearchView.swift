//
//  Home.swift
//  Vexer
//
//  Created by 杨权 on 5/25/25.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var results: [SoV2exHit] = []
    @State private var isLoading = false

    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        NavigationStack(path: $navManager.searchPath) {
            Group {
                if searchText.isEmpty {
                    // 还没输入
                    VStack {
                        Spacer()
                        Text("请输入关键词进行搜索")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if isLoading {
                    // 加载中
                    VStack {
                        Spacer()
                        ProgressView("搜索中…")
                            .padding()
                        Spacer()
                    }
                } else if results.isEmpty {
                    // 无结果
                    VStack {
                        Spacer()
                        Text("没有搜索到相关内容")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    // 有结果
                    List(results) { res in
                        Text(res.source.content)

                        //                        TopicRow(topic: topic) {
                        //                            navManager.searchPath.append(
                        //                                Route.topicId(topic.id)
                        //                            )
                        //                        }
                    }
                }
            }
            .navigationTitle("搜索")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic)
            )
            .onSubmit(of: .search) {
                Task { await performSearch() }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .topicId(let topicId):
                    DetailView(
                        topicId: topicId,
                        path: $navManager.searchPath
                    )
                case .nodeName(let nodeName):
                    NodeDetailView(
                        nodeName: nodeName,
                        path: $navManager.nodePath
                    )
                case .node(let node):
                    NodeDetailView(node: node, path: $navManager.searchPath)
                default: EmptyView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    // MARK: - 搜索逻辑
    private func performSearch() async {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else {
            results = []

            return
        }

        isLoading = true

        do {
            let req = SoV2exSearchRequest(q: keyword)
            let res = try await SoV2exService.shared.search(req)
            await MainActor.run {
                if !res.timedOut {
                    results = res.hits
                }
            }
        } catch {
            print("搜索失败，请稍后再试")
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    @Previewable var navManager = NavigationManager()
    SearchView().environmentObject(navManager)
}
