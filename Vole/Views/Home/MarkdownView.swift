//
//  MarkdownView.swift
//  Vole
//
//  Created by 杨权 on 8/23/25.
//

import Foundation
import Highlightr
import ImageIO
import Kingfisher
import LinkPresentation
import MarkdownView
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

enum LinkAction {
    case mention(username: String)
    case topic(id: Int)
    case node(name: String)
}

struct VoleMarkdownView: View {
    @State var content: String
    /// 引用类型，body 不读取其中的属性，打开和关闭预览时不会重新渲染整段内容。
    @State private var imagePreview = MarkdownImagePreviewState()
    @Environment(\.openURL) private var openURL

    var onMentionsChanged: (([String]) -> Void)?
    var onLinkAction: ((LinkAction) -> Void)?  // 统一处理链接事件

    var body: some View {
        let renderedBlocks = makeRenderedBlocks(content)
        let imageURLs = MarkdownImageCollector.imageURLs(
            in: renderedBlocks.markdown
        )
        let renderer = TappableMarkdownImageRenderer(
            imageURLs: imageURLs,
            openImagePreview: openImagePreview
        )

        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(renderedBlocks.blocks.enumerated()), id: \.offset) {
                _, block in
                switch block {
                case .markdown(let markdown):
                    markdownBlock(markdown, renderer: renderer)
                case .linkPreview(let url, let title):
                    MarkdownLinkPreviewCard(url: url, title: title)
                }
            }
        }
        .background {
            MarkdownImagePreviewHost(state: imagePreview)
        }
        .task(id: content) { @MainActor in
            onMentionsChanged?(renderedBlocks.mentions)
        }
        .environment(\.openURL, OpenURLAction(handler: handleOpenURL))
    }

    private func makeMarkdown(_ content: String) -> (String, [String]) {
        MarkdownContentFormatter().format(content)
    }

    private func makeRenderedBlocks(_ content: String) -> (
        blocks: [MarkdownRenderBlock],
        mentions: [String],
        markdown: String
    ) {
        var blocks: [MarkdownRenderBlock] = []
        var mentions: [String] = []
        var markdownSegments: [String] = []

        for block in MarkdownRenderBlockParser.blocks(from: content) {
            switch block {
            case .markdown(let rawMarkdown):
                let (markdown, blockMentions) = makeMarkdown(rawMarkdown)
                blocks.append(.markdown(markdown))
                mentions.append(contentsOf: blockMentions)
                markdownSegments.append(markdown)
            case .linkPreview:
                blocks.append(block)
            }
        }

        return (
            blocks,
            mentions,
            markdownSegments.joined(separator: "\n\n")
        )
    }

    @ViewBuilder
    private func markdownBlock(
        _ markdown: String,
        renderer: TappableMarkdownImageRenderer
    ) -> some View {
        MarkdownView(markdown)
            .markdownElementRenderer(.image(renderer, urlScheme: "http"))
            .markdownElementRenderer(.image(renderer, urlScheme: "https"))
            .markdownElementRenderer(
                .link(VoleMarkdownLinkRenderer(), urlScheme: "http")
            )
            .markdownElementRenderer(
                .link(VoleMarkdownLinkRenderer(), urlScheme: "https")
            )
            .markdownCodeBlockStyle(CompactMarkdownCodeBlockStyle())
            // 引用使用中性灰色，主题色留给链接、附言等可交互或结构性元素。
            .tint(Color.secondary, for: .blockQuote)
            .markdownTableStyle(HorizontalScrollableMarkdownTableStyle())
            .font(.headline.weight(.semibold), for: .h1)
            .font(.headline.weight(.semibold), for: .h2)
            .font(.subheadline.weight(.semibold), for: .h3)
            .font(.subheadline.weight(.semibold), for: .h4)
            .font(.body.weight(.semibold), for: .h5)
            .font(.body.weight(.medium), for: .h6)
            .padding(.top, 10, for: .h1)
            .padding(.top, 10, for: .h2)
            .padding(.top, 8, for: .h3)
            .padding(.top, 6, for: .h4)
            .padding(.top, 6, for: .h5)
            .padding(.top, 6, for: .h6)
            .textSelection(.enabled)
    }

    private func handleOpenURL(_ url: URL) -> OpenURLAction.Result {
        if url.scheme == "mention" {
            let name = url.host ?? url.lastPathComponent
            onLinkAction?(.mention(username: name))
            return .handled
        }

        if let action = VoleMarkdownLinkDestination(url: url).linkAction {
            onLinkAction?(action)
            return .handled
        }

        return .systemActionPreferringInApp(url)
    }

    /// 系统预览只能打开本地文件。被点击的图片必要时会下载；
    /// 同一内容中的其他图片只在本地已有缓存时加入，便于左右滑动查看，不额外下载。
    @MainActor
    private func openImagePreview(url: URL, imageURLs: [URL]) async {
        let urls = normalizedImageURLs(selected: url, imageURLs: imageURLs)
        do {
            let fileURL = try await MarkdownImagePreviewFiles.fileURL(for: url, allowsDownload: true)
            var fileURLs: [URL] = []
            for imageURL in urls {
                if imageURL == url {
                    fileURLs.append(fileURL)
                } else if let cached = try? await MarkdownImagePreviewFiles.fileURL(
                    for: imageURL,
                    allowsDownload: false
                ) {
                    fileURLs.append(cached)
                }
            }
            try Task.checkCancellation()
            imagePreview.urls = fileURLs
            imagePreview.selection = fileURL
        } catch is CancellationError {
            return
        } catch {
            openURL.openPreferringInApp(url)
        }
    }

    private func normalizedImageURLs(selected url: URL, imageURLs: [URL]) -> [URL] {
        var urls = imageURLs.isEmpty ? [url] : imageURLs
        if !urls.contains(url) {
            urls.insert(url, at: 0)
        }

        var seenURLs = Set<URL>()
        return urls.filter { seenURLs.insert($0).inserted }
    }
}

