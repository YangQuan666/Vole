//
//  EulaView.swift
//  Vole
//
//  Created by 杨权 on 12/10/25.
//

import SwiftUI

struct EULAView: View {
    let onAgree: () -> Void

    @State private var content: String?
    @State private var isLoading = true

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("正在加载协议…")
                    .padding()
            } else if let content {
                ScrollView {
                    MarkdownView(content: content)
                        .padding()
                }
                Button("我已阅读并同意") {
                    onAgree()  // ← 回调核心在这里
                }
                .padding()
            } else {
                Text("加载失败，请重试")
            }
        }
        .task { await loadEULA() }
    }

    private func loadEULA() async {
        isLoading = true
        defer { isLoading = false }
        guard
            let url = Bundle.main.url(
                forResource: "EULA",
                withExtension: "md"
            ),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        content = text
    }
}
