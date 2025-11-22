//
//  Home.swift
//  Vexer
//
//  Created by 杨权 on 5/25/25.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        NavigationStack(path: $navManager.searchPath) {
            List {
                if searchText.isEmpty {
                    Text("请输入关键词进行搜索")
                        .foregroundColor(.secondary)
                } else {
                    // 这里填搜索结果
                    Text("搜索结果: \(searchText)")
                }
            }
            .navigationTitle("搜索")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic)
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .topicId(let topicId):
                    DetailView(topicId: topicId, path: $navManager.searchPath)
                case .nodeName(let nodeName):
                    NodeDetailView(
                        nodeName: nodeName,
                        path: $navManager.nodePath
                    )
                case .node(let node):
                    NodeDetailView(node: node, path: $navManager.searchPath)
                default: EmptyView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}

#Preview {
    @Previewable var navManager = NavigationManager()
    SearchView().environmentObject(navManager)
}
