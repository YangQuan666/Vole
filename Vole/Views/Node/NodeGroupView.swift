//
//  NodeGroupView.swift
//  Vole
//
//  Created by 杨权 on 11/13/25.
//

import SwiftUI

struct NodeGroupView: View {
    let group: NodeGroup
    @Binding var path: NavigationPath

    var body: some View {
        List(group.nodes) { node in
            NodeCardView(node: node)
                .onTapGesture {
                    path.append(Route.node(node))
                }
        }
        .listStyle(.plain)
        .navigationTitle(group.root.title ?? group.root.name)
    }
}

