//
//  Home.swift
//  Vexer
//
//  Created by 杨权 on 5/25/25.
//

import SwiftUI

struct HomeView: View {
    @State private var path = NavigationPath()
    enum Filter: String, CaseIterable {
        case latest = "最新"
        case hot = "热门"

        // 给每个 case 绑定一个闭包
        var action: () async throws -> [Topic]? {
            switch self {
            case .hot:
                return { try await V2exAPI.shared.hotTopics() }
            case .latest:
                return { try await V2exAPI.shared.latestTopics() }
            }
        }
    }
    @State private var selection: Filter = .latest
    @State private var errorMessage: String?  // 可选：错误信息
    @State private var topics: [Topic] = []

    func loadData(selection: Filter) async {
        // 页面加载时执行异步请求
        errorMessage = nil
        do {
            let response = try await selection.action()
            topics = response ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // 分类
                Section {
                    Picker("分类", selection: $selection) {
                        ForEach(Filter.allCases, id: \.self) { item in
                            Text(item.rawValue)
                                .tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.all)
                    .listRowInsets(EdgeInsets())  // 去掉默认边距
                    .listRowSeparator(.hidden)  // 隐藏行分隔线
                }

                // 纵向卡片列表
                Section {
                    ForEach(topics) { topic in
                        TopicRow(topic: topic) {
                            path.append(topic)
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .frame(maxWidth: 600)
            .navigationDestination(for: Topic.self) { topic in
                TopicRow(topic: topic){}
            }
            .listStyle(.plain)  // 清爽列表样式
            .navigationTitle("Home")  // 左上角标题
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {  // 右上角头像
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.blue)
                }
            }
            .refreshable {
                await loadData(selection: selection)
            }
            .task(id: selection) {
                await loadData(selection: selection)
            }
        }
    }
}


#Preview {
    HomeView()
}
