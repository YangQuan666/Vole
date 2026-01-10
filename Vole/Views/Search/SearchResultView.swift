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

    // 1. 定义搜索分类枚举
    enum SearchCategory: String, CaseIterable, Identifiable {
        case topic = "话题"
        case node = "节点"
        case user = "用户"
        var id: String { self.rawValue }
    }
    // 内部状态管理
    @State private var selectedCategory: SearchCategory = .topic
    @State private var results: [SoV2exHit] = []
    @State private var isLoading = false
    @State private var pagingState = SearchPagingState()
    @State private var isPagingLoading: Bool = false

    @State private var nodes: [Node] = []
    @State private var users: [Member] = []

    @ObservedObject private var nodeManager = NodeManager.shared

    // 筛选状态
    @State private var filterOptions = SearchFilterOptions()
    @State private var isFilterPresented = false

    @Binding var path: NavigationPath

    // 判断是否有筛选条件生效（用于改变图标状态）
    private var isFiltering: Bool {
        filterOptions != SearchFilterOptions()
    }

    var body: some View {
        List {
            Section(header: listHeaderView, footer: footerView) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("搜索中…")
                        Spacer()
                    }
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                } else if isCurrentCategoryEmpty {
                    emptyStateView
                        .transition(.opacity)
                } else {
                    renderSearchResults()
                }
            }
        }
        .animation(.snappy, value: selectedCategory)
        .animation(.snappy, value: isLoading)
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
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            if results.isEmpty { await performSearch() }
        }
        .task {
            await performSearch()
        }
        .onChange(of: selectedCategory) {
            Task { await performSearch() }
        }
        .onChange(of: query) { oldValue, newValue in
            if oldValue == newValue {
                return
            }
            resetAllData()
            Task { await performSearch() }
        }
    }

    private func resetAllData() {
        results = []
        nodes = []
        users = []
        pagingState = SearchPagingState()
    }

    @ViewBuilder
    private func renderSearchResults() -> some View {
        switch selectedCategory {
        case .topic:
            ForEach(results.indices, id: \.self) { index in
                let res = results[index]
                SearchRowView(result: res)
                    .onTapGesture { path.append(Route.topicId(res.source.id)) }
                    .onAppear {
                        if index == results.count - 1 {
                            Task { await loadNextPage() }
                        }
                    }
            }

        case .node:
            ForEach(nodes) { node in
                NodeRowView(node: node)
                    .onTapGesture {
                        print("点击了\(node.name)")
                        path.append(Route.nodeName(node.name))
                    }
            }

        case .user:
            ForEach(users) { member in
                MemberView(member: member)
            }
        }
    }

    private var isCurrentCategoryEmpty: Bool {
        switch selectedCategory {
        case .topic: return results.isEmpty
        case .node: return nodes.isEmpty
        case .user: return users.isEmpty
        }
    }

    // 1. 列表头部筛选栏
    private var listHeaderView: some View {
        VStack(spacing: 12) {
            // 新增的类别切换器
            Picker("搜索类别", selection: $selectedCategory) {
                ForEach(SearchCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)  // 分段式效果
            .padding(.top, 4)

            HStack {
                if selectedCategory == .topic,
                    let total = pagingState.totalResults
                {
                    Text("共 \(total) 条结果")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 仅在“话题”搜索下显示筛选按钮（因为目前的筛选逻辑是针对话题的）
                if selectedCategory == .topic {
                    Button(action: {
                        isFilterPresented = true
                    }) {
                        HStack(spacing: 4) {
                            Text("筛选")
                            Image(
                                systemName: isFiltering
                                    ? "line.3.horizontal.decrease.circle.fill"
                                    : "line.3.horizontal.decrease.circle"
                            )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .textCase(nil)
    }

    // 2. 列表底部加载栏
    @ViewBuilder
    private var footerView: some View {
        if isPagingLoading {
            // 当大菊花正在转时，底部保持空白，避免视觉干扰
            EmptyView()
        } else {
            switch selectedCategory {
            case .topic:
                // 话题支持分页，逻辑最复杂
                if isPagingLoading {
                    HStack(spacing: 8) {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Text("正在加载更多...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                } else if let total = pagingState.totalResults, !results.isEmpty
                {
                    if results.count >= total {
                        footerText("已加载全部 \(results.count) 条结果")
                    } else {
                        footerText("上滑加载更多 (已展示 \(results.count) 条)")
                    }
                }

            case .node:
                // 节点通常是本地搜索，一次性出结果
                if !nodes.isEmpty {
                    footerText("共找到 \(nodes.count) 个匹配节点")
                }

            case .user:
                // 用户搜索
                if !users.isEmpty {
                    footerText("共找到 \(users.count) 位相关用户")
                }
            }
        }
    }

    private func footerText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowSeparator(.hidden)
    }

    // 3. 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 使用内边距代替 Spacer，确保在 List 中有足够的存在感
            Image(
                systemName: selectedCategory == .user
                    ? "person.slash" : "magnifyingglass"
            )
            .font(.system(size: 44, weight: .light))  // 稍微纤细一点更有高级感
            .foregroundStyle(.quaternary)  // 使用系统四级颜色，自带通透感
            .padding(.top, 60)  // 距离顶部的距离

            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(emptyStateDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 如果是因为筛选导致没有结果
            if selectedCategory == .topic && isFiltering {
                VStack(spacing: 12) {
                    Button(action: {
                        isFilterPresented = true
                    }) {
                        Text("调整筛选条件")
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }

                    Button("清除所有筛选") {
                        resetFilters()
                    }
                    .font(.footnote)
                    .foregroundColor(.red)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 60)  // 底部留白
        .listRowSeparator(.hidden)  // 关键：隐藏分割线
        .listRowBackground(Color.clear)  // 关键：背景透明，让它看起来不像一个“行”
    }

    // 辅助属性：根据分类返回不同的提示语
    private var emptyStateTitle: String {
        switch selectedCategory {
        case .topic: return "没有找到相关话题"
        case .node: return "没有找到匹配的节点"
        case .user: return "该用户不存在"
        }
    }

    private var emptyStateDescription: String {
        "尝试更换关键词，或者确认\n拼写是否正确"
    }

    private func resetFilters() {
        filterOptions = SearchFilterOptions()
        Task { await performSearch() }
    }

    private func performSearch() async {
        guard !query.isEmpty else { return }
        if !isCurrentCategoryEmpty {
            return
        }
        await MainActor.run {
            withAnimation { self.isLoading = true }
        }

        switch selectedCategory {
        case .topic:
            // 原有话题搜索逻辑，填充到 results
            await performTopicSearch()
        case .node:
            await performNodeSearch()
        case .user:
            await performUserSearch()
        }
        await MainActor.run {
            withAnimation { self.isLoading = false }
        }
    }

    // 1. 话题搜索逻辑
    private func performTopicSearch() async {
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
            await MainActor.run { self.isLoading = false }
        }
    }
    // 2. 节点搜索逻辑
    private func performNodeSearch() async {
        let list = await nodeManager.search(name: query)
        await MainActor.run {
            self.nodes = list
        }
    }

    // 3. 用户搜索逻辑
    private func performUserSearch() async {
        // TODO: 真正的用户 API
        try? await Task.sleep(nanoseconds: 300_000_000)
        await MainActor.run {
            self.users = []
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

    // Request Builder
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
