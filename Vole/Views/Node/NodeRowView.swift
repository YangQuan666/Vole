//
//  NodeRowView.swift
//  Vole
//
//  Created by 杨权 on 10/19/25.
//

import Kingfisher
import SwiftSoup
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

                let text = parseHTML(node.header)
                Text(text.isEmpty ? node.name : text)
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

    private func parseHTML(_ html: String?) -> String {
        guard let content = html else { return "" }
        do {
            let doc = try SwiftSoup.parse(content)
            let fullText = try doc.text()
            return fullText
        } catch {
            print("HTML 解析失败: \(error)")
            return ""
        }
    }
}

#Preview {
    if let node = ModelData().topics[0].node {
        NodeRowView(node: node)
    }
}
