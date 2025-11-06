//
//  NodeDetailView.swift
//  Vole
//
//  Created by 杨权 on 10/28/25.
//

import Kingfisher
import SwiftUI

struct NodeDetailView: View {
    let node: Node
    @State private var dominantColor: Color = Color(.secondarySystemBackground)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let avatarURL = node.avatarLarge,
                    let url = URL(string: avatarURL)
                {

                    KFImage(url)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .padding(.top, 20)

                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 100, height: 100)
                        .padding(.top, 20)
                }

                VStack(spacing: 4) {
                    Text(node.title ?? "")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if !node.name.isEmpty {
                        Text(node.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 24) {
                    Label(
                        "\(node.topics ?? 0)",
                        systemImage: "list.bullet.rectangle.portrait"
                    )
                    .font(.subheadline)
                    Label("\(node.stars ?? 0)", systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                }
                .padding(.top, 4)

                if let header = node.header, !header.isEmpty {
                    Text(header)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let parent = node.parentNodeName, !parent.isEmpty {
                    Text("上级节点：\(parent)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }

                if let aliases = node.aliases, !aliases.isEmpty {
                    AliasesView(aliases: aliases)
                        .padding(.top, 6)
                }

                Divider()
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .background(dominantColor.opacity(0.85))
            // 页面加载时立即从缓存取主色
            .onAppear {
                updateDominantColor(urlString: node.avatarLarge)
            }
        }
    }

    // MARK: - 优先同步内存缓存，异步磁盘缓存
    func updateDominantColor(urlString: String?) {
        guard let urlString = urlString else { return }
        let cache = ImageCache.default
        let key = urlString

        // 1️⃣ 内存缓存同步
        if let image = cache.retrieveImageInMemoryCache(forKey: key),
            let color = image.cgImage?.averageColor
        {
            dominantColor = color
            return
        }

        // 2️⃣ 磁盘缓存异步
        if URL(string: urlString) != nil {
            Task {
                if let image = try? await cache.retrieveImageInDiskCache(
                    forKey: key
                ),
                    let color = image.cgImage?.averageColor
                {
                    await MainActor.run {
                        dominantColor = color
                    }
                }
            }
        }
    }
}

// MARK: - 平均主色提取（纯 CoreGraphics）
extension CGImage {
    var averageColor: Color? {
        let width = 1
        let height = 1
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmap = [UInt8](repeating: 0, count: 4)
        guard
            let context = CGContext(
                data: &bitmap,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Color(
            red: Double(bitmap[0]) / 255.0,
            green: Double(bitmap[1]) / 255.0,
            blue: Double(bitmap[2]) / 255.0
        )
    }
}

// Aliases 标签视图
struct AliasesView: View {
    let aliases: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(aliases, id: \.self) { alias in
                Text(alias)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

#Preview {
    //    NodeDetailView()
}
