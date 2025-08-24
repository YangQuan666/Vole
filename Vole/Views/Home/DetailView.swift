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
    @Environment(\.openURL) private var openURL

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

                VStack(alignment: .leading) {
                    // 标题
                    if let title = topic.title {
                        Text(title)
                            .font(.title2)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                    Divider()
                    // 内容
                    if let content = topic.content {
                        MarkdownView(content: content)
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
                ShareLink(item: topic.url ?? "") {
                    Image(systemName: "square.and.arrow.up")
                }

                Menu {
                    Button("复制链接", systemImage: "link") {
                        UIPasteboard.general.string = topic.url
                    }
                    Button("在浏览器中打开", systemImage: "safari") {
                        if let url = URL(string: topic.url ?? "") {
                            openURL(url)
                        }
                    }
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
    DetailView(topic: ModelData().topics[0])
}
