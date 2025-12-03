//
//  SearchResultsView.swift
//  Vole
//
//  Created by 杨权 on 11/23/25.
//

import SwiftUI

struct SearchResultView: View {
    // 外部传入参数
    let query: String

    // 内部状态管理
    @State private var results: [SoV2exHit] = []
    @State private var isLoading = false
    @State private var pagingState = SearchPagingState()
    @State private var isPagingLoading: Bool = false

    // 筛选状态
    @State private var filterOptions = SearchFilterOptions()
    @State private var isFilterPresented = false

    // 环境对象
    @EnvironmentObject var navManager: NavigationManager

    // 判断是否有筛选条件生效（用于改变图标状态）
    private var isFiltering: Bool {
        filterOptions != SearchFilterOptions()
    }

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("搜索中…")
                        .padding()
                    Spacer()
                }
            } else if results.isEmpty {
                // 空状态视图
                emptyStateView
            } else {
                // 结果列表
                List {
                    Section(header: listHeaderView, footer: footerView) {
                        ForEach(results.indices, id: \.self) { index in
                            let res = results[index]
                            SearchRowView(result: res)
                                .onTapGesture {
                                    navManager.searchPath.append(
                                        Route.topicId(res.source.id)
                                    )
                                }
                                .onAppear {
                                    if index == results.count - 1 {
                                        Task { await loadNextPage() }
                                    }
                                }
                        }
                    }
                }
            }
        }
        // 筛选弹窗 (代码保持不变)
        .sheet(isPresented: $isFilterPresented) {
            SearchFilterSheet(
                options: $filterOptions,
                onConfirm: {
                    isFilterPresented = false
                    Task { await performSearch() }
                },
                onCancel: {
                    isFilterPresented = false
                }
            )
            .presentationDetents([.medium, .large])  // 半屏 & 全屏
            .presentationDragIndicator(.visible)  // 上拉手柄
        }
        .task(id: query) {
            await performSearch()
        }
    }

    // 1. 列表头部筛选栏
    private var listHeaderView: some View {
        HStack {
            // 左侧可以显示结果数量，或者留空
            if let total = pagingState.totalResults {
                Text("共 \(total) 条结果")
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 右侧筛选按钮
            Button(action: {
                isFilterPresented = true
            }) {
                HStack(spacing: 4) {
                    Text("筛选")
                    // 如果有筛选条件，使用实心图标，否则使用空心图标
                    Image(
                        systemName: isFiltering
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
            }
        }
        .padding(.vertical, 8)
        .textCase(nil)  // 关键：防止 SwiftUI 自动将 Section Header 转为大写
    }

    // 2. 列表底部加载栏
    @ViewBuilder
    private var footerView: some View {
        if isPagingLoading {
            HStack {
                Spacer()
                ProgressView("加载更多...")
                Spacer()
            }
            .padding()
        } else if let total = pagingState.totalResults,
            results.count >= total && results.count > 0
        {
            Text("已加载全部 \(results.count) 条结果")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .padding()
        }
    }

    // 3. 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("没有搜索到相关内容")
                .foregroundColor(.secondary)

            // 如果是因为筛选导致没有结果，需要提供重新筛选的入口
            if isFiltering {
                Button(action: {
                    isFilterPresented = true
                }) {
                    Text("调整筛选条件")
                        .fontWeight(.medium)
                }
                .padding(.top, 8)

                Button("清除所有筛选") {
                    resetFilters()
                }
                .font(.footnote)
                .foregroundColor(.red)
            }
            Spacer()
        }
    }


    private func resetFilters() {
        filterOptions = SearchFilterOptions()
        Task { await performSearch() }
    }

    private func performSearch() async {
        guard !query.isEmpty else { return }

        isLoading = true
        pagingState = SearchPagingState()

        let req = buildRequest(from: 0)

        do {
            let res = try await SoV2exService.shared.search(req)
            if Task.isCancelled { return }

            await MainActor.run {
                self.pagingState.totalResults = res.total
                self.results = res.hits
                self.pagingState.currentOffset = res.hits.count
                self.isLoading = false
            }
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.results = []
                    self.isLoading = false
                }
            }
        }
    }

    private func loadNextPage() async {
        guard !isPagingLoading,
            let total = pagingState.totalResults,
            pagingState.currentOffset < total
        else { return }

        isPagingLoading = true
        let req = buildRequest(from: pagingState.currentOffset)

        do {
            let res = try await SoV2exService.shared.search(req)
            if Task.isCancelled { return }

            await MainActor.run {
                self.results.append(contentsOf: res.hits)
                self.pagingState.currentOffset = self.results.count
                self.isPagingLoading = false
            }
        } catch {
            await MainActor.run { self.isPagingLoading = false }
        }
    }

    // MARK: - Request Builder
    private func buildRequest(from: Int) -> SoV2exSearchRequest {
        var req = SoV2exSearchRequest(
            q: query,
            from: from,
            size: pagingState.pageSize
        )

        // 1. 时间筛选
        if let startTime = filterOptions.timeRange.startTimeStamp {
            req.gte = startTime
        }

        // 2. 节点筛选
        if !filterOptions.nodeName.trimmingCharacters(in: .whitespaces).isEmpty
        {
            req.node = filterOptions.nodeName.trimmingCharacters(
                in: .whitespaces
            )
        }

        // 3. 排序
        switch filterOptions.sortType {
        case .weight:
            req.sort = .sumup
            req.order = nil
        case .timeDesc:
            req.sort = .created
            req.order = .descending
        case .timeAsc:
            req.sort = .created
            req.order = .ascending
        }

        return req
    }
}

#Preview {
    //    SearchResultsView()
}
