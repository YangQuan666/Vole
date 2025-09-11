//
//  ProfileView.swift
//  Vole
//
//  Created by 杨权 on 9/8/25.
//

import Kingfisher
import SwiftUI

struct ProfileView: View {
    @State private var step: Int
    @State private var inputToken: String = ""
    @StateObject private var userManager = UserManager.shared

    init() {
        if UserManager.shared.token != nil,
            UserManager.shared.currentMember != nil
        {
            _step = State(initialValue: 3)
        } else {
            _step = State(initialValue: 1)
        }
    }

    var body: some View {
        VStack {
            if step == 1 {
                WelcomePage {
                    withAnimation {
                        step = 2
                    }
                }
            } else if step == 2 {
                TokenInputPage(token: $inputToken) {
                    Task {
                        await login()
                    }
                }
            } else if step == 3 {
                UserInfoPage(onLogout: {
                    logout()
                })
            }
        }
        .padding()
        .animation(.easeInOut, value: step)
    }

    private func login() async {
        guard !inputToken.isEmpty else { return }
        do {
            let response = try await V2exAPI.shared.token()
            if let r = response, r.success {
                let token = r.result
                userManager.saveToken(token)

                let response = try await V2exAPI.shared.member()
                if let r = response, r.success {
                    let member = r.result
                    userManager.saveMember(member)
                    withAnimation {
                        step = 3
                    }
                }
            }

        } catch {
            print("❌ 获取 Member 失败: \(error)")
        }

    }

    private func logout() {
        userManager.clear()
        withAnimation {
            step = 1
        }
    }
}

struct WelcomePage: View {
    var onContinue: () -> Void
    var body: some View {
        ZStack {

            VStack(spacing: 20) {
                Spacer(minLength: 32)

                // 标题区
                Text("欢迎使用 Vole")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)
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
// MARK: - 输入 Token 页
struct TokenInputPage: View {
    @Binding var token: String
    var onLogin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("请输入 Token")
                .font(.title2)
                .bold()

            TextField("输入你的 token", text: $token)
                .textFieldStyle(.roundedBorder)

            Text("你可以在 https://example.com 获取 token")
                .font(.footnote)
                .foregroundColor(.gray)

            Button("登录") {
                onLogin()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - 用户信息页
struct UserInfoPage: View {
    @ObservedObject private var userManager = UserManager.shared
    var onLogout: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if let member = userManager.currentMember {
                Text("欢迎，\(member.username)")
                    .font(.title2)
                    .bold()

                if let email = member.website {
                    Text("网站: \(email)")
                }
            } else {
                Text("未找到用户信息")
                    .foregroundColor(.red)
            }
            if let token = userManager.token {
                Text("token: \(token.expiration)")
            }

            Spacer()

            Button("退出登录") {
                onLogout()
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

#Preview {
    var member2 = Member(id: 492604, username: "oligi")
    let jsonString = """
        {
            "id": 492604,
            "username": "oligi",
            "url": "https://www.v2ex.com/u/oligi",
            "website": "https://yangquan.netlify.app",
            "twitter": "",
            "psn": "",
            "github": "YangQuan666",
            "btc": "",
            "location": "",
            "tagline": "",
            "bio": "",
            "avatar_mini": "https://cdn.v2ex.com/avatar/44a2/beec/492604_mini.png?m=1756123037",
            "avatar_normal": "https://cdn.v2ex.com/avatar/44a2/beec/492604_normal.png?m=1756123037",
            "avatar_large": "https://cdn.v2ex.com/avatar/44a2/beec/492604_large.png?m=1756123037",
            "avatar_xlarge": "https://cdn.v2ex.com/avatar/44a2/beec/492604_xlarge.png?m=1756123037",
            "avatar_xxlarge": "https://cdn.v2ex.com/avatar/44a2/beec/492604_xxlarge.png?m=1756123037",
            "created": 1590995584,
            "last_modified": 1756123037,
            "pro": 0
        }
        """
    WelcomePage {

    }
}
