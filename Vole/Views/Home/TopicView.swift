//
//  TopicView.swift
//  Vole
//
//  Created by 杨权 on 8/17/25.
//

import SwiftUI

struct TopicView: View {
    var body: some View {
        Text( /*@START_MENU_TOKEN@*/"Hello, World!" /*@END_MENU_TOKEN@*/)
    }
}

let formatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full  // full: 一天前, short: 1d ago
    f.locale = Locale.current
    return f
}()

struct TopicRow: View {
    let topic: Topic
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 头像 + 昵称
                HStack {
                    if let avatarURL = topic.member?.avatarNormal,
                        let url = URL(string: avatarURL)
                    {
                        AsyncImage(url: url) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(.circle)
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 24, height: 24)
                    }

                    Text(topic.member?.username ?? "未知用户")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Spacer()
                }

                // 标题
                if let title = topic.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                // 内容
                if let content = topic.content {
                    Text(content)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                // 节点+发布时间 + 评论数量
                HStack {
                    Text(topic.node?.title ?? "")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                    
                    Spacer()
                    if let created = topic.created {
                        let date = Date(
                            timeIntervalSince1970: TimeInterval(created)
                        )
                        // 创建 formatter 并设置短格式
                        let formatter = RelativeDateTimeFormatter()
                        Text(
                            formatter.localizedString(
                                for: date,
                                relativeTo: Date(),
                            )
                        )
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    if let replies = topic.replies {
                        HStack(spacing: 4) {  // 图标和文字间距
                            Image(systemName: "ellipsis.bubble")
                                .foregroundColor(.gray)  // 图标颜色
                            Text("\(replies)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }

            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
#Preview {
    HomeView()
}
