//
//  TopicView.swift
//  Vole
//
//  Created by 杨权 on 8/17/25.
//

import Kingfisher
import SwiftUI

struct TopicRow: View {
    let topic: Topic
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            topicAvatar

            VStack(alignment: .leading, spacing: 7) {
                topicMetaLine
                topicTitle

                if let summary = topicSummary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                topicFooter
                    .padding(.top, 1)
            }
        }
        .padding(14)
        .background(
            cardShape
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            cardShape
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
        .contentShape(cardShape)
        .onTapGesture {
            onTap()
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    @ViewBuilder
    private var topicAvatar: some View {
        if let avatarURL = topic.member?.getHighestQualityAvatar(),
            let url = URL(string: avatarURL)
        {
            KFImage(url)
                .placeholder {
                    Circle()
                        .fill(Color.gray.opacity(0.18))
                }
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(Circle())
        } else if topic.member == nil {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
        }
    }

    private var topicMetaLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                authorAndTime

                Spacer(minLength: 8)

                if let nodeTitle {
                    nodeBadge(nodeTitle)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                authorAndTime

                if let nodeTitle {
                    nodeBadge(nodeTitle)
                }
            }
        }
    }

    @ViewBuilder
    private var authorAndTime: some View {
        if let username = topic.member?.username, !username.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(username)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if topic.created != nil {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    topicCreatedTime
                }
            }
        } else if topic.created != nil {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                topicCreatedTime
            }
        }
    }

    @ViewBuilder
    private var topicCreatedTime: some View {
        if let created = topic.created {
            TimelineView(.everyMinute) { _ in
                Text(DateConverter.relativeTimeString(created))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var topicTitle: some View {
        if let title = topic.title, !title.isEmpty {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var topicFooter: some View {
        HStack(alignment: .center, spacing: 12) {
            if let lastReplyBy = topic.lastReplyBy, !lastReplyBy.isEmpty {
                Label(lastReplyBy, systemImage: "arrowshape.turn.up.left")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                if let stars = topic.stars, stars > 0 {
                    topicMetric(
                        stars,
                        systemImage: "star.fill",
                        color: .yellow
                    )
                }
                if let thanks = topic.thanks, thanks > 0 {
                    topicMetric(
                        thanks,
                        systemImage: "heart.fill",
                        color: .red
                    )
                }
                if let replies = topic.replies, replies > 0 {
                    topicMetric(
                        replies,
                        systemImage: "bubble.left"
                    )
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var nodeTitle: String? {
        guard let node = topic.node else { return nil }
        if let title = node.title, !title.isEmpty {
            return title
        }
        return node.name
    }

    private var topicSummary: String? {
        guard let content = topic.content else { return nil }

        let summary = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !summary.isEmpty else { return nil }
        return summary
    }

    private func nodeBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
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
        .font(.caption.weight(.medium))
    }
}

#Preview {
    //    let topic = ModelData().topics[0]
    //    TopicRow(topic: topic) {
    //
    //    }
}
