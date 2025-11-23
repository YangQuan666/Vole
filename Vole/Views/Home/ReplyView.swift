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

struct ReplyRowView: View {
    @State private var showUserInfo = false
    @State private var selectedUser: Member?
    @Binding var path: NavigationPath
    let topic: Topic
    let reply: Reply
    let floor: Int
    var onMentionsChanged: (([String]) -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            if let avatarURL = reply.member.avatarNormal,
                let url = URL(string: avatarURL)
            {
                Button {
                    selectedUser = reply.member
                    showUserInfo = true
                } label: {
                    KFImage(url)
                        .placeholder {
                            Color.gray
                        }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
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
                    let username = reply.member.username
                    Text(username)
                        .font(.subheadline)
                        .bold()
                    if topic.member?.username == username {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(.yellow)
                            .imageScale(.small)
                    }
                    if let pro = reply.member.pro, pro > 0 {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .imageScale(.small)
                    }
                    Text(DateConverter.relativeTimeString(reply.created))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(floor+1)楼")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 评论内容
                MarkdownView(
                    content: reply.content,
                    onMentionsChanged: { mentions in
                        onMentionsChanged?(mentions)
                    },
                    onLinkAction: { action in
                        switch action {
                        case .mention(let username):
                            print("@\(username)")
                        case .topic(let id):
                            path.append(id)
                        default:
                            break
                        }
                    }
                )
            }
        }
        .sheet(item: $selectedUser) { member in
            MemberView(member: member)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
//    @Previewable @State var path = NavigationPath()
//    let topic: Topic = ModelData().topics[0]
//    let member = Member(id: 123, username: "hello")
//    let reply = Reply(id: 110, content: "帮 OP 重发图片。    ![image](https://i.imgur.com/61pfQZT.png) ![image](https://i.imgur.com/4WJyF6w.png) ![image](https://i.imgur.com/KEBNsVW.png)", contentRendered: "", created: 1, member: member)
//    ReplyRowView(path: $path,topic: topic, reply: reply, floor: 1)
//    
}
