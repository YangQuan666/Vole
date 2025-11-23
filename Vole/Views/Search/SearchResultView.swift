//
//  SearchResultsView.swift
//  Vole
//
//  Created by 杨权 on 11/23/25.
//

import SwiftUI

struct SearchResultView: View {

    let results: [SoV2exHit]
    let onResultTapped: (Route) -> Void  // 点击结果后通知父视图进行导航

    // MARK: - 分页状态

    let totalResults: Int?  // 总结果数 (从 API 获取)
    let isPagingLoading: Bool  // 是否正在加载下一页
    let onLoadMore: () -> Void  // 加载下一页的动作/回调

    var body: some View {
        List {
            // 使用 indices 遍历，以便获取索引来判断是否是最后一个元素
            ForEach(results.indices, id: \.self) { index in
                let res = results[index]

                // 列表项内容
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

                    // 节点 + 时间 + 评论数量
                    HStack {
                        Text("\(res.source.node)")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                        Spacer()

                        // 假设 DateConverter.relativeTimeString 已经实现
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
                    onResultTapped(Route.topicId(res.source.id))
                }

                // ⭐️ 自动分页加载触发器
                .onAppear {
                    // 当用户看到倒数第一个元素时，触发加载下一页
                    if index == results.count - 1 {
                        onLoadMore()
                    }
                }
            }

            // 底部加载指示器和完成提示
            footerView
        }
        .listStyle(.plain)
    }

    // 列表底部视图（加载指示器或完成提示）
    @ViewBuilder
    private var footerView: some View {
        if isPagingLoading {
            HStack {
                Spacer()
                ProgressView("加载更多...")
                Spacer()
            }
            .padding()
        } else if let total = totalResults,
            results.count >= total && results.count > 0
        {
            // 结果数量等于总数，且列表非空时，显示加载完成
            Text("已加载全部 \(results.count) 条结果")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)  // 隐藏分割线，让提示更美观
                .padding()
        }
    }
}

#Preview {
    //    SearchResultsView()
}
