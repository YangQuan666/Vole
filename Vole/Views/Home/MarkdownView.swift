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
        var mentions: [String] = []
        var result = ""

        // 用正则拆分原始内容，保留 Markdown 图片/链接
        let pattern = #"(!\[.*?\]\(.*?\)|\[.*?\]\(.*?\))"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = content as NSString
        var last = 0
        
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: ns.length))
        
        for match in matches {
            // 普通文本片段
            let rangeBefore = NSRange(location: last, length: match.range.location - last)
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
        
        return (result, mentions)
    }

    // 处理普通文本片段：@mention + 图片 URL
    private func processTextFragment(_ text: String, _ mentions: inout [String]) -> String {
        var result = text
        let mentionPattern = #"(?<![\p{L}0-9_])@([\p{L}0-9_]+)(?![\p{L}0-9_])"#
        let imagePattern = #"https?://\S+\.(png|jpg|jpeg|gif|webp|bmp|tiff)"#
        
        // @mention
        if let mentionRegex = try? NSRegularExpression(pattern: mentionPattern) {
            let nsText = result as NSString
            let matches = mentionRegex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: result) {
                    let name = String(result[range])
                    mentions.append(name)
                    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: "[@\(name)](mention://\(encoded))")
                    }
                }
            }
        }
        
        // 图片 URL
        if let imageRegex = try? NSRegularExpression(pattern: imagePattern) {
            let nsText = result as NSString
            let matches = imageRegex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
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

            这是一个图片：![](https://developer.apple.com/assets/elements/icons/swift/swift-64x64_2x.png)
            
            问题如题。\r\n\r\n![image.png]( https://s2.loli.net/2025/09/03/zTV5PdNWXnbKF4w.png)\r\n\r\n网络上找到了一些方法，比如打开 [设置-隐私与安全性-本地网络] 中的权限，但是我发现这里面我的[几十个 Chrome](/t/1144946) 的权限都是打开状态。我试过关闭之后重新打开，但是无法解决问题。\r\n\r\nPS：感觉 Mac 越来越难用了，有点想换回 Windows 了……
            """

        MarkdownView(content: markdownString)
    }
}
