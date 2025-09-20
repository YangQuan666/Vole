//
//  TopicView.swift
//  Vole
//
//  Created by 杨权 on 8/17/25.
//

import Kingfisher
import SwiftUI

let formatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full  // full: 一天前, short: 1d ago
    f.locale = Locale.autoupdatingCurrent
    return f
}()

struct TopicRow: View {
    let topic: Topic
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            // 头像 + 昵称
            HStack {
                if let avatarURL = topic.member?.avatarNormal,
                    let url = URL(string: avatarURL)
                {
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
                    Text(
                        formattedTime(created)
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
        .onTapGesture {
            onTap()
        }
        .padding()
        .cornerRadius(16)
        .frame(maxWidth: .infinity)
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = topic.url
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }) {
                Label("复制链接", systemImage: "link")
            }
            ShareLink(item: topic.url ?? "") {
                Label("分享", systemImage: "square.and.arrow.up")
            }
        }
    }
}

#Preview {
    let topic = ModelData().topics[0]
    TopicRow(topic: topic) {

    }
}
