//
//  NotifyRowView.swift
//  Vole
//
//  Created by 杨权 on 11/18/25.
//

import SwiftSoup
import SwiftUI

struct NotifyRowView: View {
    let item: Notification
    let onTap: (Int) -> Void

    private static let rowIconName = "bell.fill"

    @ObservedObject private var notifyManager = NotifyManager.shared

    private var parsedNotification: ParsedNotification? {
        parseNotificationHTML(item)
    }

    private var isRead: Bool {
        notifyManager.isRead(item.id)
    }

    var body: some View {
        if let parsedNotification {
            Button {
                guard let topicId = parsedNotification.topicId else { return }
                notifyManager.markRead(item.id)
                onTap(topicId)
            } label: {
                notificationCard(parsedNotification)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                if !isRead {
                    Button {
                        notifyManager.markRead(item.id)
                    } label: {
                        Label("已读", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }
        }
    }

    private func notificationCard(_ parsed: ParsedNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            notificationIcon(parsed)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let title = parsed.topicTitle, !title.isEmpty {
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        } else {
                            Text(parsed.username)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        HStack(spacing: 8) {
                            if parsed.topicTitle?.isEmpty == false {
                                actorLabel(parsed.username)
                            }

                            kindBadge(parsed)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 8) {
                        if let created = item.created {
                            RelativeTimeText(timestamp: created)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let payload = parsed.payload, !payload.isEmpty {
                    Text(payload)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor(for: parsed))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardBorderColor(for: parsed), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func cardBackgroundColor(for parsed: ParsedNotification) -> some ShapeStyle {
        if isRead {
            return AnyShapeStyle(Color(.secondarySystemBackground))
        }
        return AnyShapeStyle(parsed.kind.color.opacity(0.08))
    }

    private func cardBorderColor(for parsed: ParsedNotification) -> Color {
        if isRead {
            return Color.primary.opacity(0.05)
        }
        return parsed.kind.color.opacity(0.18)
    }

    private func kindBadge(_ parsed: ParsedNotification) -> some View {
        HStack(spacing: 4) {
            Image(systemName: parsed.kind.badgeIcon)
                .font(.caption2.weight(.bold))
                .imageScale(.small)

            Text(parsed.kind.badgeText)
                .font(.caption.weight(.semibold))
        }
            .foregroundStyle(parsed.kind.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(parsed.kind.color.opacity(0.12))
            )
    }

    private func actorLabel(_ username: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "person.fill")
                .font(.caption2.weight(.semibold))
                .imageScale(.small)

            Text("来自 \(username)")
                .font(.footnote)
        }
            .foregroundStyle(.secondary)
    }

    private func notificationIcon(_ parsed: ParsedNotification) -> some View {
        ZStack {
            Circle()
                .fill(parsed.kind.color.opacity(isRead ? 0.12 : 0.18))
                .frame(width: 40, height: 40)

            Image(systemName: Self.rowIconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(parsed.kind.color)
        }
    }

    private func parseNotificationHTML(_ item: Notification) -> ParsedNotification? {
        do {
            let doc = try SwiftSoup.parse(item.text ?? "")

            let firstA = try doc.select("a[href^=/member/]").first()
            let username = try firstA?.text() ?? "系统通知"

            let topicA = try doc.select("a.topic-link, a[href^=/t/]").last()
            let topicTitle = try topicA?.text()
            let topicURL = try topicA?.attr("href")

            var topicId: Int? = nil
            if let url = topicURL,
               let match = url.split(separator: "/").last?.split(separator: "#").first,
               let id = Int(match) {
                topicId = id
            }

            let kind = try NotificationKind(document: doc)
            var parsedPayload: String? = item.payload

            if kind == .tip {
                parsedPayload = nil

                if let payload = item.payload,
                   payload.hasPrefix("topic:"),
                   let id = Int(payload.dropFirst("topic:".count)) {
                    topicId = id
                }
            }

            return ParsedNotification(
                username: username,
                kind: kind,
                topicTitle: topicTitle,
                topicId: topicId,
                payload: parsedPayload
            )
        } catch {
            print("HTML 解析失败: \(error)")
            return nil
        }
    }
}

private struct ParsedNotification {
    let username: String
    let kind: NotificationKind
    let topicTitle: String?
    let topicId: Int?
    let payload: String?
}

enum NotificationKind: Equatable {
    case mention
    case reply
    case favorite
    case thanks
    case tip
    case notice

    init(document: SwiftSoup.Document) throws {
        try document.select("a").remove()
        self.init(text: try document.text())
    }

    init(text: String) {
        if text.contains("提到了你") {
            self = .mention
        } else if text.contains("回复了你") {
            self = .reply
        } else if text.contains("收藏") {
            self = .favorite
        } else if text.contains("感谢") {
            self = .thanks
        } else if text.contains("打赏") {
            self = .tip
        } else {
            self = .notice
        }
    }

    var badgeText: String {
        switch self {
        case .mention:
            "提到"
        case .reply:
            "回复"
        case .favorite:
            "收藏"
        case .thanks:
            "感谢"
        case .tip:
            "打赏"
        case .notice:
            "通知"
        }
    }

    var badgeIcon: String {
        switch self {
        case .mention:
            "at"
        case .reply:
            "bubble.left.and.bubble.right.fill"
        case .favorite:
            "star.fill"
        case .thanks:
            "heart.fill"
        case .tip:
            "dollarsign.circle.fill"
        case .notice:
            "message.fill"
        }
    }

    var color: Color {
        switch self {
        case .mention:
            .orange
        case .reply:
            .blue
        case .favorite, .tip:
            .yellow
        case .thanks:
            .red
        case .notice:
            .accentColor
        }
    }
}

#Preview {
    let notification = Notification(
        id: 1,
        memberID: 123,
        forMemberID: 456,
        text:
            "<a href=\"/member/tomyail\" target=\"_blank\"><strong>tomyail</strong></a> 在回复 <a href=\"/t/1163971#reply3\" class=\"topic-link\">摸鱼刷 Reddit 太累了？写了个 AI 总结工具，一键看精华</a> 时提到了你",
        payload:
            "@oligi 有查询频率限制，没有次数限制,显示有2000条通知没有一键已读，强迫症都犯了强迫症都犯了强迫症都犯了强迫症都犯了",
        payloadRendered: nil,
        created: 123123,
        member: nil
    )
    NotifyRowView(item: notification) { _ in }
}
