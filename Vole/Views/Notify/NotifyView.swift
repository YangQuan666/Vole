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
    @State private var notifications: [Notification]? = nil
    @State private var showProfile = false
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var notifyManager = NotifyManager.shared
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        NavigationStack(path: $navManager.notifyPath) {
            Group {
                if notifications == nil {
                    // 加载中 UI
                    VStack {
                        ProgressView("加载中…")
                            .progressViewStyle(.circular)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let notifications, notifications.isEmpty {
                    Text("暂无通知")
                        .foregroundStyle(.secondary)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .center
                        )
                        .listRowSeparator(.hidden)
                } else {
                    List {
                        Section {
                            ForEach(notifications ?? [], id: \.id) { item in
                                NotifyRowView(item: item) { topicId in
                                    navManager.notifyPath.append(
                                        Route.topicId(topicId)
                                    )
                                }
                                .listRowInsets(EdgeInsets())
                            }
                        } header: {
                            if let notifications, !notifications.isEmpty {
                                HStack {
                                    Spacer()
                                    Button {
                                        notifyManager.markAllRead(
                                            notifications.map { $0.id }
                                        )
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(
                                                systemName: "checkmark.circle"
                                            )
                                            Text("一键已读")
                                        }
                                        .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadNotifications()
                    }
                }
            }
            .navigationTitle("通知")
            .task {
                await loadNotifications()
            }
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
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }

    // 加载数据
    private func loadNotifications() async {
        guard let t = userManager.token else {
            notifications = []
            return
        }
        do {
            let response = try await V2exAPI().notifications(
                page: 1,
                token: t.token ?? ""
            )
            if let r = response, r.success, let n = r.result {
                notifications = n
            }
        } catch {
            print(error.localizedDescription)
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
