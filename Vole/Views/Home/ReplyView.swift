//
//  ReplyView.swift
//  Vole
//
//  Created by 杨权 on 8/22/25.
//

import Kingfisher
import SwiftUI

struct ReplyRowView: View {
    @State private var showAlert = false
    @State private var selectedUser: Member?
    @Binding var path: NavigationPath
    let topic: Topic
    let reply: Reply
    let floor: Int
    let showsConversationIndicator: Bool
    var onMentionsChanged: (([String]) -> Void)? = nil
    /// 点击 @用户名 时回调。
    let onMentionTap: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            replyAvatar

            VStack(alignment: .leading, spacing: 8) {
                replyHeader

                VoleMarkdownView(
                    content: reply.content,
                    onMentionsChanged: { mentions in
                        onMentionsChanged?(mentions)
                    },
                    onLinkAction: { action in
                        switch action {
                        case .mention(let username):
                            onMentionTap(username)
                        case .topic(let id):
                            path.append(Route.topicId(id))
                        case .node(let name):
                            path.append(Route.nodeName(name))
                        }
                    }
                )
            }
        }
        .padding(.vertical, 12)
        .sheet(item: $selectedUser) { member in
            NavigationStack {
                memberDetailView(for: member)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func memberDetailView(for member: Member) -> some View {
        List {
            MemberDetailView(member: member)
        }
        .navigationTitle(member.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .destructive) {
                    showAlert = true
                } label: {
                    Image(systemName: "person.slash")
                        .foregroundStyle(.red)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    selectedUser = nil
                } label: {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .font(.title)
                    }
                }
            }
        }
        .alert("确定要屏蔽该用户吗？", isPresented: $showAlert) {
            Button("确认屏蔽", role: .destructive) {
                withAnimation(.spring()) {
                    BlockManager.shared.block(member.username)
                }
                selectedUser = nil
            }
            Button("取消", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var replyAvatar: some View {
        if let avatarURL = reply.member.avatarNormal,
            let url = URL(string: avatarURL)
        {
            Button {
                selectedUser = reply.member
            } label: {
                KFImage(url)
                    .placeholder {
                        Circle()
                            .fill(Color.gray.opacity(0.18))
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
            }
            .buttonStyle(.borderless)
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
        }
    }

    private var replyHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(reply.member.username)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if topic.member?.username == reply.member.username {
                        ReplyIdentityBadge(
                            systemImage: "person.fill",
                            tint: Color.accentColor,
                            accessibilityLabel: "楼主"
                        )
                    }

                    if let pro = reply.member.pro, pro > 0 {
                        ReplyIdentityBadge(
                            systemImage: "rosette",
                            tint: .yellow,
                            accessibilityLabel: "会员"
                        )
                    }
                }

                RelativeTimeText(timestamp: reply.created)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            replyMetaActions
        }
    }

    private var replyMetaActions: some View {
        HStack(spacing: 6) {
            
            if showsConversationIndicator {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .accessibilityLabel("查看对话")
            }
            
            Text("\(floor + 1)楼")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 42)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.10))
                )
        }
    }
}

/// 仅比较影响显示的内容。配合 `.equatable()` 使用，
/// 父视图因动画等状态变化重绘时跳过回复内容，避免重复解析和排版 Markdown。
extension ReplyRowView: Equatable {
    nonisolated static func == (lhs: ReplyRowView, rhs: ReplyRowView) -> Bool {
        lhs.reply.id == rhs.reply.id
            && lhs.reply.content == rhs.reply.content
            && lhs.floor == rhs.floor
            && lhs.showsConversationIndicator == rhs.showsConversationIndicator
            && lhs.topic.member?.username == rhs.topic.member?.username
    }
}

private struct ReplyIdentityBadge: View {
    let systemImage: String
    let tint: Color
    let accessibilityLabel: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(tint.opacity(0.14))
            )
            .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    //    @Previewable @State var path = NavigationPath()
    //    let topic: Topic = ModelData().topics[0]
    //    let member = Member(id: 123, username: "hello")
    //    let reply = Reply(id: 110, content: "帮 OP 重发图片。    ![image](https://i.imgur.com/61pfQZT.png) ![image](https://i.imgur.com/4WJyF6w.png) ![image](https://i.imgur.com/KEBNsVW.png)", contentRendered: "", created: 1, member: member)
    //    ReplyRowView(path: $path,topic: topic, reply: reply, floor: 1)
    //
}