/// 查看大图的展示状态。
@Observable
private final class MarkdownImagePreviewState {
    var urls: [URL] = []
    var selection: URL?
}

/// 只有这个视图读取预览状态并负责弹出系统预览。
private struct MarkdownImagePreviewHost: View {
    @Bindable var state: MarkdownImagePreviewState

    var body: some View {
        Color.clear
            .quickLookPreview($state.selection, in: state.urls)
    }
}

private struct CompactMarkdownCodeBlockStyle: MarkdownCodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        CompactMarkdownCodeBlock(configuration: configuration)
    }
}

private struct CompactMarkdownCodeBlock: View {
    let configuration: MarkdownCodeBlockStyleConfiguration
    @Environment(\.colorScheme) private var colorScheme
    @State private var didCopy = false
    @State private var highlightedCode: AttributedString?

    var body: some View {
        ScrollView(.horizontal) {
            Group {
                if let highlightedCode {
                    Text(highlightedCode)
                } else {
                    Text(verbatim: displayedCode)
                }
            }
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .lineSpacing(1)
                .padding(.leading, 12)
                .padding(.trailing, 48)
                .padding(.top, 10)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .overlay(alignment: .topTrailing) {
            copyButton
                .padding(7)
        }
        .task(id: highlightID) {
            updateHighlighting()
        }
    }

    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = normalizedCode
            didCopy = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                didCopy = false
            }
        } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(didCopy ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .animation(.snappy(duration: 0.16), value: didCopy)
                .frame(width: 26, height: 26)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(didCopy ? "已复制" : "复制代码")
    }

    private var normalizedCode: String {
        configuration.code
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private var highlightID: String {
        "\(colorScheme)-\(configuration.language ?? "")-\(displayedCode)"
    }

    private func updateHighlighting() {
        guard let highlightr = Highlightr() else { return }
        let theme = colorScheme == .dark ? "dark" : "xcode"
        highlightr.setTheme(to: theme)

        let requestedLanguage = configuration.language?.lowercased() ?? ""
        let language = highlightr.supportedLanguages().first {
            $0.localizedCaseInsensitiveCompare(requestedLanguage) == .orderedSame
        }
        guard let highlighted = highlightr.highlight(
            displayedCode,
            as: language
        ) else {
            highlightedCode = nil
            return
        }

        let result = NSMutableAttributedString(attributedString: highlighted)
        result.removeAttribute(.font, range: NSRange(location: 0, length: result.length))
        highlightedCode = AttributedString(result)
    }

    private var displayedCode: String {
        normalizedCode.hasSuffix("\n")
            ? String(normalizedCode.dropLast())
            : normalizedCode
    }
}

