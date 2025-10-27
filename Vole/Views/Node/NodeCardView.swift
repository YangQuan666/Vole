//
//  NodeRowView.swift
//  Vole
//
//  Created by 杨权 on 10/19/25.
//

import Kingfisher
import SwiftUI

struct NodeCardView: View {
    let node: Node

    var body: some View {
        HStack {
            // 左侧头像
            if let avatarURL = node.avatarLarge,
                let url = URL(string: avatarURL)
            {
                KFImage(url)
                    .placeholder {
                        Color.gray
                    }
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title ?? "")
                    .font(.headline)
                    .lineLimit(1)

                Text(node.header ?? node.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(8)
    }
}

#Preview {
    if let node = ModelData().topics[0].node {
        NodeCardView(node: node)
    }
}
