//
//  SearchRowView.swift
//  Vole
//
//  Created by 杨权 on 11/24/25.
//

import Kingfisher
import SwiftSoup
import SwiftUI

struct SearchRowView: View {
    private struct HighlightSegment {
        let text: String
        let isHighlighted: Bool
    }

    let result: SoV2exHit
    let onTap: () -> Void

    @StateObject private var nodeManager = NodeManager.shared

    private var topicURL: String? {
        SiteConfiguration.makeSiteURL(from: "/t/\(result.source.id)")?
            .absoluteString
    }

    private var nodeTitle: String {
        nodeManager.getNode(result.source.node)?.title ?? "\(result.source.node)"
    }

    private var highlightSnippet: String? {
        result.highlight?.content?.first
            ?? result.highlight?.postscriptContent?.first
            ?? result.highlight?.replyContent?.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let avatarURL = result.source.memberAvatar {
                    avatarView(avatarURL)
                }

                Text(result.source.member)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .bold()

                Spacer()

                Text(nodeTitle)
                    .font(.callout)
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                        .fill(Color.accentColor.opacity(0.15))
                    )
            }

            highlightedText(
                from: result.highlight?.title?.first,
                fallback: result.source.title,
                font: .headline,
                defaultColor: .primary
            )
            .lineLimit(2)

            highlightedText(
                from: highlightSnippet,
                fallback: result.source.content,
                font: .body,
                defaultColor: .secondary
            )
            .lineLimit(3)

            HStack {
                if let created = DateConverter.date(
                    isoDateString: result.source.created
                ) {
                    RelativeTimeText(date: created)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                topicMetric(result.source.replies, systemImage: "ellipsis.bubble")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    @ViewBuilder
    private func avatarView(_ avatarURL: String) -> some View {
        if let url = URL(string: avatarURL) {
            KFImage(url)
                .placeholder {
                    Color.gray
                }
                .resizable()
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray)
                .frame(width: 24, height: 24)
        }
    }

    private func topicMetric(
        _ value: Int,
        systemImage: String,
        color: Color = .secondary
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(value.formattedCount)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func highlightedText(
        from html: String?,
        fallback: String,
        font: Font,
        defaultColor: Color
    ) -> Text {
        let segments = highlightSegments(from: html)
        guard !segments.isEmpty else {
            return Text(fallback).font(font).foregroundColor(defaultColor)
        }

        let text = segments.reduce(Text("")) { partial, segment in
            partial + segmentText(segment, defaultColor: defaultColor)
        }
        return text.font(font)
    }

    private func segmentText(
        _ segment: HighlightSegment,
        defaultColor: Color
    ) -> Text {
        let text = Text(segment.text)
        if segment.isHighlighted {
            return text.foregroundColor(.accentColor)
        }
        return text.foregroundColor(defaultColor)
    }

    private func highlightSegments(from html: String?) -> [HighlightSegment] {
        guard let html, !html.isEmpty else { return [] }

        do {
            let document = try SwiftSoup.parseBodyFragment(html)
            guard let body = document.body() else { return [] }

            var segments: [HighlightSegment] = []
            for child in body.getChildNodes() {
                collectHighlightSegments(
                    from: child,
                    isHighlighted: false,
                    segments: &segments
                )
            }
            return segments
        } catch {
            let plainText = decodeHTMLText(html)
            guard !plainText.isEmpty else { return [] }
            return [HighlightSegment(text: plainText, isHighlighted: false)]
        }
    }

    private func collectHighlightSegments(
        from node: SwiftSoup.Node,
        isHighlighted: Bool,
        segments: inout [HighlightSegment]
    ) {
        if let textNode = node as? SwiftSoup.TextNode {
            appendSegment(
                textNode.getWholeText(),
                isHighlighted: isHighlighted,
                segments: &segments
            )
            return
        }

        guard let element = node as? SwiftSoup.Element else { return }

        let childIsHighlighted = isHighlighted || element.tagNameNormal() == "em"
        for child in element.getChildNodes() {
            collectHighlightSegments(
                from: child,
                isHighlighted: childIsHighlighted,
                segments: &segments
            )
        }
    }

    private func appendSegment(
        _ text: String,
        isHighlighted: Bool,
        segments: inout [HighlightSegment]
    ) {
        guard !text.isEmpty else { return }

        if let last = segments.last, last.isHighlighted == isHighlighted {
            segments[segments.count - 1] = HighlightSegment(
                text: last.text + text,
                isHighlighted: isHighlighted
            )
            return
        }

        segments.append(
            HighlightSegment(text: text, isHighlighted: isHighlighted)
        )
    }

    private func decodeHTMLText(_ html: String) -> String {
        guard !html.isEmpty else { return "" }

        do {
            return try SwiftSoup.parseBodyFragment(html).text()
        } catch {
            return html
        }
    }
}

#Preview {
    let mockResult = SoV2exHit(
        source: SoV2exTopic(
            id: 100000,
            title: "请教一个关于 Swift 结构化并发的问题",
            content: "最近在尝试使用 Actor 隔离状态，但在跨 Actor 调用时遇到了死锁问题，有大佬能提供一些调试思路吗？",
            member: "Swift_Coder",
            created: "2025-11-24T09:00:00Z",
            replies: 12,
            node: 56
        ),
        highlight: SoV2exHighlight(
            title: ["请教一个关于 <em>Swift</em> 结构化并发的问题"],
            content: ["最近在尝试使用 Actor 隔离状态，但在跨 Actor 调用时遇到了死锁问题，有大佬能提供一些调试 <em>Swift</em> 思路吗？"],
            postscriptContent: nil,
            replyContent: nil
        ),
        id: "100000"
    )

    SearchRowView(result: mockResult) {}
}
