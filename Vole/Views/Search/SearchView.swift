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
    @ObservedObject private var userManager = UserManager.shared
    @StateObject private var history = SearchHistory.shared
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        NavigationStack(path: $navManager.searchPath) {
            VStack(spacing: 0) {
                // 逻辑分支：
                // 1. 如果 submittedQuery 为空，或者用户修改了输入框内容且尚未提交 -> 显示历史/空状态
                // 2. 否则 -> 显示结果页（结果页内部自己处理 Loading 和 数据）

                if submittedQuery.isEmpty || searchText != submittedQuery {
                    if history.keywords.isEmpty && searchText.isEmpty {
                        emptyStateView
                    } else {
                        SearchHistoryView(
                            onKeywordTapped: handleHistoryTap,
                            history: history
                        )
                    }
                } else {
                    // ⭐️ 核心变化：只传递 query，逻辑全在内部
                    SearchResultView(query: submittedQuery)
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
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showProfile = true
                        } label: {
                            if let memeber = userManager.currentMember,
                                let avatarURL =
                                    memeber.getHighestQualityAvatar(),
                                let url = URL(string: avatarURL)
                            {
                                KFImage(url)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showProfile = true
                        } label: {
                            if let memeber = userManager.currentMember,
                                let avatarURL = memeber.avatarNormal,
                                let url = URL(string: avatarURL)
                            {
                                KFImage(url)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(.blue)
                            }
                        }
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
            NodeDetailView(nodeName: nodeName, path: $navManager.nodePath)
        case .node(let node):
            NodeDetailView(node: node, path: $navManager.searchPath)
        default: EmptyView()
        }
    }
}
