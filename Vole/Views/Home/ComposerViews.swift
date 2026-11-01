import SwiftUI
import UIKit

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
    @State private var showNodePicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showMembershipAlert = false

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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showNodePicker = true
                } label: {
                    Label(
                        selectedNode?.title ?? (selectedNodeName.isEmpty ? "选择节点" : selectedNodeName),
                        systemImage: "square.grid.2x2"
                    )
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("\(title.count)/120")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)

            Divider()

            TextField("主题标题", text: titleBinding, axis: .vertical)
                .font(.title2.weight(.semibold))
                .lineLimit(1...2)
                .textInputAutocapitalization(.sentences)
                .padding(.vertical, 14)

            Divider()

            MarkdownComposerEditor(
                text: contentBinding,
                characterLimit: 20_000,
                previewTitle: title
            )
            .frame(maxHeight: .infinity)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .navigationTitle("新主题")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMembershipAlert) {
            MembershipRequiredSheet()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .disabled(isSubmitting)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await submit() }
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
        .sheet(isPresented: $showNodePicker) {
            NavigationStack {
                NodeSelectionSheet { node in
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
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showMembershipAlert = false

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
        VStack(spacing: 0) {
            if let replyTo {
                Label("回复 @\(replyTo.username)", systemImage: "arrowshape.turn.up.left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)

                Divider()
            }

            MarkdownComposerEditor(
                text: contentBinding,
                characterLimit: characterLimit
            )
            .frame(maxHeight: .infinity)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .navigationTitle(replyTo.map { "回复 @\($0.username)" } ?? "评论")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMembershipAlert) {
            MembershipRequiredSheet()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .disabled(isSubmitting)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await submit() }
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

private struct MarkdownComposerEditor: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case edit = "编辑"
        case preview = "预览"

        var id: String { rawValue }
    }

    @Binding var text: String
    let characterLimit: Int
    var previewTitle: String? = nil
    @State private var mode: Mode = .edit
    @State private var formatRequest: MarkdownFormatRequest?

    private var previewContent: String {
        guard let previewTitle,
            !previewTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return text }
        return "# \(previewTitle)\n\n\(text)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("编辑模式", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 6) {
                formattingButton(title: "H1", help: "一级标题", action: .heading(1))
                formattingButton(title: "H2", help: "二级标题", action: .heading(2))
                formattingButton(title: "H3", help: "三级标题", action: .heading(3))

                Divider()
                    .frame(height: 22)

                formattingButton(systemImage: "bold", help: "粗体", action: .bold)
                formattingButton(systemImage: "italic", help: "斜体", action: .italic)
                formattingButton(
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    help: "代码块",
                    action: .codeBlock
                )

                Spacer(minLength: 0)
            }

            Divider()

            Group {
                if mode == .edit {
                    MarkdownTextView(text: $text, formatRequest: $formatRequest)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("正文支持 Markdown")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                } else if previewContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("没有内容可预览")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        VoleMarkdownView(content: previewContent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(minHeight: 250, maxHeight: .infinity)

            HStack {
                Spacer()
                Text("\(text.count)/\(characterLimit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formattingButton(
        title: String? = nil,
        systemImage: String? = nil,
        help: String,
        action: MarkdownFormattingAction
    ) -> some View {
        Button {
            formatRequest = MarkdownFormatRequest(action: action)
        } label: {
            Group {
                if let title {
                    Text(title)
                        .font(.caption.weight(.semibold).monospaced())
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(width: 36, height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

private enum MarkdownFormattingAction {
    case heading(Int)
    case bold
    case italic
    case codeBlock
}

private struct MarkdownFormatRequest: Identifiable {
    let id = UUID()
    let action: MarkdownFormattingAction
}

private struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var formatRequest: MarkdownFormatRequest?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .label
        textView.tintColor = .systemBlue
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }

        if let request = formatRequest,
            context.coordinator.lastFormatRequestID != request.id
        {
            context.coordinator.lastFormatRequestID = request.id
            context.coordinator.apply(request.action, to: textView)
            DispatchQueue.main.async {
                if formatRequest?.id == request.id {
                    formatRequest = nil
                }
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private var parent: MarkdownTextView
        var lastFormatRequestID: UUID?

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func apply(_ action: MarkdownFormattingAction, to textView: UITextView) {
            switch action {
            case .heading(let level):
                applyHeading(level, to: textView)
            case .bold:
                wrapSelection(in: textView, with: "**")
            case .italic:
                wrapSelection(in: textView, with: "*")
            case .codeBlock:
                wrapSelection(in: textView, opening: "```\n", closing: "\n```")
            }
            parent.text = textView.text
        }

        private func applyHeading(_ level: Int, to textView: UITextView) {
            let source = textView.text as NSString
            let selection = textView.selectedRange
            let range = selection.length > 0
                ? selection
                : source.lineRange(
                    for: NSRange(
                        location: min(selection.location, source.length),
                        length: 0
                    )
                )
            let selectedText = source.substring(with: range)
            let marker = String(repeating: "#", count: level) + " "
            let headingPattern = try? NSRegularExpression(pattern: #"^#{1,6}\s*"#)
            let formatted = selectedText
                .components(separatedBy: "\n")
                .map { line in
                    let lineRange = NSRange(line.startIndex..., in: line)
                    let cleanLine = headingPattern?.stringByReplacingMatches(
                        in: line,
                        range: lineRange,
                        withTemplate: ""
                    ) ?? line
                    return marker + cleanLine
                }
                .joined(separator: "\n")

            textView.text = source.replacingCharacters(in: range, with: formatted)
            textView.selectedRange = NSRange(
                location: min(range.location + marker.utf16.count, (textView.text as NSString).length),
                length: 0
            )
            textView.becomeFirstResponder()
        }

        private func wrapSelection(in textView: UITextView, with delimiter: String) {
            wrapSelection(
                in: textView,
                opening: delimiter,
                closing: delimiter
            )
        }

        private func wrapSelection(
            in textView: UITextView,
            opening: String,
            closing: String
        ) {
            let source = textView.text as NSString
            let range = textView.selectedRange
            let selectedText = source.substring(with: range)
            let replacement = opening + selectedText + closing
            textView.text = source.replacingCharacters(in: range, with: replacement)

            let selectionStart = range.location + opening.utf16.count
            textView.selectedRange = NSRange(
                location: selectionStart,
                length: selectedText.utf16.count
            )
            textView.becomeFirstResponder()
        }
    }
}

private struct NodeSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var nodeManager = NodeManager.shared

    let onSelect: (Node) -> Void
    @State private var query = ""

    private var filteredNodes: [Node] {
        guard !query.isEmpty else { return nodeManager.nodes }
        let keyword = query.lowercased()
        return nodeManager.nodes.filter {
            $0.name.lowercased().contains(keyword)
                || ($0.title?.lowercased().contains(keyword) ?? false)
        }
    }

    var body: some View {
        List(filteredNodes, id: \.name) { node in
            Button {
                onSelect(node)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title ?? node.name)
                        .foregroundStyle(.primary)
                    Text(node.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .searchable(text: $query, prompt: "搜索节点")
        .navigationTitle("选择节点")
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
}
