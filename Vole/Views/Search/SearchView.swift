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
    // 💡 保持 submittedQuery 状态，以便在输入新词时显示历史记录
    @State private var submittedQuery = ""

    @StateObject private var history = SearchHistory.shared
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        NavigationStack(path: $navManager.searchPath) {
            VStack(spacing: 0) {
                // 状态分流逻辑
                if searchText.isEmpty || searchText != submittedQuery {
                    // 1. 输入框为空 或 用户正在打字（未提交）-> 展示历史记录 或 提示
                    if history.keywords.isEmpty && searchText.isEmpty {
                        VStack {
                            Spacer()
                            Text("请输入关键词进行搜索")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        // 替换为独立的 View Struct
                        SearchHistoryView(
                            onKeywordTapped: handleHistoryTap,
                            history: history
                        )
                    }
                } else if isLoading {
                    // 2. 加载中
                    VStack {
                        Spacer()
                        ProgressView("搜索中…")
                            .padding()
                        Spacer()
                    }
                } else if results.isEmpty {
                    // 3. 无结果
                    VStack {
                        Spacer()
                        Text("没有搜索到相关内容")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    // 4. 搜索结果列表
                    // 替换为独立的 View Struct
                    SearchResultsView(
                        results: results,
                        onResultTapped: handleResultTap
                    )
                }
            }
            .navigationTitle("搜索")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "搜索 V2EX 主题"
            )
            .onSubmit(of: .search) {
                Task { await performSearch() }
            }
            .onChange(of: searchText) { oldValue, newValue in
                if newValue.isEmpty {
                    results = []
                    submittedQuery = ""
                    isLoading = false
                }
            }
            .navigationDestination(
                for: Route.self,
                destination: routeDestination
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    // 处理历史记录点击动作
    private func handleHistoryTap(keyword: String) {
        searchText = keyword  // 1. 填入搜索框
        Task { await performSearch() }  // 2. 触发搜索
    }

    // 处理搜索结果点击动作
    private func handleResultTap(route: Route) {
        navManager.searchPath.append(route)
    }

    @ViewBuilder
    private func routeDestination(for route: Route) -> some View {
        // ... 路由逻辑不变 ...
        switch route {
        case .topicId(let topicId):
            DetailView(topicId: topicId, path: $navManager.searchPath)
        case .nodeName(let nodeName):
            NodeDetailView(nodeName: nodeName, path: $navManager.nodePath)
        case .node(let node):
            NodeDetailView(node: node, path: $navManager.searchPath)
        default: EmptyView()
        }
    }

    // 确保 performSearch 逻辑中更新 submittedQuery
    private func performSearch() async {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return }

        submittedQuery = keyword
        history.add(keyword)

        await MainActor.run { isLoading = true }

        do {
            let req = SoV2exSearchRequest(q: keyword)
            let res = try await SoV2exService.shared.search(req)

            await MainActor.run {
                if self.submittedQuery == keyword {
                    if !res.timedOut {
                        self.results = res.hits
                    }
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                if self.submittedQuery == keyword {
                    self.isLoading = false
                    self.results = []
                }
            }
        }
    }
}
