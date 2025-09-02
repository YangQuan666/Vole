//
//  MarkdownView.swift
//  Vole
//
//  Created by 杨权 on 8/23/25.
//

import Kingfisher
import MarkdownUI
import SwiftUI

struct MarkdownView: View {
    @State var content: String
    @State private var isRendering = true
    var onMentionsChanged: (([String]) -> Void)?
    var onTapMention: ((String) -> Void)?   // 可选：点击 @mention 的回调


    var body: some View {
        let (md, mentions) = makeMarkdownFromMentions(content)

        Markdown(md)
            .markdownInlineImageProvider(KFInlineImageProvider())
            .textSelection(.enabled)  // 开启文本选中
            .markdownTheme(.basic)
            .markdownTextStyle(\.link) {
                ForegroundColor(.accentColor)
                FontWeight(.semibold)
            }
            // 把 mention 列表回调给外部（用并发保证主线程、避免构建期改状态）
            .task(id: content) { @MainActor in
                onMentionsChanged?(mentions)
            }
            // 拦截自定义 scheme：mention://<username>
            .environment(
                \.openURL,
                OpenURLAction { url in
                    if url.scheme == "mention" {
                        let name = url.host ?? url.lastPathComponent
                        onTapMention?(name)
                        return .handled
                    }
                    return .systemAction(url)
                }
            )
    }
    
    /// 把 @username 转成 [@username](mention://username) 并收集 mentions
    private func makeMarkdownFromMentions(_ content: String) -> (String, [String]) {
        // 避免匹配邮箱等：前一位不是字母数字下划线，后一位也不是
        let pattern = #"(?<![\p{L}0-9_])@([\p{L}0-9_]+)(?![\p{L}0-9_])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return (content, []) }

        let ns = content as NSString
        var mentions: [String] = []
        var result = ""
        var last = 0

        let matches = regex.matches(in: content, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            // 原文片段
            let before = ns.substring(with: NSRange(location: last, length: m.range.location - last))
            result += before

            // 用户名
            let name = ns.substring(with: m.range(at: 1))
            mentions.append(name)

            // 为避免非 ASCII 字符出问题，做个编码
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name

            // 替换成自定义 scheme 的 Markdown 链接
            result += "[@\(name)](mention://\(encoded))"

            last = m.range.location + m.range.length
        }

        // 末尾剩余片段
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
