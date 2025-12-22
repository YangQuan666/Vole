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
    @State private var isNodeLoading = false
    @State private var isTopicLoading = false

    @ObservedObject private var userManager = UserManager.shared
    @StateObject private var nodeManager = NodeManager.shared
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

                    Section(header: Text("话题"), footer: footerView) {
                        if !topics.isEmpty {
                            ForEach(topics) { topic in
                                TopicRow(topic: topic) {
                                    if userManager.token != nil {
                                        path.append(Route.topicId(topic.id))
                                    } else {
                                        path.append(Route.topic(topic))
                                    }
                                }
                                .onAppear {
                                    if topic == topics.last {
                                        Task { await loadNextPageIfNeeded() }
                                    }
                                }
                            }
                        }
                    }
                }
                .task {
                    if userManager.token != nil {
                        await loadTopics(name: node.name, page: 1)
                    } else {
                        await loadTopicsV1(name: node.name)
                    }
                }
                .refreshable {
                    if userManager.token != nil {
                        await loadTopics(name: node.name, page: 1)
                    } else {
                        await loadTopicsV1(name: node.name)
                    }
                }
            } else if let nodeName, isNodeLoading {
                // 还没有加载到 topic
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await loadNode(name: nodeName)
                    }
            } else {
                VStack {
                    Text("\(nodeName ?? "")节点获取失败")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .toolbar {
            ToolbarItem {
                let shareURL = node?.url ?? ""
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed)
            }
            ToolbarItem {
                let shareURL = node?.url ?? ""
                Menu {
                    if let node, let parentNodeName = node.parentNodeName,
                        let n = nodeManager.getNode(parentNodeName)
                    {
                        Button("父节点", systemImage: "scale.3d") {
                            path.append(Route.node(n))
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

    @ViewBuilder
    private var footerView: some View {
        // 底部加载更多动画
        if isTopicLoading {
            VStack {
                ProgressView("加载中…")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowSeparator(.hidden)
        } else if userManager.token == nil {
            VStack {
                Text("未登录仅展示前20条内容")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    func loadNode(name: String) async {
        guard !isNodeLoading else { return }
        isNodeLoading = true
        defer { isNodeLoading = false }
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

    // 分页加载话题V1
    func loadTopicsV1(name: String) async {
        guard !isTopicLoading else { return }
        isTopicLoading = true
        defer { isTopicLoading = false }

        do {
            let response = try await V2exAPI().topics(
                nodeName: name
            )
            if let t = response {
                await MainActor.run {
                    self.topics = t
                }
            }
        } catch {
            if error is CancellationError { return }
            print("出错了: \(error)")
        }
    }

    // 分页加载话题V2
    func loadTopics(name: String, page: Int) async {
        guard !isTopicLoading else { return }
        isTopicLoading = true
        defer { isTopicLoading = false }

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
        guard !isTopicLoading else { return }
        guard let pagination = pagination else { return }
        guard currentPage < pagination.pages else { return }
        guard userManager.token != nil else { return }

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
                    .background(Color.secondary.opacity(0.15))
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
