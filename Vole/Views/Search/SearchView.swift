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
    @State private var submittedQuery = ""  //以便在输入新词时显示历史记录
    @State private var pagingState = SearchPagingState()  //搜索分页结果
    @State private var isPagingLoading: Bool = false  // 是否正在加载下一页

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
                    SearchResultView(
                        results: results,
                        onResultTapped: handleResultTap,
                        totalResults: pagingState.totalResults,
                        isPagingLoading: isPagingLoading,
                        onLoadMore: {
                            Task { await loadNextPage() }
                        }
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

        pagingState = SearchPagingState()
        submittedQuery = keyword
        history.add(keyword)

        await MainActor.run { isLoading = true }

        let req = SoV2exSearchRequest(
            q: keyword,
            from: pagingState.currentOffset,
            size: pagingState.pageSize
        )
        do {
            let res = try await SoV2exService.shared.search(req)

            await MainActor.run {
                if submittedQuery == keyword {

                    // ⭐️ 关键：只设置 totalResults，pageSize 保持不变
                    pagingState.totalResults = res.total

                    self.results = res.hits
                    // 偏移量设置为当前结果数量
                    pagingState.currentOffset = self.results.count
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

    private func loadNextPage() async {
        // 1. 边界条件检查
        // - 检查是否正在加载中
        // - 检查总结果数是否已知 (totalResults)
        // - 检查当前偏移量 (currentOffset) 是否小于总数 (totalResults)
        // - 检查当前正在搜索的关键词是否有效且未被用户修改
        guard !isPagingLoading,
            let total = pagingState.totalResults,
            pagingState.currentOffset < total,
            !submittedQuery.isEmpty,
            searchText == submittedQuery  // 确保加载的是当前搜索的结果
        else {
            // 如果不满足条件，则直接退出，不执行加载
            return
        }

        // 2. 设置分页加载状态
        await MainActor.run {
            isPagingLoading = true
        }

        // 3. 准备请求参数
        let keyword = submittedQuery
        let currentOffset = pagingState.currentOffset
        let pageSize = pagingState.pageSize  // 使用固定的每页大小

        let req = SoV2exSearchRequest(
            q: keyword,
            from: currentOffset,
            size: pageSize
        )

        // 4. 执行网络请求
        do {
            let res = try await SoV2exService.shared.search(req)

            // 5. 在主线程更新状态
            await MainActor.run {
                // 再次检查submittedQuery，防止异步操作导致的竞态条件
                if submittedQuery == keyword {
                    // 追加新的结果到 results 数组
                    self.results.append(contentsOf: res.hits)

                    // 更新下次加载的起始偏移量
                    // 使用 results.count 更安全，因为可能会有不满 pageSize 的最后一页
                    pagingState.currentOffset = self.results.count

                    // 结束分页加载状态
                    self.isPagingLoading = false
                }
            }
        } catch {
            // 6. 错误处理
            print("分页加载失败: \(error)")
            await MainActor.run {
                self.isPagingLoading = false
            }
        }
    }
}
