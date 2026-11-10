import SwiftUI

private let membershipDetailsURL = URL(string: "https://v2ex.com/balance/add")!

private func isMembershipRequired(_ message: String?) -> Bool {
    message?.localizedCaseInsensitiveContains(
        "An active PRO membership is required to create content"
    ) == true
}

private struct MembershipRequiredSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "crown.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 56, height: 56)
                .background(.orange.opacity(0.12), in: Circle())
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text("此功能需要 PRO 会员")
                    .font(.headline)

                Text("开通有效的 V2EX PRO 会员后，即可创建主题和发表评论。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Button {
                    openURL(membershipDetailsURL)
                    dismiss()
                } label: {
                    Text("了解 PRO 会员")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }

                Button("稍后再说") { dismiss() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .presentationDetents([.height(310)])
        .presentationDragIndicator(.visible)
    }
}

struct CreateTopicView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var nodeManager = NodeManager.shared

    @State private var selectedNodeName = ""
    @State private var title = ""
    @State private var content = ""
    @State private var attachments: [ComposerImageAttachment] = []
    @State private var showNodePicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showMembershipAlert = false
    @State private var showDiscardConfirmation = false
    @State private var showPendingImagesConfirmation = false

    let onCreated: (Topic) -> Void

    private var selectedNode: Node? {
        nodeManager.nodes.first { $0.name == selectedNodeName }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { title },
            set: { title = String($0.prefix(120)) }
        )
    }

    private var contentBinding: Binding<String> {
        Binding(
            get: { content },
            set: { content = String($0.prefix(20_000)) }
        )
    }

    private var canSubmit: Bool {
        !isSubmitting
            && !selectedNodeName.isEmpty
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !attachments.isEmpty
    }

    private var pendingImageCount: Int {
        attachments.filter { !$0.isUploaded }.count
    }

    /// 发布到的节点：未选择时为灰色，选中后为主题色。
    private var nodeChip: some View {
        Button {
            showNodePicker = true
        } label: {
            HStack(spacing: 4) {
                Text(selectedNodeName.isEmpty ? "选择节点" : (selectedNode?.title ?? selectedNodeName))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selectedNodeName.isEmpty ? Color.secondary : Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    selectedNodeName.isEmpty
                        ? Color(.tertiarySystemFill)
                        : Color.accentColor.opacity(0.12)
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedNodeName.isEmpty ? "选择节点" : "节点：\(selectedNode?.title ?? selectedNodeName)")
        .accessibilityHint("选择主题要发布到的节点")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                nodeChip

                TextField("标题", text: titleBinding, axis: .vertical)
                    .font(.title2.weight(.bold))
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.sentences)

                // 标题字数只在接近上限时提示。
                if title.count >= 100 {
                    Text("\(title.count)/120")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    ComposerErrorLabel(message: errorMessage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 20)

            MarkdownEditor(
                text: contentBinding,
                attachments: $attachments,
                characterLimit: 20_000,
                previewTitle: title
            )
            .frame(maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .navigationTitle("新主题")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(hasChanges || isSubmitting)
        .sheet(isPresented: $showMembershipAlert) {
            MembershipRequiredSheet()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    if hasChanges {
                        showDiscardConfirmation = true
                    } else {
                        dismiss()
                    }
                }
                .disabled(isSubmitting)
                .confirmationDialog(
                    "放弃这个主题吗？",
                    isPresented: $showDiscardConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("放弃编辑", role: .destructive) { dismiss() }
                    Button("继续编辑", role: .cancel) {}
                } message: {
                    Text("已输入的内容不会被保存。")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if pendingImageCount > 0 {
                        showPendingImagesConfirmation = true
                    } else {
                        Task { await submit() }
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("发布")
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .alert("仍要发布吗？", isPresented: $showPendingImagesConfirmation) {
            Button("取消", role: .cancel) {}
            Button("发布") { Task { await submit() } }
        } message: {
            Text("有 \(pendingImageCount) 张图片尚未上传，不会随主题发布。")
        }
        .sheet(isPresented: $showNodePicker) {
            NavigationStack {
                NodeSelectionSheet(selectedNodeName: selectedNodeName) { node in
                    selectedNodeName = node.name
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            if nodeManager.nodes.isEmpty {
                await nodeManager.refreshNodes(force: false)
            }
        }
    }

    @MainActor
    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let response = try await V2exAPI.shared.createTopic(
                nodeName: selectedNodeName,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content,
                syntax: "markdown"
            )
            guard let response, response.success, let topic = response.result else {
                showSubmissionError(response?.message, fallback: "发布失败，请稍后重试")
                return
            }

            onCreated(topic)
            dismiss()
        } catch {
            if let apiError = error as? V2exAPIError,
                case let .httpFailure(_, _, _, _, message) = apiError,
                isMembershipRequired(message)
            {
                showMembershipAlert = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func showSubmissionError(_ message: String?, fallback: String) {
        if isMembershipRequired(message) {
            showMembershipAlert = true
        } else {
            errorMessage = message ?? fallback
        }
    }
}

struct ReplyComposerView: View {
    @Environment(\.dismiss) private var dismiss

    let topicID: Int
    let replyTo: Member?
    let onSent: () -> Void

    @State private var content: String
    @State private var attachments: [ComposerImageAttachment] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showMembershipAlert = false
    @State private var showDiscardConfirmation = false
    @State private var showPendingImagesConfirmation = false

    init(topicID: Int, replyTo: Member?, onSent: @escaping () -> Void) {
        self.topicID = topicID
        self.replyTo = replyTo
        self.onSent = onSent
        _content = State(initialValue: replyTo.map { "@\($0.username) " } ?? "")
    }

    private var mention: String? {
        replyTo.map { "@\($0.username)" }
    }

    private var characterLimit: Int {
        max(0, 10_000 - (mention.map { $0.count + 1 } ?? 0))
    }

    private var contentBinding: Binding<String> {
        Binding(
            get: { content },
            set: { content = String($0.prefix(characterLimit)) }
        )
    }

    private var canSubmit: Bool {
        !isSubmitting && !submissionContent.isEmpty
    }

    private var hasChanges: Bool {
        !submissionContent.isEmpty || !attachments.isEmpty
    }

    private var pendingImageCount: Int {
        attachments.filter { !$0.isUploaded }.count
    }

    private var submissionContent: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mention else { return trimmed }

        let body = trimmed.hasPrefix(mention)
            ? String(trimmed.dropFirst(mention.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmed
        guard !body.isEmpty else { return "" }
        return "\(mention) \(body)"
    }

    var body: some View {
        // 回复对象已显示在导航标题中，这里不再重复。
        VStack(alignment: .leading, spacing: 0) {
            if let errorMessage {
                ComposerErrorLabel(message: errorMessage)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
            }

            MarkdownEditor(
                text: contentBinding,
                attachments: $attachments,
                characterLimit: characterLimit,
                placeholder: "写下你的评论，支持 Markdown"
            )
            .frame(maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .navigationTitle(replyTo.map { "回复 @\($0.username)" } ?? "评论")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(hasChanges || isSubmitting)
        .sheet(isPresented: $showMembershipAlert) {
            MembershipRequiredSheet()
        }
        .alert("仍要发送吗？", isPresented: $showPendingImagesConfirmation) {
            Button("取消", role: .cancel) {}
            Button("发送") { Task { await submit() } }
        } message: {
            Text("有 \(pendingImageCount) 张图片尚未上传，不会随评论发送。")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    if hasChanges {
                        showDiscardConfirmation = true
                    } else {
                        dismiss()
                    }
                }
                .disabled(isSubmitting)
                .confirmationDialog(
                    "放弃这条评论吗？",
                    isPresented: $showDiscardConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("放弃编辑", role: .destructive) { dismiss() }
                    Button("继续编辑", role: .cancel) {}
                } message: {
                    Text("已输入的内容不会被保存。")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if pendingImageCount > 0 {
                        showPendingImagesConfirmation = true
                    } else {
                        Task { await submit() }
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("发送")
                    }
                }
                .disabled(!canSubmit)
            }
        }
    }

    @MainActor
    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let response = try await V2exAPI.shared.createReply(
                topicId: topicID,
                content: submissionContent
            )
            guard let response, response.success, response.result != nil else {
                showSubmissionError(response?.message, fallback: "发送失败，请稍后重试")
                return
            }

            onSent()
            dismiss()
        } catch {
            if let apiError = error as? V2exAPIError,
                case let .httpFailure(_, _, _, _, message) = apiError,
                isMembershipRequired(message)
            {
                showMembershipAlert = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func showSubmissionError(_ message: String?, fallback: String) {
        if isMembershipRequired(message) {
            showMembershipAlert = true
        } else {
            errorMessage = message ?? fallback
        }
    }
}

private struct ComposerErrorLabel: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 选择发布节点：未搜索时先列出最近使用和收藏的节点，再列出全部节点。
private struct NodeSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var nodeManager = NodeManager.shared
    @ObservedObject private var favoriteNodeManager = FavoriteNodeManager.shared
    @AppStorage("composerRecentNodeNames") private var recentNodeNamesStorage = ""

    let selectedNodeName: String
    let onSelect: (Node) -> Void
    @State private var query = ""

    private static let maxRecentCount = 6

    private var recentNodeNames: [String] {
        recentNodeNamesStorage.split(separator: ",").map(String.init)
    }

    private var recentNodes: [Node] {
        recentNodeNames.compactMap { name in
            nodeManager.nodes.first { $0.name == name }
        }
    }

    private var searchResults: [Node] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return nodeManager.nodes.filter {
            $0.name.lowercased().contains(keyword)
                || ($0.title?.lowercased().contains(keyword) ?? false)
        }
    }

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                if !recentNodes.isEmpty {
                    Section("最近使用") {
                        ForEach(recentNodes, id: \.name, content: row)
                    }
                }
                if !favoriteNodeManager.favoriteNodes.isEmpty {
                    Section("我的收藏") {
                        ForEach(favoriteNodeManager.favoriteNodes, id: \.name, content: row)
                    }
                }
                Section("全部节点") {
                    ForEach(nodeManager.nodes, id: \.name, content: row)
                }
            } else {
                ForEach(searchResults, id: \.name, content: row)
            }
        }
        .overlay {
            if nodeManager.nodes.isEmpty {
                ProgressView()
            } else if !query.isEmpty, searchResults.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索节点名称"
        )
        .navigationTitle("发布到")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .task {
            if nodeManager.nodes.isEmpty {
                await nodeManager.refreshNodes(force: false)
            }
        }
    }

    private func row(_ node: Node) -> some View {
        Button {
            rememberRecent(node)
            onSelect(node)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.title ?? node.name)
                        .foregroundStyle(.primary)
                    Text(node.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if node.name == selectedNodeName {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(node.name == selectedNodeName ? .isSelected : [])
    }

    private func rememberRecent(_ node: Node) {
        var names = recentNodeNames.filter { $0 != node.name }
        names.insert(node.name, at: 0)
        recentNodeNamesStorage = names.prefix(Self.maxRecentCount).joined(separator: ",")
    }
}
