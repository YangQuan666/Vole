//
//  NotifyView.swift
//  Vole
//
//  Created by 杨权 on 8/25/25.
//

import Kingfisher
import SwiftSoup
import SwiftUI

struct NotifyView: View {

    @State private var showProfile = false
    @State private var showAlert = false
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var notifyManager = NotifyManager.shared
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        NavigationStack(path: $navManager.notifyPath) {
            Group {
                if notifyManager.notifications.isEmpty {
                    Text("暂无通知")
                        .foregroundStyle(.secondary)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .center
                        )
                        .listRowSeparator(.hidden)
                } else {
                    List {
                        Section(footer: footerView) {
                            ForEach(notifyManager.notifications, id: \.id) {
                                item in
                                NotifyRowView(item: item) { topicId in
                                    navManager.notifyPath.append(
                                        Route.topicId(topicId)
                                    )
                                }
                                .listRowInsets(EdgeInsets())
                                .onAppear {
                                    if item.id
                                        == notifyManager.notifications.last?.id
                                    {
                                        Task {
                                            await notifyManager.loadNextPage()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await notifyManager.refresh()
                    }
                }
            }
            .navigationTitle("通知")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .topicId(let topicId):
                    DetailView(topicId: topicId, path: $navManager.notifyPath)
                case .nodeName(let nodeName):
                    NodeDetailView(
                        nodeName: nodeName,
                        path: $navManager.nodePath
                    )
                case .node(let node):
                    NodeDetailView(node: node, path: $navManager.notifyPath)
                default: EmptyView()
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
    private var footerView: some View {
        // 底部加载更多动画
        if notifyManager.hasNextPage {
            VStack {
                ProgressView("加载中…")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowSeparator(.hidden)
        } else if notifyManager.totalCount > 0 {
            VStack {
                Text("已加载全部\(notifyManager.totalCount)条通知")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct ParsedNotification {
    let username: String
    let action: String
    let icon: String
    let color: Color
    let topicTitle: String?
    let topicId: Int?
}

#Preview {
    @Previewable var navManager = NavigationManager()
    NotifyView().environmentObject(navManager)
}