private enum MarkdownRenderBlock {
    case markdown(String)
    case linkPreview(url: URL, title: String?)
}

private enum VoleMarkdownLinkDestination {
    case topic(Int)
    case node(String)
    case external

    init(url: URL) {
        if let topicID = url.v2exTopicID {
            self = .topic(topicID)
        } else if let nodeName = url.v2exNodeName {
            self = .node(nodeName)
        } else {
            self = .external
        }
    }

    var badgeTitle: String {
        switch self {
        case .topic:
            return "话题"
        case .node:
            return "节点"
        case .external:
            return "浏览器"
        }
    }

    var internalTitle: String? {
        switch self {
        case .topic(let id):
            return "话题 #\(id)"
        case .node(let name):
            return "节点 \(name)"
        case .external:
            return nil
        }
    }

    var linkAction: LinkAction? {
        switch self {
        case .topic(let id):
            return .topic(id: id)
        case .node(let name):
            return .node(name: name)
        case .external:
            return nil
        }
    }

    var systemImage: String {
        switch self {
        case .topic:
            return "text.bubble"
        case .node:
            return "square.grid.2x2"
        case .external:
            return "arrow.up.right"
        }
    }

    var tint: Color {
        switch self {
        case .topic, .node:
            return Color.accentColor
        case .external:
            return .secondary
        }
    }

    var isInternal: Bool {
        switch self {
        case .topic, .node:
            return true
        case .external:
            return false
        }
    }
}

private struct VoleMarkdownLinkRenderer: MarkdownLinkRenderer {
    func makeBody(configuration: Configuration) -> some View {
        let destination = VoleMarkdownLinkDestination(url: configuration.url)

        if destination.isInternal {
            Link(destination: configuration.url) {
                MarkdownInternalLinkLabel(destination: destination) {
                    configuration.label
                }
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: configuration.url) {
                configuration.label
                    .foregroundStyle(Color.accentColor)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct MarkdownInternalLinkLabel<Label: View>: View {
    let destination: VoleMarkdownLinkDestination
    let label: Label

    init(
        destination: VoleMarkdownLinkDestination,
        @ViewBuilder label: () -> Label
    ) {
        self.destination = destination
        self.label = label()
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: destination.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(destination.tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(destination.tint.opacity(0.09))
                )
                .overlay {
                    Capsule()
                        .stroke(destination.tint.opacity(0.18), lineWidth: 1)
                }
                .accessibilityHidden(true)

            label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(destination.tint)
        }
    }
}

private struct MarkdownLinkDestinationBadge: View {
    let destination: VoleMarkdownLinkDestination

    var body: some View {
        Label(destination.badgeTitle, systemImage: destination.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(destination.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(destination.tint.opacity(0.12))
            )
    }
}

private enum MarkdownRenderBlockParser {
    private static let markdownLinkPattern =
        #"^\[([^\]]+)\]\((https?://[^)]+)\)$"#

    static func blocks(from content: String) -> [MarkdownRenderBlock] {
        var blocks: [MarkdownRenderBlock] = []
        var markdownLines: [String] = []
        var isInsideCodeFence = false
        let normalizedContent = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        func flushMarkdown() {
            guard !markdownLines.isEmpty else { return }
            blocks.append(.markdown(markdownLines.joined(separator: "\n")))
            markdownLines.removeAll(keepingCapacity: true)
        }

        for line in normalizedContent.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                isInsideCodeFence.toggle()
                markdownLines.append(line)
                continue
            }

            if !isInsideCodeFence,
               let lineComponents = linkPreviewComponents(from: trimmed) {
                flushMarkdown()
                blocks.append(
                    .linkPreview(url: lineComponents.url, title: lineComponents.title)
                )
                continue
            }

            markdownLines.append(line)
        }

        flushMarkdown()
        return blocks
    }

    private static func linkPreviewComponents(from line: String) -> (
        url: URL,
        title: String?
    )? {
        guard !line.isEmpty else { return nil }
        guard !line.hasPrefix("![") else { return nil }

        if let url = URL(string: line),
           url.scheme?.lowercased().hasPrefix("http") == true,
           !url.looksLikeImageURL {
            return (url, nil)
        }

        return standaloneMarkdownLinkComponents(from: line)
    }

    private static func standaloneMarkdownLinkComponents(from line: String) -> (
        url: URL,
        title: String?
    )? {
        guard let regex = try? NSRegularExpression(pattern: markdownLinkPattern)
        else {
            return nil
        }

        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges == 3,
              let titleRange = Range(match.range(at: 1), in: line),
              let urlRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let title = String(line[titleRange])
        let rawURL = String(line[urlRange])
        guard let url = URL(string: rawURL), !url.looksLikeImageURL else {
            return nil
        }

        return (url, title == rawURL ? nil : title)
    }
}

private struct MarkdownLinkPreviewCard: View {
    let url: URL
    let title: String?

    @Environment(\.openURL) private var openURL
    @State private var preview: MarkdownLinkPreviewData?
    @State private var isLoading = false
    @State private var cardHeight = Self.estimatedHeight

    private static let estimatedHeight: CGFloat = 196
    private static let previewImageHeight: CGFloat = 160
    private static let placeholderHeight: CGFloat = 100
    private var destination: VoleMarkdownLinkDestination {
        VoleMarkdownLinkDestination(url: url)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 0)
            linkButton(width: width)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { height in
                    updateCardHeight(height)
                }
        }
        .frame(height: cardHeight)
        .task(id: url) {
            await loadPreviewIfNeeded()
        }
    }

