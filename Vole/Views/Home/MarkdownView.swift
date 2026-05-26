//
//  MarkdownView.swift
//  Vole
//
//  Created by 杨权 on 8/23/25.
//

import Foundation
import Kingfisher
import MarkdownView
import QuickLook
import SwiftUI

enum LinkAction {
    case mention(username: String)
    case topic(id: Int)
    case node(id: Int)
}

struct VoleMarkdownView: View {
    @State var content: String
    @State private var quickLookURLs: [URL] = []
    @State private var selectedQuickLookURL: URL?
    @State private var isPreparingImagePreview = false

    var onMentionsChanged: (([String]) -> Void)?
    var onLinkAction: ((LinkAction) -> Void)?  // 统一处理链接事件

    var body: some View {
        let (md, mentions) = makeMarkdown(content)
        let imageURLs = MarkdownImageCollector.imageURLs(in: md)

        MarkdownView(md)
            .markdownImageRenderer(
                TappableMarkdownImageRenderer(
                    imageURLs: imageURLs,
                    openImagePreview: openImagePreview
                ),
                forURLScheme: "http"
            )
            .markdownImageRenderer(
                TappableMarkdownImageRenderer(
                    imageURLs: imageURLs,
                    openImagePreview: openImagePreview
                ),
                forURLScheme: "https"
            )
            .markdownTableStyle(HorizontalScrollableMarkdownTableStyle())
            .textSelection(.enabled)
            .overlay(alignment: .center) {
                if isPreparingImagePreview {
                    ProgressView()
                        .padding(14)
                        .background(.regularMaterial, in: Circle())
                }
            }
            .quickLookPreview($selectedQuickLookURL, in: quickLookURLs)
            // 把 mention 列表回调给外部
            .task(id: content) { @MainActor in
                onMentionsChanged?(mentions)
            }
            // 统一拦截链接事件
            .environment(
                \.openURL,
                OpenURLAction { url in
                    if url.scheme == "mention" {
                        let name = url.host ?? url.lastPathComponent
                        onLinkAction?(.mention(username: name))
                        return .handled
                    }

                    // 匹配 V2EX 帖子链接
                    let host = url.host?.lowercased()
                    if host == "v2ex.com" || host == "www.v2ex.com" {
                        let components = url.pathComponents
                        if components.count >= 3, components[1] == "t",
                            let topicId = Int(components[2])
                        {
                            onLinkAction?(.topic(id: topicId))
                            return .handled
                        }
                    }

                    // 统一用全局打开逻辑
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                    return .handled
                }
            )
    }

    private func makeMarkdown(_ content: String) -> (String, [String]) {
        MarkdownContentFormatter().format(content)
    }

    @MainActor
    private func openImagePreview(
        url: URL,
        image: KFCrossPlatformImage?,
        imageURLs: [URL]
    ) {
        Task {
            do {
                if image == nil {
                    await MainActor.run {
                        isPreparingImagePreview = true
                    }
                }

                let fileURL = try await MarkdownQuickLookImageExporter.fileURL(
                    for: url,
                    image: image
                )

                await MainActor.run {
                    quickLookURLs = [fileURL]
                    selectedQuickLookURL = fileURL
                    isPreparingImagePreview = false
                }

                let urls = imageURLs.isEmpty ? [url] : imageURLs
                let fileURLs = try await MarkdownQuickLookImageExporter.fileURLs(
                    for: urls,
                    preferredImage: image,
                    preferredURL: url
                )

                await MainActor.run {
                    quickLookURLs = fileURLs
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
}

private struct TappableMarkdownImageRenderer: MarkdownImageRenderer {
    let imageURLs: [URL]
    var openImagePreview: @MainActor (URL, KFCrossPlatformImage?, [URL]) -> Void

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
    var openImagePreview: @MainActor (URL, KFCrossPlatformImage?, [URL]) -> Void
    @State private var imageSize: CGSize?
    @State private var previewImage: KFCrossPlatformImage?
    @State private var availableWidth: CGFloat = 0

    private var displaySize: CGSize {
        guard let imageSize, imageSize.width > 0 else {
            return CGSize(width: 44, height: 44)
        }

        let maxWidth = availableWidth > 0 ? availableWidth : imageSize.width
        let width = min(imageSize.width, maxWidth)
        let height = imageSize.height * width / imageSize.width
        return CGSize(width: width, height: height)
    }

    var body: some View {
        let size = displaySize

        KFImage(url)
            .placeholder {
                ProgressView()
                    .frame(width: 44, height: 44)
            }
            .onSuccess { result in
                previewImage = result.image
                imageSize = result.image.size
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(
                width: size.width,
                height: size.height,
                alignment: .leading
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                openImagePreview(url, previewImage, imageURLs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: size.height, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            availableWidth = proxy.size.width
                        }
                        .onChange(of: proxy.size.width) { _, width in
                            availableWidth = width
                        }
                }
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

private enum MarkdownQuickLookImageExporter {
    static func fileURLs(
        for urls: [URL],
        preferredImage: KFCrossPlatformImage?,
        preferredURL: URL
    ) async throws -> [URL] {
        var exportedURLs: [URL] = []
        var exportedSourceURLs = Set<URL>()

        for url in urls {
            guard exportedSourceURLs.insert(url).inserted else { continue }

            if let fileURL = try? await fileURL(
                for: url,
                image: url == preferredURL ? preferredImage : nil
            ) {
                exportedURLs.append(fileURL)
            }
        }

        return exportedURLs
    }

    static func fileURL(
        for url: URL,
        image: KFCrossPlatformImage?
    ) async throws -> URL {
        let fileURL = previewFileURL(for: url)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        let exportImage: KFCrossPlatformImage
        if let cachedImage = image {
            exportImage = cachedImage
        } else {
            exportImage = try await retrieveImage(for: url)
        }

        guard let data = exportImage.kf.pngRepresentation() else {
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

    private static func previewFileURL(for url: URL) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoleMarkdownQuickLookImages", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
            .appendingPathComponent(url.absoluteString.stableFileName)
            .appendingPathExtension("png")
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
        #"(?s)(```.*?```|`[^`\n]*`|!\[[^\]]*\]\([^)]+\)|\[[^\]]+\]\([^)]+\))"#
    private let mentionPattern =
        #"(?<![\p{L}0-9_])@([\p{L}0-9_]+)(?![\p{L}0-9_])"#
    private let urlPattern =
        #"https?://[^\s<>()\[\]{}]+"#
    private let imageURLPattern =
        #"(?i)^https?://\S+\.(?:png|jpg|jpeg|gif|webp|bmp|tiff)(?:\?\S*)?$"#

    func format(_ content: String) -> (markdown: String, mentions: [String]) {
        var mentions: [String] = []
        let markdown = transformUnprotectedSegments(in: content) {
            segment in
            processTextSegment(segment, mentions: &mentions)
        }
        return (markdown, mentions)
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
