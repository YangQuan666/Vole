//
//  MarkdownEditor.swift
//  Vole
//

import PhotosUI
import SwiftUI

/// 发帖与回复共用的 Markdown 编辑器。
///
/// 底部是常驻的格式工具栏（键盘弹起时随之上移），包含格式按钮、图片和预览切换；
/// 在列表、任务、引用行按回车会自动续写前缀。
struct MarkdownEditor: View {
    static let maxAttachmentCount = 9

    @Binding var text: String
    @Binding var attachments: [ComposerImageAttachment]
    let characterLimit: Int
    var placeholder = "正文支持 Markdown"
    /// 预览时显示在正文上方的标题（发帖时传入主题标题）。
    var previewTitle: String? = nil
    var imageUploader: any ComposerImageUploader = UnavailableImageUploader()
    /// 正文与附件的水平边距；底部工具栏始终通栏显示。
    var horizontalPadding: CGFloat = 20

    @State private var isPreviewing = false
    @State private var selection: TextSelection?
    @FocusState private var isEditorFocused: Bool
    @State private var isPhotoPickerPresented = false
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var isLinkPromptPresented = false
    @State private var linkTitle = ""
    @State private var linkURL = ""

    private var remainingAttachmentCount: Int {
        max(0, Self.maxAttachmentCount - attachments.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isPreviewing {
                    preview
                } else {
                    editor
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottomTrailing) {
                characterCount
            }

            if !attachments.isEmpty {
                ComposerAttachmentStrip(
                    attachments: $attachments,
                    onRetry: { id in Task { await upload(id) } },
                    onInsert: insertImage
                )
                .padding(.bottom, 10)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            formatBar
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $pickedPhotos,
            maxSelectionCount: max(1, remainingAttachmentCount),
            matching: .images
        )
        .onChange(of: pickedPhotos) { _, items in
            guard !items.isEmpty else { return }
            importPhotos(items)
        }
        .onChange(of: text) { oldText, newText in
            continueListIfNeeded(from: oldText, to: newText)
        }
        .alert("插入链接", isPresented: $isLinkPromptPresented) {
            TextField("链接文字（可选）", text: $linkTitle)
            TextField("https://", text: $linkURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("取消", role: .cancel) {
                isEditorFocused = true
            }
            Button("插入") {
                insertLink()
            }
            .disabled(normalizedLinkURL == nil)
        } message: {
            Text("选中的文字会作为链接文字。")
        }
    }

    // MARK: - 编辑与预览

    private var editor: some View {
        TextEditor(text: $text, selection: $selection)
            .focused($isEditorFocused)
            .scrollContentBackground(.hidden)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private var preview: some View {
        let content = previewContent
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView(
                "没有内容可预览",
                systemImage: "doc.text",
                description: Text("关闭预览后开始输入")
            )
        } else {
            ScrollView {
                VoleMarkdownView(content: content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
    }

    private var previewContent: String {
        guard let previewTitle,
            !previewTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return text }
        return "# \(previewTitle)\n\n\(text)"
    }

    /// 字数只在接近上限时显示。
    @ViewBuilder
    private var characterCount: some View {
        if text.count >= characterLimit * 4 / 5 {
            Text("\(text.count)/\(characterLimit)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(text.count >= characterLimit * 19 / 20 ? Color.red : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 6)
                .accessibilityLabel("已输入 \(text.count) 字，上限 \(characterLimit) 字")
        }
    }

    // MARK: - 格式工具栏

    private var formatBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        Button {
                            isPhotoPickerPresented = true
                        } label: {
                            toolbarIcon("photo")
                        }
                        .disabled(remainingAttachmentCount == 0)
                        .accessibilityLabel("添加图片")

                        Menu {
                            Button("一级标题") { apply(.heading(1)) }
                            Button("二级标题") { apply(.heading(2)) }
                            Button("三级标题") { apply(.heading(3)) }
                        } label: {
                            // 「#」对应 Markdown 标题语法；textformat.size 在中文系统中显示为「大小」。
                            toolbarIcon("number")
                        }
                        .accessibilityLabel("标题")

                        formatButton("bold", label: "粗体", action: .bold)
                        formatButton("italic", label: "斜体", action: .italic)
                        formatButton("strikethrough", label: "删除线", action: .strikethrough)

                        Menu {
                            Button("无序列表", systemImage: "list.bullet") { apply(.bulletList) }
                            Button("有序列表", systemImage: "list.number") { apply(.numberedList) }
                            Button("任务列表", systemImage: "checklist") { apply(.taskList) }
                        } label: {
                            toolbarIcon("list.bullet")
                        }
                        .accessibilityLabel("列表")

                        formatButton("text.quote", label: "引用", action: .quote)

                        Menu {
                            Button("行内代码", systemImage: "chevron.left.forwardslash.chevron.right") {
                                apply(.inlineCode)
                            }
                            Button("代码块", systemImage: "curlybraces.square") {
                                apply(.codeBlock)
                            }
                        } label: {
                            toolbarIcon("chevron.left.forwardslash.chevron.right")
                        }
                        .accessibilityLabel("代码")

                        Button {
                            presentLinkPrompt()
                        } label: {
                            toolbarIcon("link")
                        }
                        .accessibilityLabel("插入链接")

                        formatButton("minus", label: "分隔线", action: .horizontalRule)
                    }
                    .padding(.horizontal, 8)
                }
                .disabled(isPreviewing)
                .opacity(isPreviewing ? 0.3 : 1)

                Divider()
                    .frame(height: 22)

                Button {
                    togglePreview()
                } label: {
                    toolbarIcon(isPreviewing ? "eye.fill" : "eye")
                        .foregroundStyle(isPreviewing ? Color.accentColor : Color.primary)
                }
                .accessibilityLabel(isPreviewing ? "返回编辑" : "预览")

                if isEditorFocused {
                    Button {
                        isEditorFocused = false
                    } label: {
                        toolbarIcon("keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel("收起键盘")
                }
            }
            .padding(.trailing, 6)
            .frame(height: 46)
        }
        .foregroundStyle(.primary)
        .background(.bar)
    }

    private func formatButton(
        _ systemImage: String,
        label: String,
        action: MarkdownEditAction
    ) -> some View {
        Button {
            apply(action)
        } label: {
            toolbarIcon(systemImage)
        }
        .accessibilityLabel(label)
    }

    private func toolbarIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.body.weight(.medium))
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }

