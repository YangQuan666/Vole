//
//  NotifyView.swift
//  Vole
//
//  Created by 杨权 on 8/25/25.
//

import SwiftUI

struct NotifyView: View {
    @State private var showProfile = false
    @State private var showAlert = false
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
                    if notifyManager.unreadCount > 0 {
                        ToolbarItem {
                            Button {
                                showAlert = true
                            } label: {
                                Image(systemName: "tray.and.arrow.down")
                            }
                        }
                        if #available(iOS 26.0, *) {
                            ToolbarSpacer(.fixed)
                        }
                    }
                    ToolbarItem {
                        AvatarView {
                            showProfile = true
                        }
                    }
                }
                .alert("一键已读所有通知？", isPresented: $showAlert) {
                    Button("确认", role: .destructive) {
                        notifyManager.markAllRead()
                    }
                    Button("取消", role: .cancel) {}
                }
                .sheet(isPresented: $showProfile) {
                    ProfileView()
                }
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
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(notifyManager.notifications, id: \.id) { item in
                    NotifyRowView(item: item) { topicId in
                        navManager.notifyPath.append(Route.topicId(topicId))
                    }
                    .onAppear {
                        if item.id == notifyManager.notifications.last?.id {
                            Task {
                                await notifyManager.loadNextPage()
                            }
                        }
                    }
                }

                footerView
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
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
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("正在加载更多通知…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
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

#Preview {
    @Previewable var navManager = NavigationManager()
    NotifyView().environmentObject(navManager)
}
