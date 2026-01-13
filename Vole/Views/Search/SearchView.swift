//
//  Home.swift
//  Vexer
//
//  Created by 杨权 on 5/25/25.
//

import Kingfisher
import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var submittedQuery = ""  // 只有当用户点击确认/回车时才更新此值
    @State private var showProfile = false
    @State private var showAlert = false

    @ObservedObject private var userManager = UserManager.shared
    @StateObject private var history = SearchHistory.shared
    @EnvironmentObject var navManager: NavigationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack(path: $navManager.searchPath) {
            VStack(spacing: 0) {
                // 逻辑分支：
                // 1. 如果 submittedQuery 为空 -> 显示历史/空状态
                // 2. 否则 -> 显示结果页（结果页内部自己处理 Loading 和 数据）

                if submittedQuery.isEmpty {
                    if history.keywords.isEmpty && searchText.isEmpty {
                        emptyStateView
                    } else {
                        SearchHistoryView(
                            onKeywordTapped: handleHistoryTap,
                            history: history
                        )
                    }
                } else {
                    // 只传递 query，逻辑全在内部
                    SearchResultView(
                        query: submittedQuery,
                        path: $navManager.searchPath
                    )
                    .id(submittedQuery)
                }
            }
            .navigationTitle("搜索")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "搜索 V2EX 主题"
            )
            .onSubmit(of: .search) {
                handleSubmit(searchText)
            }
            // 清空搜索框时重置状态
            .onChange(of: searchText) { oldValue, newValue in
                if newValue.isEmpty {
                    submittedQuery = ""
                }
            }
            .navigationDestination(
                for: Route.self,
                destination: routeDestination
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AvatarView {
                        showProfile = true
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }

    // MARK: - Subviews & Helpers

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("请输入关键词进行搜索")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func handleHistoryTap(keyword: String) {
        searchText = keyword
        handleSubmit(keyword)
    }

    private func handleSubmit(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // 记录历史
        history.add(trimmed)

        // 更新 submittedQuery，这将触发视图切换到 SearchResultView
        // 并触发 SearchResultView 内部的 .task(id:)
        submittedQuery = trimmed
    }

    @ViewBuilder
    private func routeDestination(for route: Route) -> some View {
        switch route {
        case .topicId(let topicId):
            DetailView(topicId: topicId, path: $navManager.searchPath)
        case .nodeName(let nodeName):
            NodeDetailView(nodeName: nodeName, path: $navManager.searchPath)
        case .node(let node):
            NodeDetailView(node: node, path: $navManager.searchPath)
        case .member(let member):
            memberDetailView(for: member)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func memberDetailView(for member: Member) -> some View {
        let shareURL = member.url ?? ""

        List {
            MemberDetailView(member: member)
        }
        .toolbar {
            // 分享按钮
            ToolbarItem {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
            }

            // iOS 26 专属间距
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed)
            }

            // 更多操作菜单
            ToolbarItem {
                Menu {
                    Button("屏蔽用户", systemImage: "person.slash") {
                        showAlert = true
                    }
                    .tint(.red)

                    Button("在浏览器中打开", systemImage: "safari") {
                        if let url = URL(string: shareURL) {
                            openURL(url)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("确定要屏蔽该用户吗？", isPresented: $showAlert) {
            Button("确认屏蔽", role: .destructive) {
                BlockManager.shared.block(member.username)
                if !navManager.searchPath.isEmpty {
                    navManager.searchPath.removeLast()
                }
            }
            Button("取消", role: .cancel) {}
        }
    }
}
