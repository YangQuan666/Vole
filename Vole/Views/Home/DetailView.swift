//
//  DetailView.swift
//  Vole
//
//  Created by 杨权 on 8/21/25.
//

import Kingfisher
import MarkdownUI
import SwiftUI

struct DetailView: View {
    @State var topic: Topic
    @Environment(\.openURL) private var openURL
    @StateObject private var replyVM = ReplyViewModel()
    @State private var allMentions: [Int: [String]] = [:]
    @Namespace private var ns
    @State private var selectedReply: Reply? = nil

    var body: some View {
        ZStack {
            // 浮层对话视图
            if let reply = selectedReply {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring()) {
                                selectedReply = nil
                            }
                        }

                        VStack(spacing: 12) {
                            ForEach(conversation(for: reply), id: \.id) { r in
                                ReplyRowView(reply: r, floor: 0)
                                    .matchedGeometryEffect(
                                        id: r.id,
                                        in: ns,
                                        isSource: false
                                    )
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                }
                .transition(.opacity)
                .zIndex(1)
            }

            List {
                // 帖子详情部分
                Section {
                    // 头像 + 昵称
                    HStack {
                        if let avatarURL = topic.member?.avatarNormal,
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

                        Text(topic.member?.username ?? "未知用户")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .listRowSeparator(.hidden)

                    VStack(alignment: .leading) {
                        // 标题
                        if let title = topic.title {
                            Text(title)
                                .font(.title2)
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                        // 内容
                        if let content = topic.content, !content.isEmpty {
                            Divider()
                            MarkdownView(content: content)
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
                            ReplyRowView(reply: reply, floor: index)
                                .matchedGeometryEffect(
                                    id: reply.id,
                                    in: ns,
                                    isSource: selectedReply == nil
                                )
                                .onTapGesture {
                                    withAnimation(.spring()) {
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
                                        generator.notificationOccurred(.success)
                                    } label: {
                                        Label("复制", systemImage: "doc.on.doc")
                                    }
                                    .tint(.accentColor)
                                }
                        }
                    }
                }
            }
            .disabled(selectedReply != nil)
            .listStyle(.plain)
            .navigationTitle(topic.node?.title ?? "")
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
                            let generator = UINotificationFeedbackGenerator()
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

        }
    }

    // 获取当前点击回复的对话列表（按 index 顺序）
    private func conversation(for reply: Reply) -> [Reply] {
        guard let replies = replyVM.replies else { return [] }
        guard let idx = replies.firstIndex(where: { $0.id == reply.id }) else {
            return [reply]
        }

        let currentUser = reply.member.username
        let mentionedUsers = extractMentionedUsers(from: reply.content)

        var conversation: [Reply] = []

        for r in replies[...idx].reversed() {
            if r.member.username == currentUser
                || mentionedUsers.contains(r.member.username)
            {
                conversation.append(r)
            }
        }

        return conversation.reversed()
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
    DetailView(topic: ModelData().topics[0])
}