    private func linkButton(width: CGFloat) -> some View {
        Button {
            openURL(url)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                previewImage(width: width)

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)

                    Text(displayHost)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    MarkdownLinkDestinationBadge(
                        destination: destination
                    )

                    if let summary = preview?.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .truncationMode(.middle)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(14)
            }
            .frame(width: width, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func previewImage(width: CGFloat) -> some View {
        if let image = preview?.image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: Self.previewImageHeight)
                .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.20),
                        Color.accentColor.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.accentColor)

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .frame(width: width, height: Self.placeholderHeight)
        }
    }

    private func updateCardHeight(_ height: CGFloat) {
        guard height > 0, abs(cardHeight - height) > 0.5 else {
            return
        }
        cardHeight = height
    }

    private var displayTitle: String {
        if let previewTitle = preview?.title, !previewTitle.isEmpty {
            return previewTitle
        }
        if let title, !title.isEmpty {
            return title
        }
        if let internalTitle = destination.internalTitle {
            return internalTitle
        }
        return url.absoluteString
    }

    private var displayHost: String {
        if let host = preview?.host, !host.isEmpty {
            return host
        }
        return url.host ?? url.absoluteString
    }

    @MainActor
    private func loadPreviewIfNeeded() async {
        if let cached = MarkdownLinkPreviewCache.shared.value(for: url) {
            preview = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let metadata = try? await MarkdownLinkPreviewLoader.metadata(for: url) else {
            return
        }

        MarkdownLinkPreviewCache.shared.insert(metadata, for: url)
        preview = metadata
    }
}

private struct MarkdownLinkPreviewData {
    let title: String?
    let host: String?
    let summary: String?
    let image: UIImage?
}

@MainActor
private final class MarkdownLinkPreviewCache {
    static let shared = MarkdownLinkPreviewCache()

    private var values: [URL: MarkdownLinkPreviewData] = [:]

    func value(for url: URL) -> MarkdownLinkPreviewData? {
        values[url]
    }

    func insert(_ value: MarkdownLinkPreviewData, for url: URL) {
        values[url] = value
    }
}

private enum MarkdownLinkPreviewLoader {
    static func metadata(for url: URL) async throws -> MarkdownLinkPreviewData {
        let provider = LPMetadataProvider()
        let metadata = try await provider.startFetchingMetadata(for: url)

        async let image = loadImage(from: metadata.imageProvider)
        async let icon = loadImage(from: metadata.iconProvider)

        let primaryImage = await image
        let fallbackIcon = await icon
        let resolvedImage = primaryImage ?? fallbackIcon
        let resolvedURL = metadata.originalURL ?? metadata.url ?? url

        return MarkdownLinkPreviewData(
            title: metadata.title,
            host: resolvedURL.host,
            summary: metadata.url?.absoluteString,
            image: resolvedImage
        )
    }

