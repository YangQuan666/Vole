//
//  DetailView.swift
//  Vole
//
//  Created by 杨权 on 8/21/25.
//

import Kingfisher
import SwiftUI

struct DetailView: View {
    let topicId: Int?
    @State var topic: Topic?

    private let reportReasons = [
        "垃圾广告",
        "色情或低俗内容",
        "人身攻击 / 仇恨言论",
        "违法或不当内容",
        "其他原因",
    ]

    @State private var selectedConversation: ReplyConversation?
    @State private var selectedConversationReplyId: Int?
    @State private var selectedAuthor: String?
    /// 浮层中从列表浮起的回复。
    @State private var threadHeroReplyID: Int?
    /// 浮起到浮层、在列表中暂时隐藏的回复。
    @State private var threadState = ReplyThreadState()
    @State private var replyFrames = ReplyFrameStore()
    @State private var conversationIndex = ReplyConversationIndex.empty
    @State private var selectedUser: Member?
    @State private var showBlockTopicAlert = false
    @State private var showBlockUserAlert = false
    @State private var showReportDialog = false
    @State private var showReplyComposer = false
    @State private var showReplyLogin = false
    @State private var replyTarget: Member?
    @State private var topicLoadErrorMessage: String?
    @State private var repliesLoadErrorMessage: String?
    @State private var isSubmittingReport = false
    @State private var reportResultMessage: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject private var nodeManager = NodeManager.shared
    @ObservedObject var blockManager = BlockManager.shared
    @ObservedObject private var userManager = UserManager.shared

    @State private var replies: [Reply]? = nil
    @State var isLoading = false
    private var visibleReplyItems: [ReplyConversationItem]? {
        guard replies != nil else { return nil }
        return conversationIndex.items
    }

    private var isCommentOverlayPresented: Bool {
        selectedConversation != nil || selectedAuthor != nil
    }

