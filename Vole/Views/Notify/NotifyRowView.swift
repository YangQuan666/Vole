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
        let parsed = parseNotificationHTML(item.text ?? "")

        VStack(alignment: .leading, spacing: 6) {

            if let title = parsed?.topicTitle {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(
                        notifyManager.isRead(item.id) ? .secondary : .primary
                    )
            }

            if let p = parsed {
                (Text(p.username).foregroundColor(.accentColor).font(.headline)
                    + Text(p.action).font(.headline))
                    .foregroundStyle(
                        notifyManager.isRead(item.id) ? .secondary : .primary
                    )
            }

            if let payload = item.payload {
                Text(payload)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if let created = item.created {
                TimelineView(.everyMinute) { _ in
                    Text(DateConverter.relativeTimeString(created))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            if let topicId = parsed?.topicId {
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

            if fullText.contains("提到了你") {
                actionText = "提到了你"
            } else if fullText.contains("回复了你") {
                actionText = "回复了你"
            } else if fullText.contains("收藏") {
                actionText = "收藏了你发布的主题"
            } else {
                actionText = fullText  // 兜底
            }

            return ParsedNotification(
                username: username,
                action: actionText,
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
        payload: "@oligi 有查询频率限制，没有次数限制",
        payloadRendered: nil,
        created: 123123,
        member: nil
    )
    NotifyRowView(item: notification) { topicId in

    }
}
