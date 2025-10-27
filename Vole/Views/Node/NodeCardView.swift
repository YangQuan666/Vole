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

//    var body: some View {
//        HStack(spacing: 12) {
//            // 左侧头像
//            if let avatarURL = node.avatarLarge,
//                let url = URL(string: avatarURL)
//            {
//                KFImage(url)
//                    .placeholder {
//                        Color.gray
//                    }
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 50, height: 50)
//                    .clipShape(Circle())
//            } else {
//                RoundedRectangle(cornerRadius: 8)
//                    .fill(Color.gray.opacity(0.2))
//                    .frame(width: 50, height: 50)
//            }
//
//            // 中间文字
//            VStack(alignment: .leading, spacing: 4) {
//                Text(node.title ?? "")
//                    .font(.headline)
//                    .lineLimit(1)
//
//                Text(node.header ?? "")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .lineLimit(1)
//            }
//
//            Spacer()
//
//            // 右侧菜单
//            Image(systemName: "ellipsis")
//                .font(.title3)
//                .foregroundColor(.secondary)
//                .rotationEffect(.degrees(90))
//        }
//        .padding(.horizontal)
//        .padding(.vertical, 8)
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(.background)
//                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
//        )
//    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(.blue)
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title ?? "")
                    .font(.headline)
                Text(node.title ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
