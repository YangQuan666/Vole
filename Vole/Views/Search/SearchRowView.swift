//
//  SearchRowView.swift
//  Vole
//
//  Created by 杨权 on 11/24/25.
//

import SwiftUI

struct SearchRowView: View {
    let result: SoV2exHit
    
    @StateObject private var nodeManager = NodeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                // 作者
                Text(result.source.member)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
            }

            // 标题
            Text(result.source.title)
                .font(.headline)

            // 内容摘要
            Text(result.source.content)
                .font(.body)
                .lineLimit(2)
                .foregroundStyle(.secondary)

            // 底部信息：节点 + 时间 + 评论数量
            HStack {
                let node = nodeManager.getNode(result.source.node)
                // 节点
                Text(node?.title ?? "\(result.source.node)")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
                Spacer()

                // 时间
                Text(
                    DateConverter.relativeTimeString(
                        isoDateString: result.source.created
                    )
                )
                .font(.caption)
                .foregroundColor(.secondary)

                // 评论数
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis.bubble")
                        .foregroundColor(.secondary)
                    Text("\(result.source.replies)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }

    }
}

#Preview {
    let mockResult = SoV2exHit(
        
        source: SoV2exTopic(
            id: 100000,
            title: "请教一个关于 Swift 结构化并发的问题",
            content: "最近在尝试使用 Actor 隔离状态，但在跨 Actor 调用时遇到了死锁问题，有大佬能提供一些调试思路吗？",
            member: "Swift_Coder",
            created: "2025-11-24T09:00:00Z",
            replies: 12,
            node: 56,
        ),
        highlight: nil,
        id: "100000",
    )
    SearchRowView(result: mockResult)
}
