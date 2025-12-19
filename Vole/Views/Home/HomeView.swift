//
//  Home.swift
//  Vole
//
//  Created by 杨权 on 5/25/25.
//

import Kingfisher
import SwiftUI

struct HomeView: View {

    @State private var selection: Category = .latest
    @State private var data: [Category: [Topic]] = [:]
    @State private var showProfile = false
    @State private var isLoading = false

    @ObservedObject private var userManager = UserManager.shared
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        NavigationStack(path: $navManager.homePath) {
            Group {
                if let topics = data[selection], !topics.isEmpty {
                    List {
                        ForEach(topics) { topic in
                            TopicRow(topic: topic) {
                                if userManager.token != nil {
                                    navManager.homePath.append(
                                        Route.topicId(topic.id)
                                    )
                                } else {
                                    navManager.homePath.append(
                                        Route.topic(topic)
                                    )
                                }
                            }
                        }
                    }
                    .id(selection)
                    .refreshable {
                        await loadTopics(for: selection)
                    }
                } else if isLoading {
                    ZStack {
                        ProgressView("加载中…")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Button {
                            Task {
                                await loadTopics(for: selection)
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
                }
            }
            .navigationTitle("首页")
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
                ToolbarItem(placement: .principal) {
                    Picker("category", selection: $selection) {
                        ForEach(Category.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
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
        }
    }

    func loadTopics(for category: Category) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await category.action()
            await MainActor.run {
                data[category] = result ?? []
            }
        } catch {
            if error is CancellationError { return }
            print("出错了: \(error)")
        }
    }
}

enum Category: String, CaseIterable {
    case latest = "最新"
    case hot = "热门"

    var action: () async throws -> [Topic]? {
        switch self {
        case .hot:
            return { try await V2exAPI.shared.hotTopics() }
        case .latest:
            return { try await V2exAPI.shared.latestTopics() }
        }
    }
}

#Preview {
    HomeView()
}
