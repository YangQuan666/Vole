//
//  ReplyView.swift
//  Vole
//
//  Created by 杨权 on 8/22/25.
//

import Kingfisher
import SwiftUI

@MainActor
class ReplyViewModel: ObservableObject {
    @Published var replies: [Reply]? = nil
    @Published var isLoading = false

    func load(topicId: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let replies = try await V2exAPI.shared.repliesAll(topicId: topicId)
            await MainActor.run {
                self.replies = replies
            }
        } catch {
            if (error as? URLError)?.code != .cancelled {
                print("真正的错误: \(error)")
            }
        }
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
    let floor: Int
    var onMentionsChanged: (([String]) -> Void)? = nil

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
                    Text(reply.member.username)
                        .font(.subheadline)
                        .bold()
                    Text(formattedTime(reply.created))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(floor+1)楼")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 评论内容
                MarkdownView(content: reply.content){ mentions in
                    onMentionsChanged?(mentions)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let reply: Reply =
        Reply(
            id: 1,
            content: "hello @121 @123 你好ok@456 thank you \r\n email yang@quan.com",
            contentRendered: "",
            created: 0,
            member: Member(id:123, username: "ok")
        )
    return ReplyRowView(reply: reply, floor: 1)
}