    private static func loadImage(from provider: NSItemProvider?) async -> UIImage? {
        guard let provider else { return nil }

        if provider.canLoadObject(ofClass: UIImage.self) {
            return try? await loadObject(from: provider)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let data = try? await loadData(from: provider),
           let image = UIImage(data: data) {
            return image
        }

        return nil
    }

    private static func loadObject(from provider: NSItemProvider) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let image = object as? UIImage {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: CocoaError(.coderInvalidValue))
                }
            }
        }
    }

    private static func loadData(from provider: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
                data,
                error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: CocoaError(.fileReadUnknown))
                }
            }
        }
    }
}

private struct TappableMarkdownImageRenderer: MarkdownImageRenderer {
    let imageURLs: [URL]
    var openImagePreview: @MainActor (URL, [URL]) async -> Void

    func makeBody(configuration: Configuration) -> some View {
        TappableMarkdownImage(
            url: configuration.url,
            imageURLs: imageURLs,
            openImagePreview: openImagePreview
        )
    }
}

private struct TappableMarkdownImage: View {
    let url: URL
    let imageURLs: [URL]
    var openImagePreview: @MainActor (URL, [URL]) async -> Void
    @State private var imageSize: CGSize?
    /// 准备状态由每张图片自己保存，点击时只刷新这一张，不触发整段内容重新渲染。
    @State private var previewTask: Task<Void, Never>?
    @State private var showsPreparingIndicator = false

    init(
        url: URL,
        imageURLs: [URL],
        openImagePreview: @escaping @MainActor (URL, [URL]) async -> Void
    ) {
        self.url = url
        self.imageURLs = imageURLs
        self.openImagePreview = openImagePreview
        _imageSize = State(
            initialValue: MarkdownImageMetadata.cachedSize(for: url)
        )
    }

    /// 宽高比；尺寸未知时为 nil。
    private var aspectRatio: CGFloat? {
        guard let imageSize, imageSize.width > 0, imageSize.height > 0 else { return nil }
        return imageSize.width / imageSize.height
    }

    /// 直接按宽高比布局，不依赖测量到的容器宽度：视图被重建时第一帧的高度也是正确的，
    /// 不会先塌成占位大小再展开。
    var body: some View {
        renderedImage
            .aspectRatio(aspectRatio, contentMode: .fit)
            // 尺寸未知时先占用一个小方块；已知时不超过原图宽度。
            .frame(
                width: aspectRatio == nil ? 44 : nil,
                height: aspectRatio == nil ? 44 : nil
            )
            .frame(maxWidth: imageSize?.width)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if showsPreparingIndicator {
                    ProgressView()
                        .padding(12)
                        .background(.regularMaterial, in: Circle())
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                preparePreview()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("查看大图")
            .frame(maxWidth: .infinity, alignment: .leading)
            .onDisappear {
                previewTask?.cancel()
                previewTask = nil
                showsPreparingIndicator = false
            }
    }

    private func preparePreview() {
        guard previewTask == nil else { return }
        previewTask = Task {
            // 文件很快准备好时不显示加载指示，避免闪烁。
            let indicator = Task {
                try await Task.sleep(for: .milliseconds(150))
                withAnimation(.easeIn(duration: 0.15)) { showsPreparingIndicator = true }
            }
            await openImagePreview(url, imageURLs)
            indicator.cancel()
            showsPreparingIndicator = false
            previewTask = nil
        }
    }

    @ViewBuilder
    private var renderedImage: some View {
        if url.isGIF {
            animatedImage
        } else {
            staticImage
        }
    }

    private var animatedImage: some View {
        KFAnimatedImage(url)
            .configure { view in
                view.autoPlayAnimatedImage = true
                view.repeatCount = .infinite
                view.framePreloadCount = 3
                view.needsPrescaling = false
                view.contentMode = .scaleAspectFit
            }
            .placeholder {
                imagePlaceholder
            }
            .onSuccess { result in
                handleImageLoaded(result, preserveExistingSize: true)
            }
    }

    private var staticImage: some View {
        KFImage(url)
            .placeholder {
                imagePlaceholder
            }
            .onSuccess { result in
                handleImageLoaded(result, preserveExistingSize: false)
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private var imagePlaceholder: some View {
        ProgressView()
            .frame(width: 44, height: 44)
    }

    private func handleImageLoaded(_ result: RetrieveImageResult, preserveExistingSize: Bool) {
        let size = result.image.size
        MarkdownImageMetadata.store(size, for: url)
        if imageSize == nil || !preserveExistingSize {
            imageSize = size
        }
    }
}

private struct HorizontalScrollableMarkdownTableStyle: MarkdownTableStyle {
    func makeBody(configuration: Configuration) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 0) {
                configuration.table
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.background.secondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.secondary.opacity(0.28), lineWidth: 1)
                    )
            }
        }
    }
}

