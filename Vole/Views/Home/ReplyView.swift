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

struct ReplyView: View {
    @ObservedObject var vm: ReplyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("评论")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)

            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if vm.replies == nil || vm.replies?.isEmpty == true {
                Divider()
                VStack(spacing: 4) {
                    Text("暂无评论，快来抢沙发吧~")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach((vm.replies ?? []).indices, id: \.self) { index in
                    Divider()
                    ReplyRowView(reply: vm.replies![index], floor: index)
                }
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
    let floor: Int

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
                    Text("\(floor+1)楼")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 评论内容
                Text(attributedContent(reply.content))
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 8)
    }

    func attributedContent(_ content: String) -> AttributedString {
        var attributed = AttributedString(content)

        // 判断是否以 @ 开头
        if content.first == "@",
            let range = content.range(
                of: #"^@\w+"#,
                options: .regularExpression
            )
        {
            let nsRange = NSRange(range, in: content)
            if let swiftRange = Range(nsRange, in: attributed) {
                attributed[swiftRange].foregroundColor = .accentColor
            }
        }

        return attributed
    }
}

#Preview {
    let mv = ReplyViewModel()
    ReplyView(vm: mv)
}
