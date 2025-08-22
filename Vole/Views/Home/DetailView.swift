//
//  DetailView.swift
//  Vole
//
//  Created by 杨权 on 8/21/25.
//

import Kingfisher
import MarkdownUI
import SwiftUI

struct DetailView: View {
    @State var topic: Topic
    @State var replies: [Reply] = []
    @State private var isLoading: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: []) {
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

                VStack {
                    // 标题
                    if let title = topic.title {
                        Text(title)
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    Divider()
                    // 内容
                    if let content = topic.content {
                        Markdown(content)
                            .markdownTheme(.basic)
                    }
                }

                // 评论区
                ReplyView(replies: replies)
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
        // 下拉刷新
        .refreshable {
            await loadReplies()
        }
        .onAppear {
            Task {
                await loadReplies()
            }
        }
        .navigationTitle("帖子详情")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.secondarySystemBackground))
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    // 分享
                }) {
                    Image(systemName: "square.and.arrow.up")
                }

                Menu {
                    Button("复制链接") {}
                    Button("在浏览器中打开") {}
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // 加载评论
    func loadReplies() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await V2exAPI.shared.repliesAll(
                topicId: self.topic.id
            )
            replies = data ?? []
        } catch {
//            print("出错了: \(error)")
        }
    }
}

#Preview {
    DetailView(topic: ModelData().topics[5])
}
