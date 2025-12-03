//
//  SearchFilterView.swift
//  Vole
//
//  Created by 杨权 on 12/3/25.
//

import SwiftUI

// 筛选相关的枚举与模型

struct SearchFilterSheet: View {
    @Binding var options: SearchFilterOptions
    var onConfirm: () -> Void
    var onCancel: () -> Void

    // 内部暂存状态，点击确定才应用
    @State private var tempOptions: SearchFilterOptions

    init(
        options: Binding<SearchFilterOptions>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._options = options
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        // 初始化暂存状态
        self._tempOptions = State(initialValue: options.wrappedValue)
    }

    var body: some View {
        NavigationView {
            Form {
                // 1. 时间筛选
                Section(header: Text("发布时间")) {
                    Picker("时间范围", selection: $tempOptions.timeRange) {
                        ForEach(SearchTimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)  // 或者用 .segmented
                }

                // 2. 节点筛选
                Section(header: Text("节点")) {
                    TextField(
                        "输入节点名称 (例如: python)",
                        text: $tempOptions.nodeName
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }

                // 3. 排序方式
                Section(header: Text("排序")) {
                    Picker("排序方式", selection: $tempOptions.sortType) {
                        ForEach(SearchSortType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("筛选条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        // 将暂存状态同步回外部，并触发回调
                        options = tempOptions
                        onConfirm()
                    }
                }
            }
        }
    }
}

#Preview {
    SearchFilterView()
}
