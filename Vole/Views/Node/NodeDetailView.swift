//
//  NodeDetailView.swift
//  Vole
//
//  Created by 杨权 on 10/28/25.
//

import Kingfisher
import SwiftUI

struct NodeDetailView: View {
    let node: Node
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    // 头像
                    if let avatarURL = node.avatarLarge,
                        let url = URL(string: avatarURL)
                    {
                        KFImage(url)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 100, height: 100)
                            .padding(.top, 20)
                    }

                    // 名称 + 英文名
                    VStack(spacing: 4) {
                        Text(node.title ?? "")
                            .font(.title2)
                            .fontWeight(.semibold)

                        if !node.name.isEmpty {
                            Text(node.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 发帖 + 星标
                    HStack(spacing: 24) {
                        Label(
                            "\(node.topics ?? 0)",
                            systemImage: "list.bullet.rectangle.portrait"
                        )
                        .font(.subheadline)
                        Label("\(node.stars ?? 0)", systemImage: "star.fill")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                    }

                    // header 简介
                    if let header = node.header, !header.isEmpty {
                        Text(header)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // aliases 标签组
                    if let aliases = node.aliases, !aliases.isEmpty {
                        AliasesView(aliases: aliases)
                            .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("话题") {
                ForEach(0..<10) { i in
                    Text("示例帖子 \(i)")
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                let shareURL = node.url ?? ""
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                Menu {
                    Button("父节点", systemImage: "scale.3d") {
                        // parent 信息
//                        let parent = node.parentNodeName
                        // todo 获取父亲节点node信息，然后路由过去
                    }
                    Button("复制链接", systemImage: "link") {
                        UIPasteboard.general.string = shareURL
                        let generator =
                            UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                    Button("在浏览器中打开", systemImage: "safari") {
                        if let url = URL(string: shareURL) {
                            openURL(url)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Aliases 标签视图
struct AliasesView: View {
    let aliases: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(aliases, id: \.self) { alias in
                Text(alias)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

#Preview {
    let node = Node(
        id: nil,
        name: "other",
        title: "其他",
        url: "https://cdn.v2ex.com/navatar/c20a/d4d7/12_large.png?m=1751718333",
        topics: 555,
        footer: nil,
        header: nil,
        titleAlternative: nil,
        avatarMini: nil,
        avatarNormal: nil,
        avatarLarge: nil,
        stars: 44,
        aliases: nil,
        root: true,
        parentNodeName: nil
    )
    NodeDetailView(node: node)
}
