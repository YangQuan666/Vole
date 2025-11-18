//
//  NotifyRowView.swift
//  Vole
//
//  Created by 杨权 on 11/18/25.
//

import SwiftUI
import SwiftSoup

struct NotifyRowView: View {
    let item: Notification
    let onTap: (Int) -> Void

    var body: some View {
        if let parsed = parseNotificationHTML(item.text ?? "") {
            VStack(alignment: .leading, spacing: 6) {
                if let title = parsed.topicTitle {
                    Text(title)
                        .font(.subheadline)
                }

                (Text(parsed.username)
                    .foregroundStyle(.tint)
                    .font(.headline)
                 + Text(parsed.action)
                    .font(.headline))

                if let payload = item.payload {
                    Text(payload)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())  // 👈 必须放在结构稳定的视图上
            .onTapGesture {
                if let topicId = parsed.topicId {
                    onTap(topicId)
                }
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
                if let match = url.split(separator: "/").last?.split(separator: "#").first,
                   let id = Int(match) {
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
                actionText = fullText   // 兜底
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
    //    NotifyRowView()
}
