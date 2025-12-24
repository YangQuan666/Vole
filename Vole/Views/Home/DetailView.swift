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
    @StateObject private var nodeManager = NodeManager.shared
    @State private var allMentions: [Int: [String]] = [:]
    //    @State private var navTitle: String = "帖子"
    @State private var selectedReply: Reply? = nil
    @State private var showSafari = false
    @State private var safariURL: URL? = nil
    @State private var showUserInfo = false
    @State private var selectedUser: Member?
    @State private var showAlert = false
    @State private var showReportDialog = false

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
                                //                                navTitle = "帖子"
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
                            Button {
                                selectedUser = topic.member
                                showUserInfo = true
                            } label: {
                                HStack {
                                    if let avatarURL = topic.member?
                                        .avatarNormal
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
                                        TimelineView(.everyMinute) { _ in
                                            Text(
                                                DateConverter.relativeTimeString(
                                                    created
                                                )
                                            )
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
                            Spacer()
                            Button {
                                if let node = topic.node {
                                    if let n = nodeManager.getNode(node.id) {
                                        path.append(Route.node(n))
                                    } else {
                                        path.append(Route.node(node))
                                    }
                                }
                            } label: {
                                Text(topic.node?.title ?? "")
                                    .font(.callout)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(
                                            cornerRadius: 8,
                                            style: .continuous
                                        )
                                        .fill(
                                            Color.accentColor.opacity(0.15)
                                        )
                                    )
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowSeparator(.hidden)

                        VStack(alignment: .leading) {
                            // 标题
                            if let title = topic.title {
                                Button {
                                    if let url = URL(string: topic.url ?? "") {
                                        safariURL = url
                                        showSafari = true
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
                                            path.append(Route.topicId(id))
                                        default:
                                            break
                                        }
                                    }
                                )
                            }
                            if let supplements = topic.supplements,
                                !supplements.isEmpty
                            {
                                ForEach(supplements.indices, id: \.self) {
                                    idx in
                                    let supplement = supplements[idx]

                                    VStack(alignment: .leading, spacing: 8) {
                                        Divider()
                                        HStack(alignment: .bottom) {
                                            Text("第 \(idx + 1)条附言")
                                                .foregroundColor(.secondary)
                                            if let created = supplement.created
                                            {
                                                TimelineView(.everyMinute) {
                                                    _ in
                                                    Text(
                                                        DateConverter
                                                            .relativeTimeString(
                                                                created
                                                            )
                                                    )
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                }
                                            }
                                        }

                                        MarkdownView(
                                            content: supplement.content ?? "",
                                            onMentionsChanged: nil,
                                            onLinkAction: { action in
                                                switch action {
                                                case .mention(let username):
                                                    print("@\(username)")
                                                case .topic(let id):
                                                    path.append(
                                                        Route.topicId(id)
                                                    )
                                                default:
                                                    break
                                                }
                                            }
                                        )
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                    }

                    // 评论区
                    Section {
                        if replyVM.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .listRowSeparator(.hidden)
                        } else if let replies = replyVM.replies {
                            if replies.isEmpty {
                                Text("暂无评论，快来抢沙发吧~")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .listRowSeparator(.hidden)
                            } else {
                                Text(replies.count > 0 ? "评论(\(replies.count))" : "评论")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .listRowSeparator(.hidden)
                                
                                ForEach(
                                    Array((replies).enumerated()),
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
                                            // navTitle = "对话"
                                        }
                                    }
                                    .swipeActions(
                                        edge: .trailing,
                                        allowsFullSwipe: true
                                    ) {
                                        Button {
                                            UIPasteboard.general.string =
                                                replies[index].content

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
                }
                .disabled(selectedReply != nil)
                .listStyle(.plain)
                .refreshable {
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            await loadTopic()
                        }
                        group.addTask {
                            await replyVM.load(topicId: topic.id)
                        }
                    }
                }
                .task(id: topic.id) {
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            await loadTopic()
                        }

                        group.addTask {
                            await replyVM.load(topicId: topic.id)
                        }
                    }
                }
            } else if topicId != nil {
                // 还没有加载到 topic
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await loadTopic()
                    }
            }
        }
        //        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                let shareURL = topic?.url ?? ""
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed)
            }
            ToolbarItem {
                let shareURL = topic?.url ?? ""
                Menu {
                    Button("访问节点", systemImage: "scale.3d") {
                        if let topic = topic, let node = topic.node {
                            path.append(Route.node(node))
                        }
                    }
                    Button("屏蔽内容", systemImage: "text.page.slash") {
                        showAlert = true
                    }
                    Button("举报内容", systemImage: "exclamationmark.bubble") {
                        showReportDialog = true
                    }
                    Button("在浏览器中打开", systemImage: "safari") {
                        if let url = URL(string: shareURL) {
                            openURL(url)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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
        .sheet(isPresented: $showUserInfo) {
            MemberView(member: selectedUser)
                .presentationDetents([.medium, .large])  // 半屏 & 全屏
                .presentationDragIndicator(.visible)  // 上拉手柄
        }
        .environment(\.appOpenURL) { url in
            safariURL = url
            showSafari = true
        }
        .alert("确定要屏蔽该话题吗？", isPresented: $showAlert) {
            Button("确认屏蔽", role: .destructive) {
                Task {
                    await V2exAPI.shared.blockTopic(topic: topic)
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            "选择举报原因",
            isPresented: $showReportDialog,
            titleVisibility: .visible
        ) {
            Button("垃圾广告", role: .destructive) {
                Task {
                    await V2exAPI.shared.report(topic: topic, reason: "垃圾广告")
                }
            }
            Button("色情或低俗内容", role: .destructive) {
                Task {
                    await V2exAPI.shared.report(topic: topic, reason: "色情或低俗内容")
                }
            }
            Button("人身攻击 / 仇恨言论", role: .destructive) {
                Task {
                    await V2exAPI.shared.report(
                        topic: topic,
                        reason: "人身攻击 / 仇恨言论"
                    )
                }
            }
            Button("违法或不当内容", role: .destructive) {
                Task {
                    await V2exAPI.shared.report(topic: topic, reason: "违法或不当内容")
                }
            }
            Button("其他原因", role: .destructive) {
                Task {
                    await V2exAPI.shared.report(topic: topic, reason: "其他原因")
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var listHeaderView: some View {
        if let count = replyVM.replies?.count {
            return Text("评论(\(count))").font(.headline)
        }
        return Text("评论").font(.headline)
    }

    private func loadTopic() async {
        guard topic == nil else { return }
        guard let id = topicId else { return }
        do {
            let response = try await V2exAPI.shared.topic(topicId: id)
            if let r = response, r.success, let newTopic = r.result {
                topic = newTopic
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
    //    @Previewable @State var path = NavigationPath()
    //    let topic: Topic = ModelData().topics[0]
    //    DetailView(topicId: nil, topic: topic, path: $path)
}
