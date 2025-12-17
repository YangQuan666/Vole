//
//  ContentView.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selection: TabID = .home
    @StateObject private var navManager = NavigationManager()
    @ObservedObject private var notifyManager = NotifyManager.shared

    var body: some View {

        Group {
            if #available(iOS 26, *) {
                TabView(selection: $selection) {
                    Tab("主页", systemImage: "doc.text.image", value: .home) {
                        HomeView()
                    }
                    Tab(
                        "节点",
                        systemImage: "square.grid.2x2.fill",
                        value: .node
                    ) {
                        NodeView()
                    }
                    Tab(
                        "通知",
                        systemImage: "tray.full.fill",
                        value: .notify
                    ) {
                        NotifyView()
                    }
                    .badge(
                        notifyManager.unreadCount > 0
                            ? notifyManager.unreadCount : 0
                    )
                    Tab(
                        "搜索",
                        systemImage: "magnifyingglass",
                        value: .search,
                        role: .search
                    ) {
                        SearchView()
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                TabView(selection: $selection) {
                    Tab("主页", systemImage: "doc.text.image", value: .home) {
                        HomeView()
                    }
                    Tab(
                        "节点",
                        systemImage: "square.grid.2x2.fill",
                        value: .node
                    ) {
                        NodeView()
                    }
                    Tab(
                        "通知",
                        systemImage: "tray.full.fill",
                        value: .notify
                    ) {
                        NotifyView()
                    }
                    .badge(
                        notifyManager.unreadCount > 0
                            ? notifyManager.unreadCount : 0
                    )
                    Tab(
                        "搜索",
                        systemImage: "magnifyingglass",
                        value: .search,
                        role: .search
                    ) {
                        SearchView()
                    }
                }
            }
        }
        .environmentObject(navManager)
        .task {
            await notifyManager.refresh()
        }
    }
}

enum TabID: Hashable {
    case home, node, notify, search
}

#Preview {
    ContentView()
    //        .modelContainer(for: Item.self, inMemory: true)
}
