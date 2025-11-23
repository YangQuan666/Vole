//
//  SearchResultsView.swift
//  Vole
//
//  Created by 杨权 on 11/23/25.
//

import SwiftUI

struct SearchResultsView: View {
    // 数据源：搜索结果
    let results: [SoV2exHit]
    // 动作回调：当用户点击结果时，告诉父视图进行导航跳转
    let onResultTapped: (Route) -> Void

    var body: some View {
        List(results) { res in
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(res.source.member)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                Text(res.source.title)
                    .font(.headline)
                Text(res.source.content)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("\(res.source.node)")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                    Spacer()

                    Text(
                        DateConverter.relativeTimeString(
                            isoDateString: res.source.created
                        )
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.bubble")
                            .foregroundColor(.secondary)
                        Text("\(res.source.replies)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
            .onTapGesture {
                // 触发回调，进行跳转
                onResultTapped(Route.topicId(res.source.id))
            }
        }
    }
}

#Preview {
//    SearchResultsView()
}
