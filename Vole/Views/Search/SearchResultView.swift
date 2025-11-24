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

    // 环境对象用于导航
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        Group {
            if isLoading {
                // 1. 初始加载中
                VStack {
                    Spacer()
                    ProgressView("搜索中…")
                        .padding()
                    Spacer()
                }
            } else if results.isEmpty {
                // 2. 无结果
                VStack {
                    Spacer()
                    Text("没有搜索到相关内容")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                // 3. 结果列表
                List {
                    Section(
                        footer: footerView
                    ) {
                        ForEach(results.indices, id: \.self) { index in
                            let res = results[index]

                            resultRowView(res: res)
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
        // ⭐️ 核心逻辑：当 query 改变时，自动触发搜索
        // .task(id:) 会在视图出现或 id 变化时运行，如果 id 变化会自动取消上一次任务
        .task(id: query) {
            await performSearch()
        }
    }

    // MARK: - Subviews

    private func resultRowView(res: SoV2exHit) -> some View {
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

            HStack {
                Text("\(res.source.node)")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
                Spacer()

                // 假设 DateConverter 可用
                Text(
                    DateConverter.relativeTimeString(
                        isoDateString: res.source.created
                    )
                )
                .font(.caption)
                .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "ellipsis.bubble")
                        .foregroundColor(.secondary)
                    Text("\(res.source.replies)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

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

    // MARK: - Logic Actions

    private func performSearch() async {
        guard !query.isEmpty else { return }

        // 重置状态
        isLoading = true
        pagingState = SearchPagingState()

        let req = SoV2exSearchRequest(
            q: query,
            from: pagingState.currentOffset,
            size: pagingState.pageSize
        )

        do {
            let res = try await SoV2exService.shared.search(req)

            // 检查当前 task 是否被取消（虽然 SwiftUI .task 会自动处理，但加上更安全）
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
                    // 可选：处理错误提示
                }
            }
        }
    }

    private func loadNextPage() async {
        // 边界检查
        guard !isPagingLoading,
            let total = pagingState.totalResults,
            pagingState.currentOffset < total
        else {
            return
        }

        isPagingLoading = true

        let req = SoV2exSearchRequest(
            q: query,
            from: pagingState.currentOffset,
            size: pagingState.pageSize
        )

        do {
            let res = try await SoV2exService.shared.search(req)

            if Task.isCancelled { return }

            await MainActor.run {
                self.results.append(contentsOf: res.hits)
                self.pagingState.currentOffset = self.results.count
                self.isPagingLoading = false
            }
        } catch {
            print("分页加载失败: \(error)")
            await MainActor.run {
                self.isPagingLoading = false
            }
        }
    }
}

#Preview {
    //    SearchResultsView()
}
