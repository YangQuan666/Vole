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
    @State private var conversationIndex = ReplyConversationIndex.empty
    @State private var showSafari = false
    @State private var safariURL: URL? = nil
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

                                    topicEngagementMetrics(for: topic)

                                    if let content = topic.content, !content.isEmpty {
                                        VStack(alignment: .leading, spacing: 12) {
                                            if content.isLikelyHTML {
                                                HTMLContentNotice(
                                                    url: topic.url.flatMap(URL.init(string:)),
                                                    openURL: { url in
                                                        safariURL = url
                                                        showSafari = true
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

                            if let supplements = topic.supplements,
                                !supplements.isEmpty
                            {
                                ForEach(supplements.indices, id: \.self) {
                                    idx in
                                    let supplement = supplements[idx]
                                    Section(
                                        header: HStack {
                                            Text("第 \(idx + 1)条附言")
                                            if let created = supplement.created {
                                                RelativeTimeText(timestamp: created)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    ) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            VoleMarkdownView(
                                                content: supplement.content ?? "",
                                                onMentionsChanged: nil,
                                                onLinkAction: handleMarkdownLinkAction
                                            )
                                        }
                                    }
                                }
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
                            replyCollectionOverlay(
                                title: "对话",
                                subtitle: conversationSubtitle(selectedConversation),
                                systemImage: "bubble.left.and.bubble.right.fill",
                                items: selectedConversation.items,
                                topic: topic,
                                selectedReplyId: selectedConversationReplyId,
                                scrollProxy: scrollProxy
                            )
                        } else if let selectedAuthor {
                            let items = authorReplyItems(for: selectedAuthor)
                            replyCollectionOverlay(
                                title: "只看 \(selectedAuthor)",
                                subtitle: "\(items.count.formattedCount) 条评论",
                                systemImage: "person.text.rectangle",
                                items: items,
                                topic: topic,
                                selectedReplyId: nil,
                                scrollProxy: scrollProxy
                            )
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
                            presentSafari(for: shareURL)
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
        .sheet(isPresented: $showSafari) {
            if let safariURL {
                SafariView(url: safariURL)
                    .ignoresSafeArea()
                    .interactiveDismissDisabled(true)
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

    @ViewBuilder
    private func topicEngagementMetrics(for topic: Topic) -> some View {
        if (topic.stars ?? 0) > 0 || (topic.thanks ?? 0) > 0
            || (topic.replies ?? 0) > 0
        {
            HStack(spacing: 14) {
                if let stars = topic.stars, stars > 0 {
                    topicMetric(
                        value: stars,
                        label: "收藏",
                        systemImage: "star",
                        tint: .secondary
                    )
                }

                if let thanks = topic.thanks, thanks > 0 {
                    topicMetric(
                        value: thanks,
                        label: "感谢",
                        systemImage: "heart",
                        tint: .secondary
                    )
                }

                if let replies = topic.replies, replies > 0 {
                    topicMetric(
                        value: replies,
                        label: "回复",
                        systemImage: "ellipsis.bubble.fill",
                        tint: .blue
                    )
                }
            }
        }
    }

    private func topicMetric(
        value: Int,
        label: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)

            Text(value.formattedCount)
                .fontWeight(.semibold)

            Text(label)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func topicTitleButton(_ title: String, urlString: String?) -> some View {
        Button {
            presentSafari(for: urlString)
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

    private func presentSafari(for urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        safariURL = url
        showSafari = true
    }

    private func handleMarkdownLinkAction(_ action: LinkAction) {
        switch action {
        case .mention(let username):
            print("@\(username)")
        case .topic(let id):
            path.append(Route.topicId(id))
        case .node(let name):
            path.append(Route.nodeName(name))
        }
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
                            showsConversationIndicator: hasConversation
                        )
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
                                presentAuthor(reply.member.username)
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
        withAnimation(.spring(dampingFraction: 0.6)) {
            selectedAuthor = nil
            selectedConversationReplyId = selectedReplyId
            selectedConversation = conversation
        }
    }

    private func presentAuthor(_ username: String) {
        withAnimation(.spring(dampingFraction: 0.6)) {
            selectedConversation = nil
            selectedConversationReplyId = nil
            selectedAuthor = username
        }
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

    // 评论集合浮层
    @ViewBuilder
    private func replyCollectionOverlay(
        title: String,
        subtitle: String,
        systemImage: String,
        items: [ReplyConversationItem],
        topic: Topic,
        selectedReplyId: Int?,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissCommentOverlay()
                }

            GeometryReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        replyCollectionHeader(
                            title: title,
                            subtitle: subtitle,
                            systemImage: systemImage
                        )

                        ForEach(
                            items,
                            id: \.id
                        ) { item in
                            replyOverlayCard(
                                item,
                                topic: topic,
                                isSelected: item.reply.id == selectedReplyId
                            ) {
                                closeCommentOverlayAndScroll(
                                    to: item,
                                    scrollProxy: scrollProxy
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: proxy.size.height,
                        alignment: .top
                    )
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissCommentOverlay()
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .transition(.opacity)
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

    private func replyCollectionHeader(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private func replyOverlayCard(
        _ item: ReplyConversationItem,
        topic: Topic,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        ReplyRowView(
            path: $path,
            topic: topic,
            reply: item.reply,
            floor: item.floor,
            showsConversationIndicator: false
        )
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.10)
                        : Color(.secondarySystemGroupedBackground).opacity(0.82)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? Color.accentColor.opacity(0.42)
                        : Color.white.opacity(0.08),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: onSelect)
        .accessibilityHint("返回第 \(item.floor + 1) 楼")
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
        withAnimation(.easeOut(duration: 0.16)) {
            selectedConversation = nil
            selectedConversationReplyId = nil
            selectedAuthor = nil
        }
    }

    private func closeCommentOverlayAndScroll(
        to item: ReplyConversationItem,
        scrollProxy: ScrollViewProxy
    ) {
        let targetID = replyScrollID(item.reply.id)

        dismissCommentOverlay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.26)) {
                scrollProxy.scrollTo(targetID, anchor: .center)
            }
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
