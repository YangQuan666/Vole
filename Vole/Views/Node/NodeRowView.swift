//
//  NodeRowView.swift
//  Vole
//
//  Created by 杨权 on 10/19/25.
//

import Kingfisher
import SwiftUI

struct NodeRowView: View {
    let node: Node
    private let baseURL = URL(string: "https://www.v2ex.com")!

    var body: some View {
        HStack {
            // 左侧头像
            if let avatarURL = node.avatarLarge,
                let url = makeFullURL(from: avatarURL)
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

    /// 构建完整 URL（支持相对路径）
    private func makeFullURL(from path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        } else {
            return URL(string: path, relativeTo: baseURL)
        }
    }
}

#Preview {
    if let node = ModelData().topics[0].node {
        NodeRowView(node: node)
    }
}
