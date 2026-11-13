//
//  NotifyView.swift
//  Vole
//
//  Created by 杨权 on 8/25/25.
//

import SwiftUI

struct NotifyView: View {
    @State private var showAlert = false
    @State private var notificationFilter = NotificationFilter.all
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var notifyManager = NotifyManager.shared
    @EnvironmentObject var navManager: NavigationManager

    private var isLoggedIn: Bool {
        userManager.currentMember != nil
    }

    var body: some View {
        NavigationStack(path: $navManager.notifyPath) {
            content
                .navigationTitle("通知")
                .modifier(HomeTitleDisplayModeModifier())
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .topicId(let topicId):
                        DetailView(topicId: topicId, path: $navManager.notifyPath)
                    case .nodeName(let nodeName):
                        NodeDetailView(
                            nodeName: nodeName,
                            path: $navManager.notifyPath
                        )
                    case .node(let node):
                        NodeDetailView(node: node, path: $navManager.notifyPath)
                    default:
                        EmptyView()
                    }
                }
                .toolbar {
                    if isLoggedIn && notifyManager.unreadCount > 0 {
                        ToolbarItem {
                            Button {
                                showAlert = true
                            } label: {
                                Image(systemName: "tray.and.arrow.down")
                            }
                            .accessibilityLabel("全部已读")
                        }
                    }
                    if #available(iOS 26.0, *), isLoggedIn,
                        notifyManager.unreadCount > 0
                    {
                        ToolbarSpacer(.fixed)
                    }
                    if isLoggedIn {
                        ToolbarItem {
                            notificationFilterButton
                        }
                    }
                }
                .alert("一键已读所有通知？", isPresented: $showAlert) {
                    Button("确认", role: .destructive) {
                        notifyManager.markAllRead()
                    }
                    Button("取消", role: .cancel) {}
                }
        }
    }

    private var notificationFilterButton: some View {
        Button {
            withAnimation(.snappy) {
                notificationFilter = notificationFilter == .all ? .unread : .all
            }
        } label: {
            Image(
                systemName: notificationFilter == .all
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .accessibilityLabel(
            notificationFilter == .all ? "筛选未读通知" : "显示全部通知"
        )
        .accessibilityValue(notificationFilter.title)
    }

    private var filteredNotifications: [Notification] {
        switch notificationFilter {
        case .all:
            notifyManager.notifications
        case .unread:
            notifyManager.notifications.filter { !notifyManager.isRead($0.id) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !isLoggedIn {
            ContentUnavailableView(
                "登录后查看通知",
                systemImage: "bell.slash",
                description: Text("回复、提到、收藏和感谢都会在这里出现")
            )
        } else {
            notificationList
        }
    }

    private var notificationList: some View {
        // 使用 List 承载通知卡片，行内的 swipeActions 才能生效。
        List {
            if filteredNotifications.isEmpty,
                !notifyManager.notifications.isEmpty
            {
                filteredEmptyRow
                    .notificationListRow()
            }

            ForEach(filteredNotifications, id: \.id) { item in
                NotifyRowView(item: item) { topicId in
                    navManager.notifyPath.append(Route.topicId(topicId))
                }
                .notificationListRow()
                .onAppear {
                    if notificationFilter == .all,
                        item.id == notifyManager.notifications.last?.id
                    {
                        Task {
                            await notifyManager.loadNextPage()
                        }
                    }
                }
            }

            footerView
                .notificationListRow()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .homeLikeListTopInset()
        .safeAreaInset(edge: .top, spacing: 8) {
            if notifyManager.hasPendingRefresh {
                pendingRefreshBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .refreshable {
            await notifyManager.refresh()
        }
        .overlay {
            listStateOverlay
        }
        .animation(.snappy, value: notifyManager.hasPendingRefresh)
    }

    private var filteredEmptyRow: some View {
        ContentUnavailableView(
            notificationFilter.emptyTitle,
            systemImage: notificationFilter.symbol,
            description: Text(
                notifyManager.hasNextPage
                    ? "当前已加载通知中没有匹配项。"
                    : "当前没有符合条件的通知。"
            )
        )
    }

    @ViewBuilder
    private var listStateOverlay: some View {
        if notifyManager.notifications.isEmpty {
            if notifyManager.isLoading {
                loadingStateView
            } else {
                emptyStateView
            }
        }
    }

    private var loadingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("正在同步通知…")
                .font(.headline)
            Text("稍等一下，最新互动马上出现")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .allowsHitTesting(false)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "还没有通知",
            systemImage: "bell.badge",
            description: Text("有人和你互动时，这里会自动更新")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var footerView: some View {
        if notifyManager.hasNextPage {
            if notificationFilter == .all {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载更多通知…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                Button {
                    Task {
                        await notifyManager.loadNextPage()
                    }
                } label: {
                    if notifyManager.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("加载更多通知", systemImage: "arrow.down")
                    }
                }
                .disabled(notifyManager.isLoading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            }
        } else if notifyManager.totalCount > 0 {
            Text("已加载全部 \(notifyManager.totalCount) 条通知")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        }
    }

    private var pendingRefreshBanner: some View {
        HStack {
            Spacer()
            Button {
                notifyManager.applyPendingRefresh()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .imageScale(.medium)
                    Text(pendingRefreshText)
                        .lineLimit(1)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, 8)
    }

    private var pendingRefreshText: String {
        if notifyManager.pendingNewCount > 0 {
            return "有 \(notifyManager.pendingNewCount) 条新通知，点击更新"
        }
        return "有新通知，点击更新"
    }
}

private enum NotificationFilter: String {
    case all
    case unread

    var title: String {
        switch self {
        case .all: "全部"
        case .unread: "未读"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: "还没有通知"
        case .unread: "没有未读通知"
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .unread: "envelope.badge"
        }
    }
}

private extension View {
    /// 保持原卡片样式：去掉系统分隔线与行背景，行间距与原 LazyVStack 一致。
    func notificationListRow() -> some View {
        listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    @Previewable var navManager = NavigationManager()
    NotifyView().environmentObject(navManager)
}
