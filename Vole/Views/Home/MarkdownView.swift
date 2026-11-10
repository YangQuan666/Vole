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
    @State private var quickLookURLs: [URL] = []
    @State private var selectedQuickLookURL: URL?
    @State private var isPreparingImagePreview = false

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
        .overlay {
            if isPreparingImagePreview {
                ProgressView()
                    .padding(14)
                    .background(.regularMaterial, in: Circle())
            }
        }
        .quickLookPreview($selectedQuickLookURL, in: quickLookURLs)
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

    @MainActor
    private func openImagePreview(
        url: URL,
        image: KFCrossPlatformImage?,
        sourceData: Data?,
        imageURLs: [URL]
    ) {
        let urls = normalizedImageURLs(selected: url, imageURLs: imageURLs)
        isPreparingImagePreview = MarkdownQuickLookImageExporter.cachedFileURL(for: url) == nil

        Task(priority: .userInitiated) {
            do {
                let fileURL = try await MarkdownQuickLookImageExporter.fileURL(
                    for: url,
                    image: image,
                    sourceData: sourceData
                )

                await MainActor.run {
                    quickLookURLs = [fileURL]
                    selectedQuickLookURL = fileURL
                    isPreparingImagePreview = false
                }

                let allFileURLs = try await MarkdownQuickLookImageExporter.fileURLs(
                    for: urls,
                    preferredImage: image,
                    preferredData: sourceData,
                    preferredURL: url
                )

                await MainActor.run {
                    quickLookURLs = allFileURLs
                    selectedQuickLookURL = fileURL
                }
            } catch {
                await MainActor.run {
                    isPreparingImagePreview = false
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
            }
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
    var openImagePreview: @MainActor (URL, KFCrossPlatformImage?, Data?, [URL]) -> Void

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
    var openImagePreview: @MainActor (URL, KFCrossPlatformImage?, Data?, [URL]) -> Void
    @State private var imageSize: CGSize?
    @State private var previewImage: KFCrossPlatformImage?
    @State private var previewData: Data?
    @State private var containerWidth: CGFloat = 0

    init(
        url: URL,
        imageURLs: [URL],
        openImagePreview: @escaping @MainActor (
            URL,
            KFCrossPlatformImage?,
            Data?,
            [URL]
        ) -> Void
    ) {
        self.url = url
        self.imageURLs = imageURLs
        self.openImagePreview = openImagePreview
        _imageSize = State(
            initialValue: MarkdownImageMetadata.cachedSize(for: url)
        )
    }

    private func displaySize(maxWidth: CGFloat) -> CGSize {
        // 尚未拿到图片尺寸或容器宽度时，先占用一个小方块，
        // 待 onGeometryChange 测得宽度后再按比例展开。
        guard let imageSize, maxWidth > 0 else {
            let fallbackSide = min(maxWidth > 0 ? maxWidth : 44, 44)
            return CGSize(width: fallbackSide, height: fallbackSide)
        }

        let width = min(imageSize.width, maxWidth)
        let height = imageSize.height * width / imageSize.width
        return CGSize(width: width, height: height)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = displaySize(maxWidth: proxy.size.width)

            renderedImage
                .frame(
                    width: size.width,
                    height: size.height,
                    alignment: .leading
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    openImagePreview(url, previewImage, previewData, imageURLs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: size.height, alignment: .leading)
        }
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            guard width > 0, abs(containerWidth - width) > 0.5 else { return }
            containerWidth = width
        }
        .frame(height: displaySize(maxWidth: containerWidth).height)
        .task(id: url) {
            await loadImageSizeIfNeeded()
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
        let sourceData = url.isAnimatedPreviewCandidate ? result.data() : nil
        handleImageLoaded(
            result.image,
            sourceData: sourceData,
            preserveExistingSize: preserveExistingSize
        )
    }

    private func handleImageLoaded(
        _ image: KFCrossPlatformImage,
        sourceData: Data?,
        preserveExistingSize: Bool
    ) {
        MarkdownImageMetadata.store(image.size, for: url)
        previewImage = image
        if let sourceData {
            previewData = sourceData
        }
        if imageSize == nil || !preserveExistingSize {
            imageSize = image.size
        }
        MarkdownQuickLookImageExporter.preheat(
            url: url,
            image: image,
            sourceData: sourceData
        )
    }

    @MainActor
    private func loadImageSizeIfNeeded() async {
        guard imageSize == nil else { return }
        guard let size = try? await MarkdownImageMetadata.imageSize(for: url) else {
            return
        }
        imageSize = size
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

    static func imageSize(for url: URL) async throws -> CGSize {
        if let size = cachedSize(for: url) {
            return size
        }

        let data = try await MarkdownImageDataLoader.data(for: url)

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0,
              height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let size = CGSize(width: width, height: height)
        store(size, for: url)
        return size
    }
}

private enum MarkdownQuickLookImageExporter {
    static func cachedFileURL(for url: URL) -> URL? {
        for format in ImageExportFormat.allCases {
            let fileURL = previewFileURL(for: url, format: format)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        return nil
    }

    static func preheat(
        url: URL,
        image: KFCrossPlatformImage?,
        sourceData: Data?
    ) {
        Task(priority: .utility) {
            await MarkdownQuickLookImagePreheater.shared.preheat(
                url: url,
                image: image,
                sourceData: sourceData
            )
        }
    }

    static func fileURLs(
        for urls: [URL],
        preferredImage: KFCrossPlatformImage?,
        preferredData: Data?,
        preferredURL: URL
    ) async throws -> [URL] {
        var exportedURLs: [URL] = []
        var exportedSourceURLs = Set<URL>()

        for url in urls {
            guard exportedSourceURLs.insert(url).inserted else { continue }

            if let fileURL = try? await fileURL(
                for: url,
                image: url == preferredURL ? preferredImage : nil,
                sourceData: url == preferredURL ? preferredData : nil
            ) {
                exportedURLs.append(fileURL)
            }
        }

        return exportedURLs
    }

    static func fileURL(
        for url: URL,
        image: KFCrossPlatformImage?,
        sourceData: Data?
    ) async throws -> URL {
        if let cachedFileURL = cachedFileURL(for: url) {
            return cachedFileURL
        }

        let resolvedSourceData = try await retrieveOriginalData(
            for: url,
            sourceData: sourceData
        )
        let exportFormat = ImageExportFormat.infer(from: resolvedSourceData, url: url)
        let fileURL = previewFileURL(for: url, format: exportFormat)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        if exportFormat.preservesAnimation {
            try resolvedSourceData.write(to: fileURL, options: .atomic)
            return fileURL
        }

        let exportImage: KFCrossPlatformImage
        if let image {
            exportImage = image
        } else {
            exportImage = try await retrieveImage(for: url)
        }

        guard let data = exportFormat.data(from: exportImage) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func retrieveImage(for url: URL) async throws -> KFCrossPlatformImage {
        let resource = KF.ImageResource(downloadURL: url)
        return try await KingfisherManager.shared
            .retrieveImage(with: resource)
            .image
    }

    private static func retrieveOriginalData(
        for url: URL,
        sourceData: Data?
    ) async throws -> Data {
        if let sourceData {
            return sourceData
        }

        if let cachedData = try kingfisherCachedData(for: url) {
            return cachedData
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    private static func kingfisherCachedData(for url: URL) throws -> Data? {
        guard let fileURL = ImageCache.default.cacheFileURLIfOnDisk(forKey: url.cacheKey) else {
            return nil
        }
        return try Data(contentsOf: fileURL)
    }

    private static func previewFileURL(for url: URL, format: ImageExportFormat) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoleMarkdownQuickLookImages", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
            .appendingPathComponent(url.absoluteString.stableFileName)
            .appendingPathExtension(format.fileExtension)
    }
}

private actor MarkdownQuickLookImagePreheater {
    static let shared = MarkdownQuickLookImagePreheater()

    private var activeURLs = Set<URL>()

    func preheat(
        url: URL,
        image: KFCrossPlatformImage?,
        sourceData: Data?
    ) async {
        guard activeURLs.insert(url).inserted else { return }
        defer { activeURLs.remove(url) }

        guard MarkdownQuickLookImageExporter.cachedFileURL(for: url) == nil else {
            return
        }

        _ = try? await MarkdownQuickLookImageExporter.fileURL(
            for: url,
            image: image,
            sourceData: sourceData
        )
    }
}

private enum ImageExportFormat: CaseIterable {
    case gif
    case png
    case jpeg
    case webp
    case bmp
    case tiff

    var fileExtension: String {
        switch self {
        case .gif: return "gif"
        case .png: return "png"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        case .bmp: return "bmp"
        case .tiff: return "tiff"
        }
    }

    var preservesAnimation: Bool {
        switch self {
        case .gif, .webp:
            return true
        default:
            return false
        }
    }

    func data(from image: KFCrossPlatformImage) -> Data? {
        switch self {
        case .gif:
            return image.kf.gifRepresentation()
        case .png:
            return image.kf.pngRepresentation()
        case .jpeg:
            return image.kf.jpegRepresentation(compressionQuality: 1.0)
        case .webp, .bmp, .tiff:
            return image.kf.pngRepresentation()
        }
    }

    static func infer(from data: Data, url: URL) -> ImageExportFormat {
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let type = CGImageSourceGetType(source),
           let utType = UTType(type as String) {
            switch utType {
            case .gif:
                return .gif
            case .png:
                return .png
            case .jpeg:
                return .jpeg
            case .webP:
                return .webp
            case .bmp:
                return .bmp
            case .tiff:
                return .tiff
            default:
                break
            }
        }

        switch url.pathExtension.lowercased() {
        case "gif":
            return .gif
        case "jpg", "jpeg":
            return .jpeg
        case "webp":
            return .webp
        case "bmp":
            return .bmp
        case "tif", "tiff":
            return .tiff
        default:
            return .png
        }
    }
}

private enum MarkdownImageDataLoader {
    static func data(for url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}

private extension URL {
    var isAnimatedPreviewCandidate: Bool {
        let normalized = absoluteString.lowercased()
        let ext = pathExtension.lowercased()
        return ext == "gif"
            || ext == "webp"
            || normalized.contains(".gif?")
            || normalized.contains(".webp?")
            || normalized.hasSuffix(".gif")
            || normalized.hasSuffix(".webp")
    }

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