private enum MarkdownImageMetadata {
    private static let sizeCache = NSCache<NSURL, NSValue>()

    static func cachedSize(for url: URL) -> CGSize? {
        if let size = sizeCache.object(forKey: url as NSURL)?.cgSizeValue {
            return size
        }

        guard let size = ImageCache.default
            .retrieveImageInMemoryCache(forKey: url.cacheKey)?
            .size else {
            return nil
        }

        store(size, for: url)
        return size
    }

    static func store(_ size: CGSize, for url: URL) {
        guard size.width > 0, size.height > 0 else { return }
        sizeCache.setObject(NSValue(cgSize: size), forKey: url as NSURL)
    }
}

/// 查看大图使用的本地预览文件。系统预览只能打开本地文件，这里直接使用图片的
/// 原始数据（优先硬链接 Kingfisher 的磁盘缓存文件），不重新编码。
enum MarkdownImagePreviewFiles {
    private static let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("VoleMarkdownQuickLookImages", isDirectory: true)

    /// 每次启动使用独立的子目录，后台清理旧文件时不会影响本次生成的文件。
    fileprivate static let directory = rootDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    /// 准备单张图片的预览文件；同一张图片同时只准备一次。
    /// - Parameter allowsDownload: 为 false 时只使用本地缓存，没有缓存则抛出错误。
    static func fileURL(for url: URL, allowsDownload: Bool) async throws -> URL {
        try await MarkdownImagePreviewFileStore.shared.fileURL(for: url, allowsDownload: allowsDownload)
    }

    /// 在后台删除以往启动留下的预览文件。
    static func removeStaleFiles() {
        let root = rootDirectory
        let current = directory.lastPathComponent
        Task.detached(priority: .background) {
            let fileManager = FileManager.default
            let items = (try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil
            )) ?? []
            for item in items where item.lastPathComponent != current {
                try? fileManager.removeItem(at: item)
            }
        }
    }
}

private enum MarkdownImagePreviewError: Error {
    case notCached
    case invalidImage
}

private actor MarkdownImagePreviewFileStore {
    static let shared = MarkdownImagePreviewFileStore()

    private var preparedFiles: [URL: URL] = [:]
    private var tasks: [URL: Task<URL, Error>] = [:]

    func fileURL(for url: URL, allowsDownload: Bool) async throws -> URL {
        if let fileURL = preparedFiles[url], FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        if let task = tasks[url] {
            return try await task.value
        }
        guard allowsDownload || ImageCache.default.isCached(forKey: url.cacheKey) else {
            throw MarkdownImagePreviewError.notCached
        }

        let task = Task.detached(priority: .userInitiated) {
            try await Self.makeFile(for: url, allowsDownload: allowsDownload)
        }
        tasks[url] = task
        defer { tasks[url] = nil }
        let fileURL = try await task.value
        preparedFiles[url] = fileURL
        return fileURL
    }

    /// 依次使用 Kingfisher 磁盘缓存中的原始文件、重新下载。
    private static func makeFile(for url: URL, allowsDownload: Bool) async throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: MarkdownImagePreviewFiles.directory,
            withIntermediateDirectories: true
        )
        let baseURL = MarkdownImagePreviewFiles.directory
            .appendingPathComponent(url.absoluteString.stableFileName)

        if let cacheFileURL = ImageCache.default.cacheFileURLIfOnDisk(forKey: url.cacheKey),
            let fileExtension = imageFileExtension(
                of: CGImageSourceCreateWithURL(cacheFileURL as CFURL, nil)
            )
        {
            let fileURL = baseURL.appendingPathExtension(fileExtension)
            try? fileManager.removeItem(at: fileURL)
            do {
                // 同一磁盘内硬链接不复制数据；Kingfisher 之后清理缓存也不影响这份文件。
                try fileManager.linkItem(at: cacheFileURL, to: fileURL)
            } catch {
                try fileManager.copyItem(at: cacheFileURL, to: fileURL)
            }
            return fileURL
        }

        guard allowsDownload else { throw MarkdownImagePreviewError.notCached }
        try Task.checkCancellation()
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        let (data, _) = try await URLSession.shared.data(for: request)
        // 图床可能返回错误页等非图片内容，这时视为失败，改为打开网页。
        guard let fileExtension = imageFileExtension(
            of: CGImageSourceCreateWithData(data as CFData, nil)
        ) else {
            throw MarkdownImagePreviewError.invalidImage
        }
        let fileURL = baseURL.appendingPathExtension(fileExtension)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// 内容是有效图片时返回对应的文件扩展名。
    private static func imageFileExtension(of source: CGImageSource?) -> String? {
        guard let source,
            CGImageSourceGetCount(source) > 0,
            let type = CGImageSourceGetType(source),
            let utType = UTType(type as String),
            utType.conforms(to: .image)
        else { return nil }
        return utType.preferredFilenameExtension ?? "img"
    }
}