    private func togglePreview() {
        isPreviewing.toggle()
        isEditorFocused = !isPreviewing
    }

    private func apply(_ action: MarkdownEditAction) {
        let edit = MarkdownTextEditing.apply(action, to: text, selection: selection)
        // 超出字数上限时放弃本次格式化，避免内容被截断。
        guard edit.text.count <= characterLimit else { return }
        text = edit.text
        selection = edit.selection
        isEditorFocused = true
    }

    /// 在列表、任务或引用行末按回车时续写前缀；空项上按回车结束列表。
    private func continueListIfNeeded(from oldText: String, to newText: String) {
        guard newText.count == oldText.count + 1 else { return }

        let offset = zip(oldText, newText).prefix { $0 == $1 }.count
        let index = newText.index(newText.startIndex, offsetBy: offset)
        guard newText[index] == "\n",
            let edit = MarkdownTextEditing.continueList(in: newText, afterNewlineAt: offset),
            edit.text.count <= characterLimit
        else { return }

        text = edit.text
        selection = edit.selection
    }

    // MARK: - 链接

    private var normalizedLinkURL: String? {
        let trimmed = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), url.isWebURL, url.host() != nil else {
            return nil
        }
        return candidate
    }

    private func presentLinkPrompt() {
        linkTitle = MarkdownTextEditing.selectedText(in: text, selection: selection)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        linkURL = ""
        isLinkPromptPresented = true
    }

    private func insertLink() {
        guard let url = normalizedLinkURL else { return }
        let title = linkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        apply(.link(title: title, url: url))
    }

    // MARK: - 图片

    private func importPhotos(_ items: [PhotosPickerItem]) {
        pickedPhotos = []
        for item in items.prefix(remainingAttachmentCount) {
            let attachment = ComposerImageAttachment()
            attachments.append(attachment)
            let id = attachment.id

            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                let thumbnail = try? await item.loadTransferable(type: Image.self)
                guard let data else {
                    updateAttachment(id) { $0.state = .failed("无法读取这张图片") }
                    return
                }
                updateAttachment(id) {
                    $0.data = data
                    $0.thumbnail = thumbnail
                }
                await upload(id)
            }
        }
    }

    private func upload(_ id: ComposerImageAttachment.ID) async {
        guard let data = attachments.first(where: { $0.id == id })?.data else { return }
        guard imageUploader.isAvailable else {
            updateAttachment(id) { $0.state = .pendingUpload }
            return
        }

        updateAttachment(id) { $0.state = .uploading }
        do {
            let url = try await imageUploader.upload(data)
            updateAttachment(id) { $0.state = .uploaded(url) }
            if let attachment = attachments.first(where: { $0.id == id }) {
                insertImage(attachment)
            }
        } catch {
            updateAttachment(id) { $0.state = .failed(error.localizedDescription) }
        }
    }

    private func insertImage(_ attachment: ComposerImageAttachment) {
        guard case .uploaded(let url) = attachment.state else { return }
        apply(.image(alt: "image", url: url.absoluteString))
    }

    private func updateAttachment(
        _ id: ComposerImageAttachment.ID,
        _ update: (inout ComposerImageAttachment) -> Void
    ) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        update(&attachments[index])
    }
}

