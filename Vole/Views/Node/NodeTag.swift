//
//  NodeTag.swift
//  Vole
//

import SwiftUI

/// 节点标签：主题列表与主题详情共用的节点样式。
///
/// 只负责外观；是否可点击由使用方决定（详情页包在 Button 中）。
struct NodeTag: View {
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "square.stack.3d.up")
                .imageScale(.small)

            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.12))
        )
    }
}

extension NodeTag {
    init(node: Node) {
        if let title = node.title, !title.isEmpty {
            self.init(title: title)
        } else {
            self.init(title: node.name)
        }
    }
}

#Preview {
    NodeTag(title: "程序员")
}
