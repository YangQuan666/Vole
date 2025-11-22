//
//  NodeDetailView.swift
//  Vole
//
//  Created by 杨权 on 10/28/25.
//

import Kingfisher
import SwiftSoup
import SwiftUI

struct NodeDetailView: View {
    var nodeName: String? = nil
    @State var node: Node?
    @State private var topics: [Topic] = []
    @State private var pagination: Pagination? = nil
    @State private var currentPage = 1
    @State private var isLoading = false
    @Environment(\.openURL) private var openURL
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            if let node = node {
                List {
                    // 节点信息 Section
                    Section {
                        VStack(spacing: 16) {
                            // 头像
                            if let avatarURL = node.avatarLarge ?? node.avatar,
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
                                if let topics = node.topics, topics > 0 {
                                    HStack(spacing: 8) {
                                        Image(
                                            systemName: "append.page.fill"
                                        )
                                        .foregroundColor(.blue)
                                        Text("\(topics)")
                                    }
                                }
                                if let stars = node.stars, stars > 0 {
                                    HStack(spacing: 8) {
                                        Image(
                                            systemName: "star.fill"
                                        )
                                        .foregroundColor(.yellow)
                                        Text("\(stars)")
                                    }
                                }
                            }

                            // header 简介
                            let text = parseHTML(node.header)
                            if !text.isEmpty {
                                Text(text)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            // aliases 标签组
                            if let aliases = node.aliases, !aliases.isEmpty {
                                AliasesView(aliases: aliases)
                                    .padding(.top, 6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    Section("话题") {
                        if topics.isEmpty && isLoading {
                            // 初次加载动画
                            HStack {
                                Spacer()
                                ProgressView("加载中…")
                                Spacer()
                            }
                            .padding()
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(topics) { topic in
                                TopicRow(topic: topic) {
                                    path.append(topic.id)
                                }
                                .onAppear {
                                    if topic == topics.last {
                                        Task { await loadNextPageIfNeeded() }
                                    }
                                }
                            }

                            // 底部加载更多动画
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView("加载中…")
                                    Spacer()
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
                .task {
                    await loadTopics(name: node.name, page: 1)
                }
                .refreshable {
                    await loadTopics(name: node.name, page: 1)
                }
            } else if let nodeName {
                // 还没有加载到 topic
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await loadNode(name: nodeName)
                    }
            }
        }
        .navigationDestination(for: Int.self) { topicId in
            DetailView(topicId: topicId, path: $path)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                let shareURL = node?.url ?? ""
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                Menu {
                    Button("父节点", systemImage: "scale.3d") {
                        if let node, let parentNodeName = node.parentNodeName {
                            path.append(Route.nodeName(parentNodeName))
                        }
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
    }

    func loadNode(name: String) async {
        do {
            let response = try await V2exAPI().getNode(nodeName: name)
            if let r = response, r.success, let n = r.result {
                await MainActor.run {
                    self.node = n
                }
            }
        } catch {
            if error is CancellationError { return }
            print("出错了: \(error)")
        }
    }

    // 分页加载话题
    func loadTopics(name: String, page: Int) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await V2exAPI().topics(
                nodeName: name,
                page: page
            )
            if let r = response, r.success, let t = r.result {
                await MainActor.run {
                    if page == 1 {
                        self.topics = t
                    } else {
                        self.topics.append(contentsOf: t)
                    }
                    self.pagination = r.pagination
                    self.currentPage = page
                }
            }
        } catch {
            if error is CancellationError { return }
            print("出错了: \(error)")
        }
    }

    // 分页加载逻辑
    func loadNextPageIfNeeded() async {
        guard !isLoading else { return }
        guard let pagination = pagination else { return }
        guard currentPage < pagination.pages else { return }

        if let node {
            await loadTopics(name: node.name, page: currentPage + 1)
        }
    }

    private func parseHTML(_ html: String?) -> String {
        guard let content = html else { return "" }
        do {
            let doc = try SwiftSoup.parse(content)
            let fullText = try doc.text()
            return fullText
        } catch {
            print("HTML 解析失败: \(error)")
            return ""
        }
    }
}

// liases 标签视图
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
    @Previewable @State var path = NavigationPath()
    let node = Node(
        id: nil,
        name: "other",
        title: "其他",
        url: "https://cdn.v2ex.com/navatar/c20a/d4d7/12_large.png?m=1751718333",
        topics: 555,
        footer: nil,
        header: nil,
        titleAlternative: nil,
        avatar: nil,
        avatarMini: nil,
        avatarNormal: nil,
        avatarLarge: nil,
        stars: 44,
        aliases: nil,
        root: true,
        parentNodeName: nil
    )
    NodeDetailView(node: node, path: $path)
}
