//
//  DetailView.swift
//  Vole
//
//  Created by 杨权 on 8/21/25.
//

import Kingfisher
import SwiftUI

struct DetailView: View {
    @Namespace private var ns

    let topicId: Int?
    @State var topic: Topic?

    @StateObject private var replyVM = ReplyViewModel()
    @State private var allMentions: [Int: [String]] = [:]

    @State private var selectedReply: Reply? = nil
    @State private var showSafari = false
    @State private var safariURL: URL? = nil

    @Environment(\.openURL) private var openURL
    @Environment(\.appOpenURL) private var appOpenURL
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            if let topic = topic {
                // 浮层对话视图
                if let reply = selectedReply {
                    ZStack {
                        // 全屏背景模糊
                        Color.clear
                            .background(.ultraThinMaterial)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(dampingFraction: 0.6)) {
                                    selectedReply = nil
                                }
                            }

                        // 浮层内容
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(
                                    conversation(for: reply),
                                    id: \.0.id
                                ) {
                                    r,
                                    floor in
                                    ReplyRowView(
                                        path: $path,
                                        topic: topic,
                                        reply: r,
                                        floor: floor
                                    )
                                    .matchedGeometryEffect(
                                        id: r.id,
                                        in: ns,
                                        isSource: selectedReply != nil
                                    )
                                    Divider()
                                        .padding(.leading, 48)
                                }
                            }
                            .padding()
                        }
                        .onTapGesture {
                            withAnimation(.spring(dampingFraction: 0.6)) {
                                selectedReply = nil
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }

                List {
                    // 帖子详情部分
                    Section {
                        // 头像 + 昵称
                        HStack {
                            if let avatarURL = topic.member?.avatarNormal
                                ?? topic.member?.avatar,
                                let url = URL(string: avatarURL)
                            {
                                KFImage(url)
                                    .placeholder {
                                        Color.gray
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 24, height: 24)
                            }

                            Text(topic.member?.username ?? "")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            if let created = topic.created {
                                Text(formattedTime(created))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(topic.node?.title ?? "")
                                .font(.subheadline)

                        }
                        .listRowSeparator(.hidden)

                        VStack(alignment: .leading) {
                            // 标题
                            if let title = topic.title {
                                Button {
                                    if let url = URL(string: topic.url ?? "") {
                                        appOpenURL(url)
                                    }
                                } label: {
                                    Text(title)
                                        .font(.title)
                                        .bold()
                                        .textSelection(.enabled)
                                }
                                .buttonStyle(.plain)  // 避免整行高亮
                            }
                            // 内容
                            if let content = topic.content, !content.isEmpty {
                                Divider()
                                MarkdownView(
                                    content: content,
                                    onMentionsChanged: nil,
                                    onLinkAction: { action in
                                        switch action {
                                        case .mention(let username):
                                            print("@\(username)")
                                        case .topic(let id):
                                            path.append(
                                                TopicRoute(
                                                    id: id,
                                                    topic: nil
                                                )
                                            )
                                        //                                        case .external(let url):
                                        //                                            openInApp(url)
                                        default:
                                            break
                                        }
                                    }
                                )
                            }
                        }
                        .listRowSeparator(.hidden)
                    }

                    // 评论区
                    Section(header: Text("评论").font(.headline)) {
                        if replyVM.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .listRowSeparator(.hidden)
                        } else if replyVM.replies?.isEmpty ?? true {
                            Text("暂无评论，快来抢沙发吧~")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(
                                Array((replyVM.replies ?? []).enumerated()),
                                id: \.1.id
                            ) { index, reply in
                                ReplyRowView(
                                    path: $path,
                                    topic: topic,
                                    reply: reply,
                                    floor: index
                                )
                                .matchedGeometryEffect(
                                    id: reply.id,
                                    in: ns,
                                    isSource: selectedReply == nil
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(
                                        .spring(dampingFraction: 0.6)
                                    ) {
                                        selectedReply = reply
                                    }
                                }
                                .swipeActions(
                                    edge: .trailing,
                                    allowsFullSwipe: true
                                ) {
                                    Button {
                                        UIPasteboard.general.string =
                                            replyVM.replies![index].content

                                        let generator =
                                            UINotificationFeedbackGenerator()
                                        generator.notificationOccurred(
                                            .success
                                        )
                                    } label: {
                                        Label(
                                            "复制",
                                            systemImage: "doc.on.doc"
                                        )
                                    }
                                    .tint(.accentColor)
                                }
                            }
                        }
                    }
                }
                .disabled(selectedReply != nil)
                .listStyle(.plain)
                .navigationTitle("帖子")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable {
                    await replyVM.load(topicId: topic.id)
                }
                .task(id: topic.id) {
                    if replyVM.replies == nil {
                        await replyVM.load(topicId: topic.id)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        ShareLink(item: topic.url ?? "") {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Menu {
                            Button("访问节点", systemImage: "scale.3d") {

                            }
                            Button("复制链接", systemImage: "link") {
                                UIPasteboard.general.string = topic.url
                                let generator =
                                    UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            }
                            Button("在浏览器中打开", systemImage: "safari") {
                                if let url = URL(string: topic.url ?? "") {
                                    openURL(url)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }

            } else if topicId != nil {
                // 还没有加载到 topic
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await loadTopicIfNeeded()
                    }
            }
        }
        .sheet(isPresented: $showSafari) {
            if let safariURL {
                SafariView(url: safariURL)
                    .ignoresSafeArea()
                    .interactiveDismissDisabled(true)
            }
        }
        .environment(\.appOpenURL) { url in
            safariURL = url
            showSafari = true
        }
    }
    private func loadTopicIfNeeded() async {
        guard topic == nil, let topicId else { return }
        do {
            let response = try await V2exAPI.shared.topic(topicId: topicId)
            if let r = response, r.success {
                topic = r.result
            }
        } catch {
            print("❌ 获取 Topic 失败: \(error)")
        }
    }

    // 获取当前点击回复的对话列表，并返回实际楼层
    private func conversation(for reply: Reply) -> [(Reply, Int)] {
        guard let replies = replyVM.replies else { return [] }
        guard let idx = replies.firstIndex(where: { $0.id == reply.id }) else {
            return [(reply, 0)]
        }

        let currentUser = reply.member.username
        let mentionedUsers = extractMentionedUsers(from: reply.content)

        var conversation: [(Reply, Int)] = []

        if !mentionedUsers.isEmpty {
            // 倒序遍历，收集自己 + 被提及用户的回复
            for i in stride(from: idx, through: 0, by: -1) {
                let r = replies[i]
                if r.member.username == currentUser
                    || mentionedUsers.contains(r.member.username)
                {
                    conversation.append((r, i))
                }
            }
            return conversation.reversed()
        } else {
            // 没有提及用户：表示是发表者自己发的
            // 从当前楼层往后遍历，收集所有回复了当前用户的评论
            conversation.append((reply, idx))  // 先加自己
            for i in (idx + 1)..<replies.count {
                let r = replies[i]
                let rMentions = extractMentionedUsers(from: r.content)
                if rMentions.contains(currentUser) {
                    conversation.append((r, i))
                }
            }
            return conversation
        }
    }

    // 提取 @ 用户名
    private func extractMentionedUsers(from content: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "@([A-Za-z0-9_]+)")
        let matches = regex.matches(
            in: content,
            range: NSRange(content.startIndex..., in: content)
        )
        return matches.compactMap {
            Range($0.range(at: 1), in: content).map { String(content[$0]) }
        }
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    let topic: Topic = ModelData().topics[0]
    DetailView(topicId: nil, topic: topic, path: $path)
}
