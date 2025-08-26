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
    @Environment(\.openURL) private var openURL
    @StateObject private var replyVM = ReplyViewModel()

    var body: some View {
        List {
            // 帖子详情部分
            Section {
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
                    if let node = topic.node,
                        let url = URL(string: node.avatarNormal ?? ""),
                        let title = node.title
                    {
                        KFImage(url)
                            .placeholder {
                                Color.gray
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        Text(title)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                .listRowSeparator(.hidden)

                VStack(alignment: .leading) {
                    // 标题
                    if let title = topic.title {
                        Text(title)
                            .font(.title2)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                    // 内容
                    if let content = topic.content, !content.isEmpty {
                        Divider()
                        MarkdownView(content: content)
                    }
                }
                .listRowSeparator(.hidden)
            }

            // 评论区
            Section(header: Text("评论").font(.headline)) {
                if replyVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .listRowSeparator(.hidden)
                } else if replyVM.replies?.isEmpty ?? true {
                    Text("暂无评论，快来抢沙发吧~")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(replyVM.replies!.indices, id: \.self) { index in
                        ReplyRowView(
                            reply: replyVM.replies![index],
                            floor: index
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                UIPasteboard.general.string =
                                    replyVM.replies![index].content

                                let generator =
                                    UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            .tint(.accentColor)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("帖子详情")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await replyVM.load(topicId: topic.id)
        }
        .task(id: topic.id) {
            if replyVM.replies == nil {
                await replyVM.load(topicId: topic.id)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ShareLink(item: topic.url ?? "") {
                    Image(systemName: "square.and.arrow.up")
                }
                Menu {
                    Button("复制链接", systemImage: "link") {
                        UIPasteboard.general.string = topic.url
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
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
}
#Preview {
    DetailView(topic: ModelData().topics[0])
}
