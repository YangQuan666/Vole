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
    @State private var isLoading = false
    @EnvironmentObject var navManager: NavigationManager
    @ObservedObject private var userManager = UserManager.shared

    var body: some View {
        NavigationStack(path: $navManager.nodePath) {
            Group {
                if isLoading {
                    ProgressView("加载中…")
                        .padding()
                } else if notifications.isEmpty {
                    Text("暂无通知")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(notifications, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            // 主内容 text
                            if let text = item.text, let topic = parseTopic(html: text) {
                                Text(topic.title ?? "")
                                    .font(.subheadline)
                            }
                            // 用户名
                            Text("\(item.member?.username ?? "")回复了你：")
                                .font(.headline)
                            // payload
                            if let payload = item.payload {
                                Text(payload)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .onTapGesture {
                            // 你自己决定路由逻辑
                            navManager.notifyPath.append(
                                Route.topicId(1_163_971)
                            )
                        }
                    }
                }
            }
            .navigationTitle("通知")
            .refreshable {
                await loadNotifications()
            }
            .task {
                if notifications.isEmpty {  // 防止重复加载
                    await loadNotifications()
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .topicId(let topicId):
                    DetailView(topicId: topicId, path: $navManager.nodePath)
                case .nodeName(let nodeName):
                    NodeDetailView(
                        nodeName: nodeName,
                        path: $navManager.nodePath
                    )
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
        isLoading = true
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
        isLoading = false
    }

    private func parseTopic(html: String) -> Topic? {
        do {
            let document = try SwiftSoup.parse(html)
            let link = try document.select("a").select(".topic-link").first()
            if let link = link {
                let href = try link.attr("href")
                let title = try link.text()
                return Topic(
                    id: 0,
                    member: nil,
                    title: title,
                    url: nil,
                    created: nil,
                    deleted: nil,
                    content: href,
                    contentRendered: nil,
                    syntax: nil,
                    lastModified: nil,
                    replies: nil,
                    lastReplyBy: nil,
                    lastTouched: nil,
                    supplements: nil
                )
            }
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
}

#Preview {
    @Previewable var navManager = NavigationManager()
    NotifyView().environmentObject(navManager)
}
