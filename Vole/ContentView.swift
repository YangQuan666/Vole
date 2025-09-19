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

    var body: some View {

        if #available(iOS 26, *) {
            TabView(selection: $selection) {
                Tab("Home", systemImage: "doc.text.image", value: .home) {
                    HomeView()
                }
                Tab("Node", systemImage: "square.grid.2x2.fill", value: .node) {
                    NodeView()
                }
                Tab(
                    "Notify",
                    systemImage: "tray.full.fill",
                    value: .notify
                ) {
                    NotifyView()
                }
                Tab(
                    "Search",
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
                Tab("Home", systemImage: "doc.text.image", value: .home) {
                    HomeView()
                }
                Tab("Node", systemImage: "square.grid.2x2.fill", value: .node) {
                    NodeView()
                }
                Tab(
                    "Notify",
                    systemImage: "tray.full.fill",
                    value: .notify
                ) {
                    NotifyView()
                }
                Tab(
                    "Search",
                    systemImage: "magnifyingglass",
                    value: .search,
                    role: .search
                ) {
                    SearchView()
                }
            }
        }

    }
}

enum TabID: Hashable {
    case home, node, notify, search
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
