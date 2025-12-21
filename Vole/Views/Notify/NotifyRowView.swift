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
    @ObservedObject private var notifyManager = NotifyManager.shared

    var body: some View {
        if let parsed = parseNotificationHTML(item.text ?? "") {
            HStack {
                Image(systemName: parsed.icon)
                    .foregroundStyle(parsed.color)
                VStack(alignment: .leading, spacing: 6) {
                    if let title = parsed.topicTitle {
                        HStack {
                            Text(title)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    (Text(parsed.username).foregroundColor(.accentColor).font(
                        .headline
                    )
                        + Text(parsed.action).font(.headline))

                    if let payload = item.payload {
                        Text(payload)
                            .font(.body)
                            .lineLimit(3)
                    }
                    if let created = item.created {
                        TimelineView(.everyMinute) { _ in
                            Text(DateConverter.relativeTimeString(created))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                notifyManager.isRead(item.id)
                    ? Color.clear : Color.accentColor.opacity(0.2)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if let topicId = parsed.topicId {
                    notifyManager.markRead(item.id)
                    onTap(topicId)
                }
            }
            .swipeActions(edge: .trailing) {
                Button {
                    notifyManager.markRead(item.id)
                } label: {
                    Label("已读", systemImage: "checkmark")
                }
                .tint(.green)
            }
        }
    }

    private func parseNotificationHTML(_ html: String) -> ParsedNotification? {
        do {
            let doc = try SwiftSoup.parse(html)

            // 1️⃣ 用户名
            let firstA = try doc.select("a[href^=/member/]").first()
            let username = try firstA?.text() ?? ""

            // 2️⃣ 找文章链接（/t/xxxx）
            let topicA = try doc.select("a.topic-link, a[href^=/t/]").last()
            let topicTitle = try topicA?.text()
            let topicURL = try topicA?.attr("href")

            // 2.1️⃣ 解析 topicId：/t/776391#reply0 -> 776391
            var topicId: Int? = nil
            if let url = topicURL {
                if let match = url.split(separator: "/").last?.split(
                    separator: "#"
                ).first,
                    let id = Int(match)
                {
                    topicId = id
                }
            }

            // 3️⃣ action 文本判断（不用替换、直接匹配关键词）
            let fullText = try doc.text()
            var actionText = ""
            var icon = "message.fill"
            var color: Color = .accentColor

            if fullText.contains("提到了你") {
                actionText = "提到了你"
                icon = "at"
                color = .orange
            } else if fullText.contains("回复了你") {
                actionText = "回复了你"
                icon = "bubble.left.and.bubble.right.fill"
                color = .blue
            } else if fullText.contains("收藏") {
                actionText = "收藏了你发布的主题"
                icon = "star.fill"
                color = .yellow
            } else if fullText.contains("感谢") {
                actionText = "感谢了你发布的主题"
                icon = "heart.fill"
                color = .red
            } else {
                actionText = fullText  // 兜底
            }

            return ParsedNotification(
                username: username,
                action: actionText,
                icon: icon,
                color: color,
                topicTitle: topicTitle,
                topicId: topicId
            )

        } catch {
            print("HTML 解析失败: \(error)")
            return nil
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
    NotifyRowView(item: notification) { topicId in

    }
}
