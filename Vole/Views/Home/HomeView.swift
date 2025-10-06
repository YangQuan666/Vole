//
//  Home.swift
//  Vole
//
//  Created by 杨权 on 5/25/25.
//

import Kingfisher
import SwiftUI

struct HomeView: View {

    @State private var path = NavigationPath()
    @State private var selection: Category = .latest
    @State private var data: [Category: [Topic]] = [:]
    @State private var showProfile = false

    @ObservedObject private var userManager = UserManager.shared

    func loadTopics(for category: Category) async {
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

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let topics = data[selection], !topics.isEmpty {
                    List {
                        ForEach(topics) { topic in
                            TopicRow(topic: topic) {
                                path.append(
                                    TopicRoute(id: topic.id, topic: topic)
                                )
                            }
                        }
                    }
                    .id(selection)
                    .refreshable {
                        await loadTopics(for: selection)
                    }
                } else {
                    VStack {
                        Spacer()
                        ProgressView("加载中…")
                            .progressViewStyle(.circular)
                            .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle("首页")
            .navigationDestination(for: TopicRoute.self) { route in
                DetailView(topicId: route.id, topic: route.topic, path: $path)
            }
            .toolbar {
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .principal) {
                        Picker("category", selection: $selection) {
                            ForEach(Category.allCases, id: \.self) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarSpacer(.fixed)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showProfile = true
                        } label: {
                            if let memeber = userManager.currentMember,
                                let avatarURL =
                                    memeber.getHighestQualityAvatar(),
                                let url = URL(string: avatarURL)
                            {
                                KFImage(url)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .automatic) {
                        Picker("category", selection: $selection) {
                            ForEach(Category.allCases, id: \.self) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showProfile = true
                        } label: {
                            if let memeber = UserManager.shared.currentMember,
                                let avatarURL = memeber.avatarNormal,
                                let url = URL(string: avatarURL)
                            {
                                KFImage(url)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(.blue)
                            }
                        }
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

struct TopicRoute: Hashable {
    let id: Int
    let topic: Topic?
}

#Preview {
    HomeView()
}
