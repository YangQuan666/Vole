//
//  WelcomePage.swift
//  Vole
//
//  Created by 杨权 on 12/7/25.
//

import SwiftUI

struct WelcomePage: View {
    var onContinue: () -> Void
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Spacer(minLength: 32)

                // 标题区
                Text("欢迎使用 Vole")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 32)

                // Feature 列表
                VStack(alignment: .leading, spacing: 18) {
                    FeatureRow(
                        icon: "swift",
                        iconColor: .orange,
                        title: "Swift编写",
                        description: "基于最新的 SwiftUI，一次编写多平台轻松运行"
                    )
                    FeatureRow(
                        icon: "person.2.fill",
                        iconColor: .blue,
                        title: "会话展示",
                        description: "通过私信、回复等方式与社区用户互动并获得帮助"
                    )
                    FeatureRow(
                        icon: "key.icloud.fill",
                        iconColor: .green,
                        title: "安全保障",
                        description: "你的 Token 会被安全地存储在设备的 Keychain 中"
                    )
                }

                // 卡片下面：中间的 icon + 说明文字
                VStack(spacing: 12) {
                    // 小图标
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(UIColor.systemBlue))

                    // 说明文字（多行居中）
                    Text(
                        "一款基于V2ex API开发的第三方客户端，开源免费无广告 [了解更多](https://github.com/YangQuan666/Vole)"
                    )
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)
                }
                .padding(.top, 18)

                // 底部继续按钮（全宽）
                Button(action: onContinue) {
                    Text("继续")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .padding(.all)

                Spacer()
            }
            .padding()
        }
    }

}

// 单条 feature 行
struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack {

            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 28))
                .frame(width: 32, height: 32)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}
#Preview {
    WelcomePage{}
}
