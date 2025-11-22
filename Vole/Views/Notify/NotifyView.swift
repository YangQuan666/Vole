//
//  NotifyView.swift
//  Vole
//
//  Created by 杨权 on 8/25/25.
//

import SwiftSoup
import SwiftUI

struct NotifyView: View {
    @State private var notifications: [Notification] = []
    @EnvironmentObject var navManager: NavigationManager
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var notifyManager = NotifyManager.shared

    var body: some View {
        NavigationStack(path: $navManager.notifyPath) {
            Group {
                if notifications.isEmpty {
                    VStack {
                        Spacer()
                        Text("暂无通知")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else {
                    List {
                        Section {
                            ForEach(notifications, id: \.id) { item in
                                NotifyRowView(item: item) { topicId in
                                    navManager.notifyPath.append(
                                        Route.topicId(topicId)
                                    )
                                }
                            }
                        } header: {
                            HStack {
                                Spacer()
                                Button {
                                    notifyManager.markAllRead(
                                        notifications.map { $0.id }
                                    )
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle")
                                        Text("一键已读")
                                    }
                                    .font(.subheadline)
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
                if notifications.isEmpty {  // 防止重复加载
                    await loadNotifications()
                }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    // 加载数据
    private func loadNotifications() async {
        guard let t = userManager.token else { return }
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
