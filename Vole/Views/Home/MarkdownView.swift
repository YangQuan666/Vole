//
//  MarkdownView.swift
//  Vole
//
//  Created by 杨权 on 8/23/25.
//

import Kingfisher
import MarkdownUI
import SwiftUI

enum LinkAction {
    case mention(username: String)
    case topic(id: Int)
    case node(id: Int)
}

struct MarkdownView: View {
    @State var content: String
    @State private var isRendering = true

    var onMentionsChanged: (([String]) -> Void)?
    var onLinkAction: ((LinkAction) -> Void)?  // 统一处理链接事件

    @Environment(\.appOpenURL) private var appOpenURL

    var body: some View {
        let (md, mentions) = makeMarkdown(content)

        Markdown(md)
            .markdownInlineImageProvider(KFInlineImageProvider())
            .textSelection(.enabled)
            .markdownTheme(.basic)
            .markdownTextStyle(\.link) {
                ForegroundColor(.accentColor)
                FontWeight(.semibold)
            }
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
        var mentions: [String] = []
        var result = ""

        // 用正则拆分原始内容，保留 Markdown 图片/链接
        let pattern = #"(!\[.*?\]\(.*?\)|\[.*?\]\(.*?\))"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = content as NSString
        var last = 0

        let matches = regex.matches(
            in: content,
            range: NSRange(location: 0, length: ns.length)
        )

        for match in matches {
            // 普通文本片段
            let rangeBefore = NSRange(
                location: last,
                length: match.range.location - last
            )
            let textBefore = ns.substring(with: rangeBefore)
            result += processTextFragment(textBefore, &mentions)

            // 已有 Markdown 图片或链接，直接保留
            let markdownFragment = ns.substring(with: match.range)
            result += markdownFragment

            last = match.range.location + match.range.length
        }

        // 尾部普通文本
        if last < ns.length {
            let tail = ns.substring(from: last)
            result += processTextFragment(tail, &mentions)
        }

        // 把 \n / \r\n 统一转换为 Markdown 硬换行
//        result =
//            result
//            .replacingOccurrences(of: "\r\n", with: "  \n")
//            .replacingOccurrences(of: "\n", with: "  \n")
//        print("处理后的md文档: \(result)")
        return (result, mentions)
    }

    // 处理普通文本片段：@mention + 图片 URL
    private func processTextFragment(_ text: String, _ mentions: inout [String])
        -> String
    {
        var result = text
        let mentionPattern = #"(?<![\p{L}0-9_])@([\p{L}0-9_]+)(?![\p{L}0-9_])"#
        let imagePattern = #"https?://\S+\.(png|jpg|jpeg|gif|webp|bmp|tiff)"#

        // @mention
        if let mentionRegex = try? NSRegularExpression(pattern: mentionPattern)
        {
            let nsText = result as NSString
            let matches = mentionRegex.matches(
                in: result,
                range: NSRange(location: 0, length: nsText.length)
            )
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: result) {
                    let name = String(result[range])
                    mentions.append(name)
                    let encoded =
                        name.addingPercentEncoding(
                            withAllowedCharacters: .urlPathAllowed
                        ) ?? name
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(
                            fullRange,
                            with: "[@\(name)](mention://\(encoded))"
                        )
                    }
                }
            }
        }

        // 图片 URL
        if let imageRegex = try? NSRegularExpression(pattern: imagePattern) {
            let nsText = result as NSString
            let matches = imageRegex.matches(
                in: result,
                range: NSRange(location: 0, length: nsText.length)
            )
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    let url = String(result[range])
                    result.replaceSubrange(range, with: "![image](\(url))")
                }
            }
        }

        return result
    }
}

struct KFInlineImageProvider: InlineImageProvider {
    func image(with url: URL, label: String) async throws -> Image {
        let targetPointHeight: CGFloat = 2
        let scale = await UIScreen.main.scale

        // 先加载原图（或缓存中的）
        let result = try await KingfisherManager.shared.retrieveImage(
            with: url,
            options: [.cacheOriginalImage]
        )

        let uiImage = result.image
        let originalSize = uiImage.size

        // 高度大于限制，按比例缩放
        if originalSize.height > targetPointHeight {
            let aspectRatio = originalSize.width / originalSize.height
            let targetSize = CGSize(
                width: targetPointHeight * aspectRatio * scale,
                height: targetPointHeight * scale
            )

            let processor = DownsamplingImageProcessor(size: targetSize)

            let resized = try await KingfisherManager.shared.retrieveImage(
                with: url,
                options: [
                    .processor(processor),
                    .scaleFactor(scale),
                    .cacheOriginalImage
                ]
            )

            return Image(uiImage: resized.image)
                .renderingMode(.original)
        } else {
            return Image(uiImage: uiImage)
                .renderingMode(.original)
        }
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

        MarkdownView(content: markdownString)
    }
}
