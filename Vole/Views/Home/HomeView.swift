//
//  Home.swift
//  Vole
//
//  Created by 杨权 on 5/25/25.
//

import SwiftUI

struct HomeView: View {

    @State private var path = NavigationPath()
    @State private var selection: Category = .latest
    @State private var data: [Category: [Topic]] = [:]

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
            VStack {
                Picker("分类", selection: $selection) {
                    ForEach(Category.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .frame(maxWidth: 500)

                TabView(selection: $selection) {
                    ForEach(Category.allCases, id: \.self) { category in
                        Group {
                            if let topics = data[category], !topics.isEmpty {
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(topics) { topic in
                                            TopicRow(
                                                topic: topic,
                                            ) {
                                                path.append(TopicRoute(id: topic.id, topic: topic))
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .frame(maxWidth: 600)
                                .refreshable {
                                    await loadTopics(for: category)
                                }
                            } else {
                                // 数据为空时显示加载动画
                                VStack {
                                    Spacer()
                                    ProgressView("加载中…")
                                        .progressViewStyle(.circular)
                                        .padding()
                                    Spacer()
                                }
                            }
                        }
                        .tag(category)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: TopicRoute.self) { route in
                DetailView(topicId: route.id, topic: route.topic, path: $path)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {  // 右上角头像
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.blue)
                }

            }
            .task(id: selection) {
                // 首次加载默认分类
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
