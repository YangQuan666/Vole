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
        Group {
            if isLoading {
                ProgressView()
            } else if let content {
                agreementView(content)
            } else {
                ContentUnavailableView {
                    Label("无法载入协议", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("请稍后再试。")
                } actions: {
                    Button("重试") {
                        Task { await loadEULA() }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEULA() }
    }

    private func agreementView(_ content: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VoleMarkdownView(content: content)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scenePadding()
        }
        .modifier(AgreementActionBar(onAgree: onAgree))
    }

    // 顶部：图标 + 大标题 + 说明，参考系统 App 的条款与隐私说明页
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.tint)

            Text("条款与条件")
                .font(.largeTitle)
                .bold()

            Text("在开始使用 Vole 之前，请阅读以下最终用户许可协议，了解社区内容规范与违规处理方式。")
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
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
        content = Self.removingLeadingTitle(from: text)
    }

    /// 页面已有大标题，去掉 Markdown 开头重复的一级标题
    private static func removingLeadingTitle(from text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        while let first = lines.first,
            first.trimmingCharacters(in: .whitespaces).isEmpty
        {
            lines.removeFirst()
        }
        if let first = lines.first, first.hasPrefix("# ") {
            lines.removeFirst()
        }
        return lines.joined(separator: "\n")
    }
}

/// 底部固定操作区：iOS 26+ 使用系统 Liquid Glass 栏位与按钮，旧系统回退到系统栏材质
private struct AgreementActionBar: ViewModifier {
    let onAgree: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .bottom) {
                actions
                    .buttonStyle(.glassProminent)
                    .scenePadding()
            }
        } else {
            content.safeAreaInset(edge: .bottom) {
                actions
                    .buttonStyle(.borderedProminent)
                    .scenePadding()
                    .background(.bar)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Text("轻点“同意”，即表示你已阅读并同意上述条款。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onAgree) {
                Text("同意")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.extraLarge)
        }
    }
}

#Preview {
    NavigationStack {
        EULAView {}
    }
}
