//
//  Home.swift
//  Vexer
//
//  Created by 杨权 on 5/25/25.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var submittedQuery = ""
    @State private var isSearchPresented = false
    @State private var showProfile = false
    @State private var showAlert = false

    @ObservedObject private var blockManager = BlockManager.shared
    @StateObject private var history = SearchHistory.shared
    @EnvironmentObject var navManager: NavigationManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack(path: $navManager.searchPath) {
            VStack(spacing: 0) {
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
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "搜索 主题、节点、用户"
            )
            .onSubmit(of: .search) {
                handleSubmit(searchText)
            }
            .onChange(of: searchText) { _, newValue in
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
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        history.add(trimmed)
        submittedQuery = trimmed
        isSearchPresented = false
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
            ToolbarItem {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
            }

            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed)
            }

            ToolbarItem {
                Menu {
                    if blockManager.isBlocked(member.username) {
                        Button("取消屏蔽用户", systemImage: "person") {
                            blockManager.unblock(member.username)
                        }
                        .tint(.red)
                    } else {
                        Button("屏蔽用户", systemImage: "person.slash") {
                            showAlert = true
                        }
                        .tint(.red)
                    }

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
                blockManager.block(member.username)
                if !navManager.searchPath.isEmpty {
                    navManager.searchPath.removeLast()
                }
            }
            Button("取消", role: .cancel) {}
        }
    }
}