    private var commentRowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
    }

    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            if let topic = topic {
                ScrollViewReader { scrollProxy in
                    ZStack {
                        List {
                            // 帖子详情部分
                            Section {
                                VStack(alignment: .leading, spacing: 14) {
                                    topicHeader(for: topic)

                                    if let title = topic.title {
                                        topicTitleButton(title, urlString: topic.url)
                                    }

                                    if let content = topic.content, !content.isEmpty {
                                        VStack(alignment: .leading, spacing: 12) {
                                            if content.isLikelyHTML {
                                                HTMLContentNotice(
                                                    url: topic.url.flatMap(URL.init(string:)),
                                                    openURL: { url in
                                                        openURL.openPreferringInApp(url)
                                                    }
                                                )
                                            }

                                            VoleMarkdownView(
                                                content: content,
                                                onMentionsChanged: nil,
                                                onLinkAction: handleMarkdownLinkAction
                                            )
                                        }
                                    }

                                    topicSupplements(for: topic)

                                    topicEngagementMetrics(for: topic)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .listRowInsets(
                                    EdgeInsets(
                                        top: 14,
                                        leading: 16,
                                        bottom: 14,
                                        trailing: 16
                                    )
                                )
                            }

                            commentsSection(for: topic)

                        }
                        .refreshable {
                            let id =  topic.id
                            await withTaskGroup(of: Void.self) { group in
                                group.addTask {
                                    await loadTopic()
                                }
                                group.addTask {
                                    await loadReply(topicId: id, force: true)
                                }
                            }
                        }
                        .task(id: topic.id) {
                            let id =  topic.id
                            await withTaskGroup(of: Void.self) { group in
                                group.addTask {
                                    await loadTopic()
                                }
                                group.addTask {
                                    await loadReply(topicId: id)
                                }
                            }
                        }

                        if let selectedConversation {
                            replyThreadOverlay(
                                title: "对话",
                                subtitle: conversationSubtitle(selectedConversation),
                                systemImage: "bubble.left.and.bubble.right.fill",
                                items: selectedConversation.items,
                                topic: topic,
                                scrollProxy: scrollProxy
                            )
                            .id(selectedConversation.id)
                        } else if let selectedAuthor {
                            let items = authorReplyItems(for: selectedAuthor)
                            replyThreadOverlay(
                                title: "只看 \(selectedAuthor)",
                                subtitle: "\(items.count.formattedCount) 条评论",
                                systemImage: "person.text.rectangle",
                                items: items,
                                topic: topic,
                                scrollProxy: scrollProxy
                            )
                            .id(selectedAuthor)
                        }
                    }
                }
            } else if let errorMessage = topicLoadErrorMessage {
                topicUnavailableView(message: errorMessage)
            } else if topicId != nil {
                // 还没有加载到 topic
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await loadTopic()
                    }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isCommentOverlayPresented {
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
                            showBlockTopicAlert = true
                        }
                        Button("举报内容", systemImage: "exclamationmark.bubble") {
                            showReportDialog = true
                        }
                        .disabled(isSubmittingReport)
                        Button("在浏览器中打开", systemImage: "safari") {
                            openWebPage(for: shareURL)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    commentOverlayCloseButton
                }
            }
        }
        .sheet(item: $selectedUser) { member in
            NavigationStack {
                memberDetailView(for: member)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReplyComposer, onDismiss: {
            replyTarget = nil
        }) {
            if let topic {
                NavigationStack {
                    ReplyComposerView(
                        topicID: topic.id,
                        replyTo: replyTarget
                    ) {
                        Task {
                            await loadReply(topicId: topic.id, force: true)
                        }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showReplyLogin) {
            ProfileView()
        }
        .alert("确定要屏蔽该话题吗？", isPresented: $showBlockTopicAlert) {
            Button("确认屏蔽", role: .destructive) {
                blockCurrentTopic()
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            "选择举报原因",
            isPresented: $showReportDialog,
            titleVisibility: .visible
        ) {
            ForEach(reportReasons, id: \.self) { reason in
                Button(reason, role: .destructive) {
                    submitReport(reason: reason)
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert(
            "举报",
            isPresented: Binding(
                get: { reportResultMessage != nil },
                set: { if !$0 { reportResultMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(reportResultMessage ?? "")
        }
        .onChange(of: isCommentOverlayPresented) { _, isPresented in
            // 浮层被直接移除（如屏蔽用户后对话消失）时，恢复列表中隐藏的回复。
            if !isPresented {
                resetReplyThreadState()
            }
        }
        .onChange(of: blockManager.blockedUsernames) { _, _ in
            rebuildConversationCacheFromCurrentReplies()
        }
    }

    /// 本地立即屏蔽并返回上一页，同时通知开发者
    private func blockCurrentTopic() {
        guard let topic else { return }
        blockManager.blockTopic(topic.id)
        let reporter = userManager.currentMember?.username
        Task {
            try? await ReportService.shared.blockTopic(topic, reporter: reporter)
        }
        dismiss()
    }

    private func submitReport(reason: String) {
        guard let topic, !isSubmittingReport else { return }
        isSubmittingReport = true
        Task {
            do {
                try await ReportService.shared.report(topic, reason: reason)
                reportResultMessage = "已收到你的举报，我们会在 24 小时内处理。"
            } catch {
                reportResultMessage = error.localizedDescription
            }
            isSubmittingReport = false
        }
    }

    private func topicUnavailableView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "text.page.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.quaternary)

            VStack(spacing: 8) {
                Text("主题不存在")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func topicHeader(for topic: Topic) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                topicAuthorView(for: topic)

                Spacer(minLength: 12)

                if let node = topic.node {
                    topicNodeButton(node)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                topicAuthorView(for: topic)

                if let node = topic.node {
                    topicNodeButton(node)
                }
            }
        }
    }

    @ViewBuilder
    private func topicAuthorView(for topic: Topic) -> some View {
        if let member = topic.member {
            Button {
                selectedUser = member
            } label: {
                topicAuthorContent(member: member, created: topic.created)
            }
            .buttonStyle(.plain)
        } else {
            topicAuthorContent(member: nil, created: topic.created)
        }
    }

    private func topicAuthorContent(member: Member?, created: Int?) -> some View {
        HStack(spacing: 10) {
            topicAuthorAvatar(for: member)

            VStack(alignment: .leading, spacing: 2) {
                Text(member?.username ?? "匿名用户")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let created {
                    RelativeTimeText(timestamp: created)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func topicAuthorAvatar(for member: Member?) -> some View {
        if let avatarURL = member?.avatarNormal ?? member?.avatar,
            let url = URL(string: avatarURL)
        {
            KFImage(url)
                .placeholder {
                    Circle()
                        .fill(Color.gray.opacity(0.18))
                }
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func topicNodeButton(_ node: Node) -> some View {
        Button {
            if let cachedNode = nodeManager.getNode(node.id) {
                path.append(Route.node(cachedNode))
            } else {
                path.append(Route.node(node))
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "square.stack.3d.up")
                    .imageScale(.small)

                Text(node.title ?? node.name)
                    .lineLimit(1)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    /// 帖子末尾的互动数据。回复数已显示在评论区标题中，这里不再重复。
    @ViewBuilder
    private func topicEngagementMetrics(for topic: Topic) -> some View {
        let stars = topic.stars ?? 0
        let thanks = topic.thanks ?? 0

        if stars > 0 || thanks > 0 {
            VStack(spacing: 10) {
                Divider()

                // 两项各占一半宽度并居中，像工具栏一样左右平衡。
                HStack(spacing: 0) {
                    topicMetric(value: stars, label: "收藏", systemImage: "star")
                        .frame(maxWidth: .infinity)

                    topicMetric(value: thanks, label: "感谢", systemImage: "heart")
                        .frame(maxWidth: .infinity)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
            .padding(.top, 2)
        }
    }

    private func topicMetric(
        value: Int,
        label: String,
        systemImage: String
    ) -> some View {
        Label {
            Text("\(value.formattedCount) \(label)")
                .monospacedDigit()
        } icon: {
            Image(systemName: systemImage)
        }
        .labelStyle(.titleAndIcon)
    }

    /// 附言并入帖子卡片，接在正文之后，左侧以主题色竖线标示。
    /// Markdown 引用的竖线为灰色，两者以颜色区分。
    @ViewBuilder
    private func topicSupplements(for topic: Topic) -> some View {
        let supplements = (topic.supplements ?? []).filter {
            !($0.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if !supplements.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(supplements.enumerated()), id: \.element.id) { index, supplement in
                    supplementBlock(
                        supplement,
                        title: supplements.count > 1 ? "附言 \(index + 1)" : "附言"
                    )
                }
            }
            .padding(.top, 4)
        }
    }

    private func supplementBlock(_ supplement: Supplement, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)

                if let created = supplement.created {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    RelativeTimeText(timestamp: created)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            .accessibilityElement(children: .combine)

            VoleMarkdownView(
                content: supplement.content ?? "",
                onMentionsChanged: nil,
                onLinkAction: handleMarkdownLinkAction
            )
        }
        .padding(.leading, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(Color.accentColor.opacity(0.4))
                .frame(width: 3)
        }
    }

    private func topicTitleButton(_ title: String, urlString: String?) -> some View {
        Button {
            openWebPage(for: urlString)
        } label: {
            Text(title)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityHint("打开主题原网页")
    }

    private func openWebPage(for urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        openURL.openPreferringInApp(url)
    }

    private func handleMarkdownLinkAction(_ action: LinkAction) {
        switch action {
        case .mention(let username):
            showMember(named: username)
        case .topic(let id):
            path.append(Route.topicId(id))
        case .node(let name):
            path.append(Route.nodeName(name))
        }
    }

    /// 优先使用本帖中已有的用户资料展示资料卡；
    /// 官方 API 2.0 不提供按用户名查询他人资料的接口，找不到时打开网页主页。
    private func showMember(named username: String) {
        if let member = knownMember(named: username) {
            selectedUser = member
        } else if let url = Member.profileURL(username: username) {
            openURL.openPreferringInApp(url)
        }
    }

    private func knownMember(named username: String) -> Member? {
        func matches(_ member: Member) -> Bool {
            member.username.caseInsensitiveCompare(username) == .orderedSame
        }

        if let author = topic?.member, matches(author) {
            return author
        }
        return replies?.last { matches($0.member) }?.member
    }

    @ViewBuilder
    private func commentsSection(for topic: Topic) -> some View {
        if isLoading {
            Section {
                commentsLoadingRow
                    .listRowInsets(commentRowInsets)
            } header: {
                commentsSectionHeader(count: nil)
            }
        } else if let errorMessage = repliesLoadErrorMessage, replies == nil {
            Section {
                commentsErrorRow(message: errorMessage, topicId: topic.id)
                    .listRowInsets(commentRowInsets)
            } header: {
                commentsSectionHeader(count: nil)
            }
        } else if let replies = visibleReplyItems {
            if replies.isEmpty {
                Section {
                    commentsEmptyRow
                        .listRowInsets(commentRowInsets)
                } header: {
                    commentsSectionHeader(count: 0)
                }
            } else {
                Section {
                    ForEach(replies) { item in
                        let reply = item.reply
                        let conversation =
                            conversationIndex.conversation(containing: reply.id)
                        let hasConversation =
                            conversation?.hasMultipleReplies == true

                        ReplyRowView(
                            path: $path,
                            topic: topic,
                            reply: reply,
                            floor: item.floor,
                            showsConversationIndicator: hasConversation,
                            onMentionTap: showMember(named:)
                        )
                        .equatable()
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .global)
                        } action: { frame in
                            replyFrames.frames[reply.id] = frame
                        }
                        .onDisappear { replyFrames.frames[reply.id] = nil }
                        .replyLiftHidden(reply.id, state: threadState)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if hasConversation, let conversation {
                                presentConversation(
                                    conversation,
                                    selectedReplyId: reply.id
                                )
                            }
                        }
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: true
                        ) {
                            Button {
                                beginReply(to: reply.member)
                            } label: {
                                Label("回复", systemImage: "arrowshape.turn.up.left")
                            }
                            .tint(.accentColor)

                            Button {
                                presentAuthor(reply.member.username, from: reply.id)
                            } label: {
                                Label("只看TA", systemImage: "person.text.rectangle")
                            }
                            .tint(.blue)

                            Button {
                                copyReplyContent(reply.content)
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            .tint(.accentColor)
                        }
                        .listRowInsets(
                            commentRowInsets
                        )
                        .id(replyScrollID(reply.id))
                    }
                } header: {
                    commentsSectionHeader(count: replies.count)
                }
            }
        }
    }

    private func commentsSectionHeader(count: Int?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text("评论")
                .font(.headline)
                .foregroundStyle(.primary)

            if let count {
                Text(count.formattedCount)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
            }

            Spacer(minLength: 8)

            Button {
                beginReply()
            } label: {
                Label("评论", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("评论主题")
        }
        .textCase(nil)
        .padding(.top, 4)
    }

    private var commentsLoadingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("评论加载中")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var commentsEmptyRow: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("暂无评论")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("快来抢沙发吧")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func commentsErrorRow(message: String, topicId: Int) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.tertiary)

                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Button {
                Task {
                    await loadReply(topicId: topicId, force: true)
                }
            } label: {
                Label("重试", systemImage: "arrow.clockwise")
                    .font(.footnote.weight(.medium))
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    private func copyReplyContent(_ content: String) {
        UIPasteboard.general.string = content
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func authorReplyItems(for username: String) -> [ReplyConversationItem] {
        conversationIndex.items(byAuthor: username)
    }

    private func presentConversation(
        _ conversation: ReplyConversation,
        selectedReplyId: Int
    ) {
        guard !isCommentOverlayPresented else { return }
        threadState.closeRequest = nil
        threadHeroReplyID = selectedReplyId
        selectedConversationReplyId = selectedReplyId
        selectedConversation = conversation
    }

    private func presentAuthor(_ username: String, from replyId: Int) {
        guard !isCommentOverlayPresented else { return }
        threadState.closeRequest = nil
        threadHeroReplyID = replyId
        selectedAuthor = username
    }

    private func beginReply(to member: Member? = nil) {
        guard userManager.token?.token?.isEmpty == false else {
            showReplyLogin = true
            return
        }
        replyTarget = member
        showReplyComposer = true
    }

    private func replyScrollID(_ replyId: Int) -> String {
        "reply-\(replyId)"
    }

    // 评论浮层：仿 iMessage 回复线程，回复从列表浮起并在关闭时落回
    private func replyThreadOverlay(
        title: String,
        subtitle: String,
        systemImage: String,
        items: [ReplyConversationItem],
        topic: Topic,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        let heroReplyID = threadHeroReplyID
        let contentWidth = heroReplyID.flatMap { replyFrames.frames[$0]?.width }
            ?? replyFrames.frames.values.first?.width

        return ReplyThreadOverlay(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            items: items,
            heroReplyID: heroReplyID,
            contentWidth: contentWidth,
            rowFrames: replyFrames,
            threadState: threadState,
            onSelect: { item in
                closeCommentOverlayAndScroll(to: item, scrollProxy: scrollProxy)
            },
            onLift: { replyId in
                threadState.liftedReplyID = replyId
            },
            onClosed: {
                selectedConversation = nil
                selectedAuthor = nil
                resetReplyThreadState()
            }
        ) { item in
            ReplyRowView(
                path: $path,
                topic: topic,
                reply: item.reply,
                floor: item.floor,
                showsConversationIndicator: conversationIndex
                    .conversation(containing: item.reply.id)?
                    .hasMultipleReplies == true,
                onMentionTap: showMember(named:)
            )
            .equatable()
        }
        .zIndex(1)
    }

    private var commentOverlayCloseButton: some View {
        Button {
            dismissCommentOverlay()
        } label: {
            Image(systemName: "xmark")
        }
        .accessibilityLabel("关闭浮层")
    }

    private func conversationSubtitle(_ conversation: ReplyConversation) -> String {
        let count = "\(conversation.items.count.formattedCount) 条评论"
        let names = conversation.participants.prefix(3).joined(separator: "、")
        guard !names.isEmpty else { return count }

        if conversation.participants.count > 3 {
            return "\(count) · \(names) 等 \(conversation.participants.count.formattedCount) 人"
        }

        return "\(count) · \(names)"
    }

    private func dismissCommentOverlay() {
        guard threadState.closeRequest == nil else { return }
        threadState.closeRequest = .dismiss
    }

    private func resetReplyThreadState() {
        selectedConversationReplyId = nil
        threadHeroReplyID = nil
        threadState.liftedReplyID = nil
        // closeRequest 留到下次打开时再清除：浮层移除前修改它会让浮层多渲染一次。
    }

    private func closeCommentOverlayAndScroll(
        to item: ReplyConversationItem,
        scrollProxy: ScrollViewProxy
    ) {
        guard threadState.closeRequest == nil else { return }
        // 在模糊背景下先把列表滚动到目标楼层，回复再从浮层落回该位置。
        threadState.liftedReplyID = item.reply.id
        scrollProxy.scrollTo(replyScrollID(item.reply.id), anchor: .center)
        threadState.closeRequest = .jump(to: item.reply.id)
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
                    showBlockUserAlert = true
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
        .alert("确定要屏蔽该用户吗？", isPresented: $showBlockUserAlert) {
            Button("确认屏蔽", role: .destructive) {
                withAnimation(.spring()) {
                    BlockManager.shared.block(member.username)
                }
                selectedUser = nil
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func loadTopic() async {
        guard topic == nil else { return }
        guard let id = topicId else { return }
        topicLoadErrorMessage = nil
        do {
            if userManager.token != nil {
                let response = try await V2exAPI.shared.topic(topicId: id)
                if let r = response, r.success, let newTopic = r.result {
                    topic = newTopic
                } else {
                    topicLoadErrorMessage = response?.message ?? "无法加载该主题"
                }
            } else {
                let response = try await V2exAPI.shared.topicV1(topicId: id)
                if let newTopic = response?.first {
                    topic = newTopic
                } else {
                    topicLoadErrorMessage = "无法加载该主题"
                }
            }
        } catch {
            print("❌ 获取 Topic 失败: \(error)")
            if (error as? URLError)?.code != .cancelled {
                topicLoadErrorMessage = "无法加载该主题"
            }
        }
    }

    private func rebuildConversationCacheFromCurrentReplies() {
        guard let replies else {
            conversationIndex = .empty
            selectedConversation = nil
            selectedConversationReplyId = nil
            selectedAuthor = nil
            return
        }

        rebuildConversationCache(for: replies)
    }

    private func rebuildConversationCache(for replies: [Reply]) {
        let index = ReplyConversationIndex(replies: replies) { reply in
            !blockManager.isBlocked(reply.member.username)
        }
        conversationIndex = index
        if let selectedAuthor,
            index.items(byAuthor: selectedAuthor).isEmpty
        {
            self.selectedAuthor = nil
        }
        if let selectedConversationReplyId {
            let updatedConversation = index.conversation(
                containing: selectedConversationReplyId
            )
            if let updatedConversation, updatedConversation.hasMultipleReplies {
                selectedConversation = updatedConversation
            } else {
                selectedConversation = nil
                self.selectedConversationReplyId = nil
            }
        }
    }

    func loadReply(topicId: Int, force: Bool = false) async {
        guard force || replies == nil else { return }
        isLoading = true
        repliesLoadErrorMessage = nil
        defer { isLoading = false }
        do {
            let r = try await V2exAPI.shared.repliesAll(topicId: topicId)
            replies = r
            if let r {
                rebuildConversationCache(for: r)
            } else {
                conversationIndex = .empty
                repliesLoadErrorMessage = "评论加载失败"
            }
        } catch {
            if (error as? URLError)?.code != .cancelled {
                print("真正的错误: \(error)")
                repliesLoadErrorMessage = "评论加载失败"
            }
        }
    }
}

private struct HTMLContentNotice: View {
    let url: URL?
    let openURL: (URL) -> Void

    private let noticeColor = Color.yellow

    var body: some View {
        Group {
            if let url {
                Button {
                    openURL(url)
                } label: {
                    noticeContent(showsOpenIndicator: true)
                }
                .buttonStyle(.plain)
            } else {
                noticeContent(showsOpenIndicator: false)
            }
        }
    }

    private func noticeContent(showsOpenIndicator: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 4) {
                Text("该主题内容包含 HTML")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("当前页面可能无法完整显示，建议访问网页版。")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsOpenIndicator {
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.forward.app")
            }
        }
        .foregroundStyle(noticeColor)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(noticeShape.fill(noticeColor.opacity(0.12)))
        .contentShape(noticeShape)
    }

    private var noticeShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }
}

private extension String {
    var isLikelyHTML: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("<"), trimmed.contains(">") else {
            return false
        }

        return trimmed.range(
            of: Self.htmlTagPattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    static let htmlTagPattern =
        #"<\s*/?\s*(?:html|head|body|div|section|article|p|br|hr|a|img|figure|figcaption|table|thead|tbody|tr|td|th|ul|ol|li|span|strong|em|b|i|blockquote|pre|code|h[1-6]|script|style|iframe|video|audio|source)\b[^>]*>"#
}

#Preview {
    //    @Previewable @State var path = NavigationPath()
    //    let topic: Topic = ModelData().topics[0]
    //    DetailView(topicId: nil, topic: topic, path: $path)
}
