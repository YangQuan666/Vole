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

    @StateObject private var history = SearchHistory.shared

    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        NavigationStack(path: $navManager.searchPath) {
            VStack(spacing: 0) {
                // 状态分流逻辑
                if searchText.isEmpty {
                    // MARK: 1. 输入框无内容 -> 展示历史记录 或 提示
                    if history.keywords.isEmpty {
                        emptyPlaceholderView
                    } else {
                        historyListView
                    }
                } else if isLoading {
                    // MARK: 2. 加载中
                    loadingView
                } else if results.isEmpty {
                    // MARK: 3. 无结果
                    noResultsView
                } else {
                    // MARK: 4. 搜索结果列表
                    resultsListView
                }
            }
            .navigationTitle("搜索")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "搜索 V2EX 主题"
            )
            // 提交搜索（键盘回车）
            .onSubmit(of: .search) {
                Task { await performSearch() }
            }
            .navigationDestination(for: Route.self) { route in
                routeDestination(for: route)
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

    // MARK: - Subviews (为了代码整洁，拆分视图)

    // 空状态提示
    private var emptyPlaceholderView: some View {
        VStack {
            Spacer()
            Text("请输入关键词进行搜索")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // 历史记录列表
    private var historyListView: some View {
        List {
            Section {
                ForEach(history.keywords, id: \.self) { keyword in
                    // 使用 Button 而不是 NavigationLink，因为我们要执行动作（搜索）而不是直接跳转
                    Button {
                        // 点击历史记录逻辑：
                        // 1. 填入搜索框
                        searchText = keyword
                        // 2. 触发搜索
                        Task { await performSearch() }
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                            Text(keyword)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
                .onDelete { indexSet in
                    // 删除单行历史
                    history.remove(at: indexSet)
                }
            } header: {
                HStack {
                    Text("最近搜索")
                    Spacer()
                    if !history.keywords.isEmpty {
                        Button("清除") {
                            history.clear()
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .listStyle(.plain)  // 或 .insetGrouped 根据喜好
    }

    // 加载视图
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("搜索中…")
                .padding()
            Spacer()
        }
    }

    // 无结果视图
    private var noResultsView: some View {
        VStack {
            Spacer()
            Text("没有搜索到相关内容")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // 结果列表视图
    private var resultsListView: some View {
        List(results) { res in
            // 这里假设你有对应的 Row View
            // TopicRow(topic: res.source)

            // 临时使用 Text 代替展示
            VStack(alignment: .leading, spacing: 5) {
                Text(res.source.title)
                    .font(.headline)
                Text(res.source.content)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .onTapGesture {
                // 点击结果跳转
                navManager.searchPath.append(Route.topicId(res.source.id))
            }
        }
        .listStyle(.plain)
    }

    // 路由逻辑
    @ViewBuilder
    private func routeDestination(for route: Route) -> some View {
        switch route {
        case .topicId(let topicId):
            DetailView(topicId: topicId, path: $navManager.searchPath)
        case .nodeName(let nodeName):
            NodeDetailView(nodeName: nodeName, path: $navManager.nodePath)
        case .node(let node):
            NodeDetailView(node: node, path: $navManager.searchPath)
         default: EmptyView() // 如果 Route 是 enum 且 exhaustive，不需要 default
        }
    }

    // MARK: - Logic

    private func performSearch() async {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else {
            results = []
            return
        }

        // 1. 记录历史 (在搜索开始时记录)
        history.add(keyword)

        // 2. UI 状态变更
        await MainActor.run { isLoading = true }

        // 3. 网络请求
        do {
            let req = SoV2exSearchRequest(q: keyword)
            let res = try await SoV2exService.shared.search(req)

            await MainActor.run {
                if !res.timedOut {
                    self.results = res.hits
                }
                self.isLoading = false
            }
        } catch {
            print("搜索失败: \(error)")
            await MainActor.run {
                self.isLoading = false
                // 可以选择在这里清空结果或者保持上一次结果
                self.results = []
            }
        }
    }
}