// MARK: - 图片附件

/// 编辑器中待发布的图片。
struct ComposerImageAttachment: Identifiable {
    enum State: Equatable {
        case loading
        /// 已读取，等待上传（当前没有可用的上传服务）。
        case pendingUpload
        case uploading
        case uploaded(URL)
        case failed(String)
    }

    let id = UUID()
    var data: Data?
    var thumbnail: Image?
    var state: State = .loading

    var isUploaded: Bool {
        if case .uploaded = state { return true }
        return false
    }
}

/// 图片上传服务。上传成功后返回图片地址，编辑器会把它以 Markdown 图片插入正文。
protocol ComposerImageUploader: Sendable {
    var isAvailable: Bool { get }
    func upload(_ data: Data) async throws -> URL
}

enum ComposerImageUploadError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "图片上传功能即将支持"
        }
    }
}

/// V2EX 官方 API 不提供图片上传，接入图床前使用此占位实现。
struct UnavailableImageUploader: ComposerImageUploader {
    var isAvailable: Bool { false }

    func upload(_ data: Data) async throws -> URL {
        throw ComposerImageUploadError.unavailable
    }
}

private struct ComposerAttachmentStrip: View {
    @Binding var attachments: [ComposerImageAttachment]
    let onRetry: (ComposerImageAttachment.ID) -> Void
    let onInsert: (ComposerImageAttachment) -> Void

    private let thumbnailShape = RoundedRectangle(cornerRadius: 10, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(attachments) { attachment in
                        thumbnail(for: attachment)
                    }
                }
                // 为右上角的删除按钮留出空间。
                .padding(.top, 8)
                .padding(.trailing, 8)
            }

            if attachments.contains(where: { $0.state == .pendingUpload }) {
                Label("图片上传即将支持，目前图片不会随内容发布。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func thumbnail(for attachment: ComposerImageAttachment) -> some View {
        ZStack {
            thumbnailShape.fill(Color(.secondarySystemFill))

            if let image = attachment.thumbnail {
                image
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(thumbnailShape)
        .overlay { statusOverlay(attachment.state) }
        .overlay(alignment: .topTrailing) {
            Button {
                remove(attachment)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .offset(x: 8, y: -8)
            .accessibilityLabel("删除图片")
        }
        .contextMenu {
            if attachment.isUploaded {
                Button("插入到正文", systemImage: "text.insert") {
                    onInsert(attachment)
                }
            }
            if case .failed = attachment.state {
                Button("重新上传", systemImage: "arrow.clockwise") {
                    onRetry(attachment.id)
                }
            }
            Button("删除", systemImage: "trash", role: .destructive) {
                remove(attachment)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("图片，\(statusDescription(attachment.state))")
    }

    @ViewBuilder
    private func statusOverlay(_ state: ComposerImageAttachment.State) -> some View {
        switch state {
        case .loading, .uploading:
            ZStack {
                thumbnailShape.fill(.black.opacity(0.35))
                ProgressView()
                    .tint(.white)
            }
        case .pendingUpload:
            Text("待上传")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.regularMaterial, in: Capsule())
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 5)
        case .uploaded:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(5)
        case .failed:
            ZStack {
                thumbnailShape.fill(.black.opacity(0.35))
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func statusDescription(_ state: ComposerImageAttachment.State) -> String {
        switch state {
        case .loading: return "正在读取"
        case .pendingUpload: return "待上传"
        case .uploading: return "正在上传"
        case .uploaded: return "已上传"
        case .failed(let message): return "上传失败，\(message)"
        }
    }

    private func remove(_ attachment: ComposerImageAttachment) {
        withAnimation(.snappy) {
            attachments.removeAll { $0.id == attachment.id }
        }
    }
}
