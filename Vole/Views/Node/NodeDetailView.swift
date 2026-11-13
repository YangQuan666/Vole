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
    @State private var nodeLoadFailed = false

    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var blockManager = BlockManager.shared
    @StateObject private var favoriteNodeManager = FavoriteNodeManager.shared
    @StateObject private var nodeManager = NodeManager.shared
    @Environment(\.openURL) private var openURL
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            if let node = node {
                List {
                    nodeProfileHeader(node)
                        .listRowInsets(
                            EdgeInsets(
                                top: 14,
                                leading: 16,
                                bottom: 10,
                                trailing: 16
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    topicsSectionHeader(for: node)
                        .listRowInsets(
                            EdgeInsets(
                                top: 12,
                                leading: 16,
                                bottom: 2,
                                trailing: 16
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if !topics.isEmpty {
                        ForEach(blockManager.visible(topics)) { topic in
                            TopicRow(topic: topic) {
                                if userManager.token != nil {
                                    path.append(Route.topicId(topic.id))
                                } else {
                                    path.append(Route.topic(topic))
                                }
                            }
                            .onAppear {
                                if topic.id == blockManager.visible(topics).last?.id {
                                    Task { await loadNextPageIfNeeded() }
                                }
                            }
                            .listRowInsets(
                                EdgeInsets(
                                    top: 6,
                                    leading: 12,
                                    bottom: 6,
                                    trailing: 12
                                )
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    } else if isTopicLoading {
                        topicsStateRow(
                            systemImage: "doc.text",
                            title: "正在加载话题",
                            message: "正在获取这个节点下的最新内容。",
                            isLoading: true
                        )
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 16,
                                bottom: 0,
                                trailing: 16
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        topicsStateRow(
                            systemImage: "doc.text.magnifyingglass",
                            title: "暂无话题",
                            message: "这个节点暂时还没有可展示的内容",
                            isLoading: false
                        )
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 16,
                                bottom: 0,
                                trailing: 16
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    footerView
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 16,
                                bottom: 8,
                                trailing: 16
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .contentMargins(.top, 0, for: .scrollContent)
                .task(id: node.name) {
                    await loadTopicsIfNeeded(for: node.name)
                }
                .refreshable {
                    await refreshNodeAndTopics(for: node)
                }
            } else if let nodeName {
                if nodeLoadFailed {
                    NodeDetailStateView(
                        systemImage: "square.grid.2x2",
                        title: "节点加载失败",
                        message: "暂时无法获取 \(nodeName) 的节点信息。",
                        isLoading: false
                    ) {
                        Task { await loadNode(name: nodeName) }
                    }
                } else {
                    NodeDetailStateView(
                        systemImage: "square.grid.2x2",
                        title: "正在加载节点",
                        message: "正在获取 \(nodeName) 的节点信息。",
                        isLoading: true,
                        action: nil
                    )
                    .task {
                        await loadNode(name: nodeName)
                    }
                }
            } else {
                NodeDetailStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "节点获取失败",
                    message: "没有找到可展示的节点信息。",
                    isLoading: false,
                    action: nil
                )
            }
        }
        .toolbar {
            ToolbarItem {
                if let node {
                    Button {
                        favoriteNodeManager.toggleFavorite(node)
                    } label: {
                        Image(
                            systemName: favoriteNodeManager.isFavorite(node)
                                ? "checkmark"
                                : "plus"
                        )
                    }
                }
            }
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed)
            }
            ToolbarItem {
                Menu {
                    if let shareURL = node?.url, !shareURL.isEmpty {
                        ShareLink(item: shareURL) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    }

                    if let shareURL = node?.url, !shareURL.isEmpty {
                        Button("在浏览器中打开", systemImage: "safari") {
                            if let url = URL(string: shareURL) {
                                openURL(url)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func nodeProfileHeader(_ node: Node) -> some View {
        let description = parseHTML(node.header)

        return VStack(spacing: 16) {
            nodeIdentityHeader(node)

            if !description.isEmpty {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            nodeInfoStrip(node)
        }
        .frame(maxWidth: .infinity)
    }

    private func nodeIdentityHeader(_ node: Node) -> some View {
        VStack(spacing: 10) {
            nodeAvatar(node)

            VStack(spacing: 5) {
                Text(node.title ?? node.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !node.name.isEmpty {
                    Text(node.name)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func nodeInfoStrip(_ node: Node) -> some View {
        let metrics = nodeInfoMetrics(node)

        if !metrics.isEmpty {
            HStack(spacing: 0) {
                ForEach(metrics.indices, id: \.self) { index in
                    nodeInfoItem(metrics[index])

                    if index < metrics.count - 1 {
                        Divider()
                            .frame(height: 30)
                            .padding(.horizontal, 2)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func nodeInfoItem(_ metric: NodeProfileMetric) -> some View {
        if let route = metric.route {
            Button {
                path.append(route)
            } label: {
                nodeInfoItemContent(metric)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        } else {
            nodeInfoItemContent(metric)
        }
    }

    private func nodeInfoItemContent(_ metric: NodeProfileMetric) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: metric.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(metric.tint)

                Text(metric.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(metric.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func nodeInfoMetrics(_ node: Node) -> [NodeProfileMetric] {
        var metrics: [NodeProfileMetric] = []

        if let topics = node.topics {
            metrics.append(
                NodeProfileMetric(
                    value: topics.formattedCount,
                    label: "话题",
                    systemImage: "doc.text.fill",
                    tint: .blue,
                    route: nil
                )
            )
        }

        if let stars = node.stars {
            metrics.append(
                NodeProfileMetric(
                    value: stars.formattedCount,
                    label: "收藏",
                    systemImage: "star.fill",
                    tint: .yellow,
                    route: nil
                )
            )
        }

        if let parentNodeName = node.parentNodeName, !parentNodeName.isEmpty {
            let parentTitle =
                nodeManager.getNode(parentNodeName)?.title ?? parentNodeName
            metrics.append(
                NodeProfileMetric(
                    value: parentTitle,
                    label: "父节点",
                    systemImage: "folder.fill",
                    tint: .green,
                    route: parentNodeRoute(parentNodeName)
                )
            )
        }

        return metrics
    }

    private func parentNodeRoute(_ parentNodeName: String) -> Route {
        if let node = nodeManager.getNode(parentNodeName) {
            return Route.node(node)
        }
        return Route.nodeName(parentNodeName)
    }

    private struct NodeProfileMetric {
        let value: String
        let label: String
        let systemImage: String
        let tint: Color
        let route: Route?
    }

    private func topicsSectionHeader(for node: Node) -> some View {
        let count = node.topics ?? topics.count

        return HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text("话题")
                .font(.headline)
                .foregroundStyle(.primary)

            if count > 0 {
                Text(count.formattedCount)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
            }
        }
        .textCase(nil)
        .padding(.top, 4)
    }

    private func topicsStateRow(
        systemImage: String,
        title: String,
        message: String,
        isLoading: Bool
    ) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 48, height: 48)

                if isLoading {
                    ProgressView()
                        .controlSize(.regular)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func nodeAvatar(_ node: Node) -> some View {
        Group {
            if let avatarURL = node.getHighestQualityAvatar(),
                let url = URL(string: avatarURL)
            {
                KFImage(url)
                    .placeholder {
                        nodeAvatarPlaceholder(node)
                    }
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
            } else {
                nodeAvatarPlaceholder(node)
            }
        }
        .frame(width: 66, height: 66)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private func nodeAvatarPlaceholder(_ node: Node) -> some View {
        ZStack {
            Color.accentColor.opacity(0.08)
            Text(String((node.title ?? node.name).prefix(1)))
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
    }

    @ViewBuilder
    private var footerView: some View {
        if isTopicLoading && !topics.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text("加载更多话题")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .textCase(nil)
        } else if userManager.token == nil && !topics.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "lock")
                    .imageScale(.small)

                Text("未登录仅展示前20条内容")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .textCase(nil)
        }
    }

    func loadNode(name: String) async {
        guard !isNodeLoading else { return }
        isNodeLoading = true
        nodeLoadFailed = false
        defer { isNodeLoading = false }
        do {
            let response = try await V2exAPI().getNode(nodeName: name)
            if let r = response, r.success, let n = r.result {
                await MainActor.run {
                    self.node = n
                    self.nodeLoadFailed = false
                }
            } else {
                await MainActor.run {
                    self.nodeLoadFailed = true
                }
            }
        } catch {
            if error is CancellationError { return }
            print("出错了: \(error)")
            await MainActor.run {
                self.nodeLoadFailed = true
            }
        }
    }

    func loadTopicsIfNeeded(for name: String) async {
        guard topics.isEmpty else { return }
        await reloadTopics(for: name)
    }

    func refreshNodeAndTopics(for currentNode: Node) async {
        await refreshNodeInfo(for: currentNode)
        guard !Task.isCancelled else { return }
        await reloadTopics(for: currentNode.name)
    }

    func refreshNodeInfo(for currentNode: Node) async {
        do {
            guard let refreshedNode = try await V2exAPI.shared.nodesShow(
                name: currentNode.name
            ) else {
                return
            }
            let mergedNode = mergeNodeInfo(currentNode, refreshedNode)

            await MainActor.run {
                guard self.node?.name == currentNode.name else { return }
                self.node = mergedNode
            }
        } catch {
            if error is CancellationError { return }
            print("刷新节点信息失败: \(error)")
        }
    }

    private func mergeNodeInfo(_ currentNode: Node, _ refreshedNode: Node)
        -> Node
    {
        Node(
            id: refreshedNode.id ?? currentNode.id,
            name: refreshedNode.name.isEmpty ? currentNode.name : refreshedNode.name,
            title: refreshedNode.title ?? currentNode.title,
            url: refreshedNode.url ?? currentNode.url,
            topics: refreshedNode.topics ?? currentNode.topics,
            footer: refreshedNode.footer ?? currentNode.footer,
            header: refreshedNode.header ?? currentNode.header,
            headerText: refreshedNode.headerText
                ?? (refreshedNode.header == nil ? currentNode.headerText : nil),
            titleAlternative: refreshedNode.titleAlternative
                ?? currentNode.titleAlternative,
            avatar: refreshedNode.avatar ?? currentNode.avatar,
            avatarMini: refreshedNode.avatarMini ?? currentNode.avatarMini,
            avatarNormal: refreshedNode.avatarNormal ?? currentNode.avatarNormal,
            avatarLarge: refreshedNode.avatarLarge ?? currentNode.avatarLarge,
            stars: refreshedNode.stars ?? currentNode.stars,
            aliases: refreshedNode.aliases ?? currentNode.aliases,
            root: refreshedNode.root ?? currentNode.root,
            parentNodeName: refreshedNode.parentNodeName
                ?? currentNode.parentNodeName
        )
        .withResolvedHeaderText()
    }

    func reloadTopics(for name: String) async {
        if userManager.token != nil {
            await loadTopics(name: name, page: 1)
        } else {
            await loadTopicsV1(name: name)
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
                    self.topics = NodeTopicPagination.unique(t)
                    self.pagination = nil
                    self.currentPage = 1
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
                        self.topics = NodeTopicPagination.unique(t)
                    } else {
                        self.topics = NodeTopicPagination.appendingUnique(
                            t,
                            to: self.topics
                        )
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

enum NodeTopicPagination {
    static func unique(_ topics: [Topic]) -> [Topic] {
        appendingUnique(topics, to: [])
    }

    static func appendingUnique(_ page: [Topic], to topics: [Topic]) -> [Topic] {
        var knownIDs = Set<Int>()
        return (topics + page).filter { knownIDs.insert($0.id).inserted }
    }
}

private struct NodeDetailStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let isLoading: Bool
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 64, height: 64)

                if isLoading {
                    ProgressView()
                        .controlSize(.regular)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let action {
                Button(action: action) {
                    Text("重试")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
        headerText: nil,
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
