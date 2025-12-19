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
                                    //
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
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        AvatarView {
                            showProfile = true
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        AvatarView {
                            showProfile = true
                        }
                    }
                }
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
    let topicTitle: String?
    let topicId: Int?
}

#Preview {
    @Previewable var navManager = NavigationManager()
    NotifyView().environmentObject(navManager)
}