private extension URL {
    var isGIF: Bool {
        let normalized = absoluteString.lowercased()
        return pathExtension.lowercased() == "gif"
            || normalized.contains(".gif?")
            || normalized.hasSuffix(".gif")
    }

    var looksLikeImageURL: Bool {
        let normalized = absoluteString.lowercased()
        return normalized.range(
            of: #"\.(png|jpg|jpeg|gif|webp|bmp|tiff)(\?.*)?$"#,
            options: .regularExpression
        ) != nil
    }

    var v2exTopicID: Int? {
        let host = host?.lowercased()
        guard SiteConfiguration.matchesCurrentSite(host: host) else {
            return nil
        }

        let components = pathComponents
        guard components.count >= 3, components[1] == "t" else {
            return nil
        }

        return Int(components[2])
    }

    var v2exNodeName: String? {
        let host = host?.lowercased()
        guard SiteConfiguration.matchesCurrentSite(host: host) else {
            return nil
        }

        let components = pathComponents
        guard components.count >= 3, components[1] == "go" else {
            return nil
        }

        return components[2].removingPercentEncoding ?? components[2]
    }
}

private extension String {
    var stableFileName: String {
        let hash = unicodeScalars.reduce(UInt64(5381)) { result, scalar in
            ((result << 5) &+ result) &+ UInt64(scalar.value)
        }
        return String(format: "%016llx", hash)
    }
}

private enum MarkdownImageCollector {
    static func imageURLs(in markdown: String) -> [URL] {
        guard let regex = try? NSRegularExpression(
            pattern: #"!\[[^\]]*\]\(([^)]+)\)"#
        ) else {
            return []
        }

        let nsMarkdown = markdown as NSString
        let matches = regex.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        )

        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }

            let rawURL = nsMarkdown
                .substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(string: rawURL)
        }
    }
}

private struct MarkdownContentFormatter {
    private let protectedPattern =
        #"(?s)(```.*?```|`[^`\n]*`|!?\[(?:[^\[\]]|\[[^\]]*\])*\]\([^)]+\))"#
    private let spacedLinkDestinationPattern =
        #"(!?\[(?:[^\[\]]|\[[^\]]*\])*\])\(\s*(https?://[^)\s]+)\s*\)"#
    private let mentionPattern =
        #"(?<![\p{L}0-9_])@([\p{L}0-9_]+)(?![\p{L}0-9_])"#
    private let urlPattern =
        #"https?://[^\s<>()\[\]{}]+"#
    private let imageURLPattern =
        #"(?i)^https?://\S+\.(?:png|jpg|jpeg|gif|webp|bmp|tiff)(?:\?\S*)?$"#

    func format(_ content: String) -> (markdown: String, mentions: [String]) {
        var mentions: [String] = []
        let normalizedContent = normalizeLinkDestinations(in: content)
        let markdown = transformUnprotectedSegments(in: normalizedContent) {
            segment in
            processTextSegment(segment, mentions: &mentions)
        }
        return (markdown, mentions)
    }

    private func normalizeLinkDestinations(in content: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: spacedLinkDestinationPattern
        ) else {
            return content
        }

