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
                    // 1. 输入框无内容 -> 展示历史记录 或 提示
                    if history.keywords.isEmpty {
                        VStack {
                            Spacer()
                            Text("请输入关键词进行搜索")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        historyListView
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
            .onChange(of: searchText) { oldValue, newValue in
                // 当输入框变为空时，重置所有搜索状态
                if newValue.isEmpty {
                    results = []  // 清空结果数据
                    isLoading = false  // 如果正在加载中，也强制停止加载状态
                }
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
                        .font(.subheadline)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // 结果列表视图
    private var resultsListView: some View {
        List(results) { res in

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(res.source.member)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                Text(res.source.title)
                    .font(.headline)
                Text(res.source.content)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
                // 节点+发布时间 + 评论数量
                HStack {
                    Text("\(res.source.node)")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                    Spacer()

                    Text(
                        DateConverter.relativeTimeString(
                            isoDateString: res.source.created
                        )
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    HStack(spacing: 4) {  // 图标和文字间距
                        Image(systemName: "ellipsis.bubble")
                            .foregroundColor(.secondary)  // 图标颜色
                        Text("\(res.source.replies)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
            .onTapGesture {
                // 点击结果跳转
                navManager.searchPath.append(Route.topicId(res.source.id))
            }
        }
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
        default: EmptyView()  // 如果 Route 是 enum 且 exhaustive，不需要 default
        }
    }

    // 执行搜索
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
