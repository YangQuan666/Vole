//
//  SearchHistoryView.swift
//  Vole
//
//  Created by 杨权 on 11/23/25.
//

import SwiftUI

struct SearchHistoryView: View {
    // 动作回调：当用户点击历史记录时，告诉父视图执行搜索
    let onKeywordTapped: (String) -> Void
    
    // 数据源：搜索历史（使用 ObservedObject 接收 SearchHistory.shared）
    @ObservedObject var history: SearchHistory
    
    var body: some View {
        List {
            Section {
                ForEach(history.keywords, id: \.self) { keyword in
                    Button {
                        // 触发回调，将关键词传给父视图
                        onKeywordTapped(keyword)
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                            Text(keyword)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
                .onDelete { indexSet in
                    // 删除单行历史
                    history.remove(at: indexSet)
                }
            } header: {
                HStack {
                    Text("最近搜索")
                    Spacer()
                    if !history.keywords.isEmpty {
                        Button("清除") {
                            history.clear()
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
//    SearchHistoryView()
}