        let range = NSRange(content.startIndex..., in: content)
        return regex.stringByReplacingMatches(
            in: content,
            range: range,
            withTemplate: "$1($2)"
        )
    }

    private func transformUnprotectedSegments(
        in content: String,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: protectedPattern)
        else {
            return transform(content)
        }

        let nsContent = content as NSString
        let matches = regex.matches(
            in: content,
            range: NSRange(location: 0, length: nsContent.length)
        )
        var result = ""
        var cursor = 0

        for match in matches {
            if match.range.location > cursor {
                let range = NSRange(
                    location: cursor,
                    length: match.range.location - cursor
                )
                result += transform(nsContent.substring(with: range))
            }

            result += nsContent.substring(with: match.range)
            cursor = match.range.location + match.range.length
        }

        if cursor < nsContent.length {
            result += transform(nsContent.substring(from: cursor))
        }

        return result
    }

    private func processTextSegment(
        _ text: String,
        mentions: inout [String]
    ) -> String {
        guard let urlRegex = try? NSRegularExpression(pattern: urlPattern)
        else {
            return processMentions(in: text, mentions: &mentions)
        }

        let nsText = text as NSString
        let matches = urlRegex.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )
        var result = ""
        var cursor = 0

        for match in matches {
            if match.range.location > cursor {
                let range = NSRange(
                    location: cursor,
                    length: match.range.location - cursor
                )
                result += processMentions(
                    in: nsText.substring(with: range),
                    mentions: &mentions
                )
            }

            let rawURL = nsText.substring(with: match.range)
            let (url, suffix) = trimTrailingURLPunctuation(rawURL)
            result += markdownLink(for: url) + suffix
            cursor = match.range.location + match.range.length
        }

        if cursor < nsText.length {
            result += processMentions(
                in: nsText.substring(from: cursor),
                mentions: &mentions
            )
        }

        return result
    }

    private func processMentions(
        in text: String,
        mentions: inout [String]
    ) -> String {
        replaceMatches(
            in: text,
            pattern: mentionPattern
        ) { _, match in
            guard let nameRange = Range(match.range(at: 1), in: text)
            else {
                return nil
            }

            let name = String(text[nameRange])
            mentions.append(name)
            let encoded = name.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed
            ) ?? name
            return "[@\(name)](mention://\(encoded))"
        }
    }

    private func replaceMatches(
        in text: String,
        pattern: String,
        replacement: (String, NSTextCheckingResult) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        var result = text
        let nsText = text as NSString
        let matches = regex.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else {
                continue
            }
            let matchText = String(result[range])
            guard let replacement = replacement(matchText, match) else {
                continue
            }
            result.replaceSubrange(range, with: replacement)
        }

        return result
    }

    private func markdownLink(for url: String) -> String {
        if url.range(of: imageURLPattern, options: .regularExpression) != nil {
            return "![image](\(url))"
        }
        if let parsedURL = URL(string: url),
            let internalTitle = VoleMarkdownLinkDestination(url: parsedURL)
                .internalTitle
        {
            return "[\(internalTitle)](\(url))"
        }
        return "[\(url)](\(url))"
    }

    private func trimTrailingURLPunctuation(_ url: String)
        -> (url: String, suffix: String)
    {
        var trimmed = url
        var suffix = ""
        while let last = trimmed.last, ".,;:!?".contains(last) {
            suffix.insert(last, at: suffix.startIndex)
            trimmed.removeLast()
        }
        return (trimmed, suffix)
    }

}

#Preview {

    ScrollView {
        let markdownString = """
            帮 OP 重发图片。    
                
            ![image](https://i.imgur.com/61pfQZT.png)    
            ![image](https://i.imgur.com/4WJyF6w.png)    
            ![image](https://i.imgur.com/KEBNsVW.png)    
            ![image](https://i.imgur.com/yVTQO66.png)    
            ![image](https://i.imgur.com/Moyp0xD.png)    
            ![image](https://i.imgur.com/qY9MksK.png)    
            ![image](https://i.imgur.com/v0XnJTS.png)    
            ![image](https://i.imgur.com/zy09Dt6.png)    
            ![image](https://i.imgur.com/lDFqr3j.png)    
            ![image](https://i.imgur.com/0uptnWx.png)
            """

        VoleMarkdownView(content: markdownString)
    }
}
