//
//  ReplyView.swift
//  Vole
//
//  Created by 杨权 on 8/22/25.
//

import Kingfisher
import SwiftUI

struct ReplyView: View {
    let replies: [Reply]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("评论")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)

            ForEach(replies) { reply in
                ReplyRowView(reply: reply)
                Divider()
            }
        }
        .padding()
    }
}

// 时间格式化工具
func formattedTime(_ timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
}

struct ReplyRowView: View {
    let reply: Reply

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            if let avatarURL = reply.member.avatarNormal,
                let url = URL(string: avatarURL)
            {
                KFImage(url)
                    .placeholder {
                        Color.gray
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                // 头像占位
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                // 用户名 + 时间 + 楼层
                HStack {
                    Text(reply.member.username ?? "")
                        .font(.subheadline)
                        .bold()
                    Text(formattedTime(reply.created))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("1楼")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 评论内容
                Text(reply.content)  // TODO 如果是 HTML，可改成 NSAttributedString
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ReplyView(replies: [])
}
