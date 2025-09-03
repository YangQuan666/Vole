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

                    // 其他链接
                    return .systemAction(url)
                }
            )
    }
    
    private func makeMarkdown(_ content: String) -> (String, [String]) {
        /// 正则匹配 @username
        let mentionPattern = #"(?<![\p{L}0-9_])@([\p{L}0-9_]+)(?![\p{L}0-9_])"#
        let imagePattern = #"https?://\S+\.(png|jpg|jpeg|gif|webp|bmp|tiff)"#
        
        guard let mentionRegex = try? NSRegularExpression(pattern: mentionPattern),
              let imageRegex = try? NSRegularExpression(pattern: imagePattern) else {
            return (content, [])
        }
        
        let ns = content as NSString
        var mentions: [String] = []
        var result = ""
        var last = 0
        
        /// 找出所有 @mention 和图片链接，按起始位置排序
        let mentionMatches = mentionRegex.matches(in: content, range: NSRange(location: 0, length: ns.length))
        let imageMatches = imageRegex.matches(in: content, range: NSRange(location: 0, length: ns.length))
        let allMatches = (mentionMatches.map { ($0.range.location, $0, true) } +
                          imageMatches.map { ($0.range.location, $0, false) })
            .sorted { $0.0 < $1.0 } // 按位置排序
        
        for (_, match, isMention) in allMatches {
            // 原文片段
            let before = ns.substring(with: NSRange(location: last, length: match.range.location - last))
            result += before
            
            let substring = ns.substring(with: match.range)
            if isMention {
                // mention
                let name = ns.substring(with: match.range(at: 1))
                mentions.append(name)
                let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
                result += "[@\(name)](mention://\(encoded))"
            } else {
                // 图片链接
                result += "![image](\(substring))"
            }
            
            last = match.range.location + match.range.length
        }
        
        // 尾部剩余
        result += ns.substring(from: last)
        return (result, mentions)
    }
}

struct KFInlineImageProvider: InlineImageProvider {
    func image(with url: URL, label: String) async throws -> Image {
        // 行内图常见做法：限制目标高度（点），等比下采样到这个高度
        let targetPointHeight: CGFloat = 100
        let scale = await UIScreen.main.scale
        let targetPixelSize = CGSize(
            width: targetPointHeight * scale,
            height: targetPointHeight * scale
        )
        let processor = DownsamplingImageProcessor(size: targetPixelSize)

        let result = try await KingfisherManager.shared.retrieveImage(
            with: url,
            options: [
                .processor(processor),
                .scaleFactor(scale),
                .cacheOriginalImage,
            ]
        )
        // 注意：这里必须返回 "Image" 本体，不能加修饰符
        return Image(uiImage: result.image).renderingMode(.original)
    }
}
#Preview {

    ScrollView {
        let markdownString = """
            ## Try MarkdownUI

            **MarkdownUI** is a native Markdown renderer for SwiftUI
            compatible with the
            [GitHub Flavored Markdown Spec](https://github.github.com/gfm/).

            You can quote text with a `>`.

            > Outside of a dog, a book is man's best friend. Inside of a
            > dog it's too dark to read.


            # Markdown + 链接预览 Demo

            普通文字内容测试。

            这是一个普通链接：[Apple 官网](https://www.apple.com)

            这是一个裸链接：https://developer.apple.com

            这是一个图片：![](https://developer.apple.com/assets/elements/icons/swift/swift-64x64_2x.png)
            """

        MarkdownView(content: markdownString)
    }
}
