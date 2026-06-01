//
//  Home.swift
//  Vole
//
//  Created by 杨权 on 5/25/25.
//

import Kingfisher
import SwiftUI

struct HomeView: View {

    @State private var selection: HomeFeed = .latest
    @State private var data: [HomeFeed: [Topic]] = [:]
    @State private var showProfile = false
    @State private var loadingFeeds: Set<HomeFeed> = []

    @ObservedObject private var userManager = UserManager.shared
    @StateObject private var collectionManager = NodeCollectionManager.shared
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        NavigationStack(path: $navManager.homePath) {
            ZStack {
                ForEach(availableFeeds) { feed in
                    HomeFeedPage(
                        topics: data[feed],
                        isLoading: loadingFeeds.contains(feed),
                        isSelected: selection == feed,
                        onRefresh: {
                            await loadTopics(for: feed)
                        },
                        onRetry: {
                            await loadTopics(for: feed)
                        },
                        onSelectTopic: { topic in
                            openTopic(topic)
                        }
                    )
                    .opacity(selection == feed ? 1 : 0)
                    .allowsHitTesting(selection == feed)
                    .accessibilityHidden(selection != feed)
                    .zIndex(selection == feed ? 1 : 0)
                }
            }
            .navigationTitle("主页")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .topicId(let topicId):
                    DetailView(topicId: topicId, path: $navManager.homePath)
                case .topic(let topic):
                    DetailView(
                        topicId: nil,
                        topic: topic,
                        path: $navManager.homePath
                    )
                case .node(let node):
                    NodeDetailView(node: node, path: $navManager.homePath)
                case .nodeName(let nodeName):
                    NodeDetailView(
                        nodeName: nodeName,
                        path: $navManager.nodePath
                    )
                default:
                    EmptyView()
                }
            }
            .toolbar {
                let picker = Picker("category", selection: $selection) {
                    ForEach(HomeFeed.builtInFeeds) { item in
                        Text(item.title).tag(item)
                    }
                    ForEach(collectionManager.customCollections) {
                        collection in
                        Text(collection.name).tag(HomeFeed.collection(collection.id))
                    }
                }
                .pickerStyle(.segmented)
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .principal) {
                        picker
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        picker
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    AvatarView {
                        showProfile = true
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .task(id: selection) {
                if data[selection] == nil || data[selection]?.isEmpty == true {
                    await loadTopics(for: selection)
                }
            }
            .onChange(of: collectionManager.customCollections) { _, value in
                data = data.filter { key, _ in
                    if case .collection = key { return false }
                    return true
                }

                guard case .collection(let id) = selection else { return }
                if !value.contains(where: { $0.id == id }) {
                    selection = .latest
                } else {
                    Task {
                        await loadTopics(for: selection)
                    }
                }
            }
        }
    }

    private var availableFeeds: [HomeFeed] {
        HomeFeed.builtInFeeds
            + collectionManager.customCollections.map {
                HomeFeed.collection($0.id)
            }
    }

    func loadTopics(for feed: HomeFeed) async {
        guard !loadingFeeds.contains(feed) else { return }
        guard let action = action(for: feed) else {
            selection = .latest
            return
        }
        loadingFeeds.insert(feed)
        defer { loadingFeeds.remove(feed) }
        do {
            let result = try await action()
            await MainActor.run {
                data[feed] = result ?? []
            }
        } catch {
            if error is CancellationError { return }
            print("出错了: \(error)")
        }
    }

    private func openTopic(_ topic: Topic) {
        if userManager.token != nil {
            navManager.homePath.append(Route.topicId(topic.id))
        } else {
            navManager.homePath.append(Route.topic(topic))
        }
    }

    private func action(for feed: HomeFeed) -> (() async throws -> [Topic]?)? {
        switch feed {
        case .hot:
            return { try await V2exAPI.shared.hotTopics() }
        case .latest:
            return { try await V2exAPI.shared.latestTopics() }
        case .collection(let id):
            guard let collection = collectionManager.customCollection(id: id)
            else { return nil }
            return { try await loadCollectionTopics(collection) }
        }
    }

    private func loadCollectionTopics(_ collection: NodeCollection) async throws
        -> [Topic]
    {
        await withTaskGroup(of: [Topic].self) { group in
            for name in collection.nodeNames {
                group.addTask {
                    do {
                        let topics = try await V2exAPI.shared.topics(
                            nodeName: name
                        ) ?? []
                        return topics.map { topic in
                            var topic = topic
                            if topic.node == nil {
                                topic.node = Node.createVirtual(name: name)
                            }
                            return topic
                        }
                    } catch {
                        print("加载失败：\(name)", error)
                        return []
                    }
                }
            }

            var all: [Topic] = []
            for await list in group {
                all.append(contentsOf: list)
            }
            return all.sorted { ($0.created ?? 0) > ($1.created ?? 0) }
        }
    }
}

private struct HomeFeedPage: View {
    let topics: [Topic]?
    let isLoading: Bool
    let isSelected: Bool
    let onRefresh: () async -> Void
    let onRetry: () async -> Void
    let onSelectTopic: (Topic) -> Void

    @State private var scrollPosition: Int?

    var body: some View {
        Group {
            if let topics, !topics.isEmpty {
                List {
                    ForEach(topics) { topic in
                        TopicRow(topic: topic) {
                            onSelectTopic(topic)
                        }
                    }
                }
                .scrollPosition(id: $scrollPosition)
                .refreshable {
                    await onRefresh()
                }
            } else if isLoading {
                ZStack {
                    ProgressView("加载中…")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSelected {
                VStack {
                    Button {
                        Task {
                            await onRetry()
                        }
                    } label: {
                        Text("点击重试")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
            } else {
                Color.clear
            }
        }
    }
}

enum HomeFeed: Hashable, Identifiable {
    case latest
    case hot
    case collection(UUID)

    static let builtInFeeds: [HomeFeed] = [.latest, .hot]

    var id: String {
        switch self {
        case .latest:
            return "latest"
        case .hot:
            return "hot"
        case .collection(let id):
            return id.uuidString
        }
    }

    var title: String {
        switch self {
        case .latest:
            return "最新"
        case .hot:
            return "热门"
        case .collection:
            return ""
        }
    }
}

#Preview {
    HomeView()
}
