//
//  Home.swift
//  Vole
//
//  Created by 杨权 on 5/25/25.
//

import Kingfisher
import SwiftUI

let categories = [
    NodeCategory(name: "技术", color: .indigo, systemIcon: "hammer.fill"),
    NodeCategory(name: "创意", color: .green, systemIcon: "sparkles.2"),
    NodeCategory(name: "好玩", color: .cyan, systemIcon: "puzzlepiece.fill"),
    NodeCategory(name: "Apple", color: .gray, systemIcon: "apple.logo"),
    NodeCategory(name: "酷工作", color: .brown, systemIcon: "briefcase.fill"),
    NodeCategory(name: "交易", color: .teal, systemIcon: "creditcard.fill"),
    NodeCategory(name: "城市", color: .blue, systemIcon: "building.2.fill"),
    NodeCategory(
        name: "问与答",
        color: .blue,
        systemIcon: "questionmark.bubble.fill"
    ),
]

struct NodeView: View {
    @State private var selectedCategory: NodeCategory? = nil
    @State private var path = NavigationPath()
    @State private var nodes: [Node] = []
    @State private var isLoading = false

    let sections = ["必玩游戏", "热门游戏"]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: 分类横向滚动
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.self) { category in
                                HStack(spacing: 8) {
                                    Image(systemName: category.systemIcon)
                                        .foregroundColor(category.color)
                                    Text(category.name)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.gray.opacity(0.1))
                                )
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: 节点列表
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("全部节点")
                                .font(.title3.bold())
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.horizontal)

                        if nodes.isEmpty && !isLoading {
                            VStack {
                                Image(systemName: "tray.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("暂无数据")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 150)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(nodes) { node in
                                    NodeRowView(node: node)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Node")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                }
            }
            .task {
                // 首次进入页面时加载
                if nodes.isEmpty {
                    await loadNodes()
                }
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - 加载逻辑
    func loadNodes() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await V2exAPI.shared.nodesList()
            await MainActor.run {
                nodes = result ?? []
                print("加载节点:", nodes.count)
            }
        } catch {
            if error is CancellationError { return }
            print("❌ 加载节点失败:", error)
        }
    }
}

// MARK: - Game Card
struct NodeRowView: View {
    let node: Node

    var body: some View {
        HStack(spacing: 12) {
            // 左侧头像
            if let avatarURL = node.avatarLarge,
                let url = URL(string: avatarURL)
            {
                KFImage(url)
                    .placeholder {
                        Color.gray
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
            }

            // 中间文字
            VStack(alignment: .leading, spacing: 4) {
                Text(node.title ?? "")
                    .font(.headline)
                    .lineLimit(1)

                Text(node.header ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 右侧菜单
            Image(systemName: "ellipsis")
                .font(.title3)
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(90))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct NodeCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
    let systemIcon: String
}

#Preview {
    NodeView()
}
