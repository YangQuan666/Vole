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
            _step = State(initialValue: 2)
        }
    }

    var body: some View {
        VStack {
            if step == 2 {
                TokenInputPage(
                    token: $inputToken,
                    onValidate: validateToken,
                    onLogin: { token in
                        try await loginWithToken(token)
                        withAnimation {
                            step = 3
                        }
                    }
                )
            } else if step == 3 {
                MemberView(
                    member: userManager.currentMember,
                    admin: true,
                    onLogout: {
                        logout()
                    }
                )
            }
        }
        .animation(.easeInOut, value: step)
    }

    // 第一步：校验 Token 有效性
    func validateToken(_ token: String) async throws -> Token {
        let response = try await V2exAPI.shared.token(token: token)
        if let r = response, let token = r.result, r.success {
            userManager.saveToken(token)
            return token
        } else {
            throw NSError(
                domain: "TokenError",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: response?.message ?? "Token校验失败"
                ]
            )
        }
    }

    // 第二步：登录
    func loginWithToken(_ token: String) async throws {
        let response = try await V2exAPI.shared.member()
        if let r = response, let memeber = r.result, r.success {
            userManager.saveMember(memeber)
            print(memeber)
        } else {
            throw NSError(
                domain: "LoginError",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "登录失败，请稍后重试"
                ]
            )
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

struct TokenInputPage: View {
    @Binding var token: String
    var onValidate: (String) async throws -> Token  // 校验 Token，返回过期时间
    var onLogin: (String) async throws -> Void  // 登录

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var tokenExpiry: Int?  // 校验通过后保存过期时间
    @State private var loginFailed = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题
            VStack(spacing: 12) {
                Text("使用 Token 登录")
                    .font(.largeTitle)
                    .bold()
                Text("以更加安全的方式访问你账户中的数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 60)

            Spacer()

            // 输入区域
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    TextField("请输入 Token", text: $token)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 30)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 34)
                    }

                    // 校验通过显示过期时间
                    if let expiry = tokenExpiry {
                        Text("你的 Token 有效期剩余 \(expiry) 天")
                            .font(.footnote)
                            .foregroundColor(.green)
                            .padding(.horizontal, 34)
                    }
                }

                // 获取 token 提示
                Label {
                    Text(
                        "了解如何获取 [Personal Access Token](https://www.v2ex.com/help/personal-access-token)"
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }

            Spacer()

            // 底部按钮
            Button(action: handleAction) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: .white)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                } else {
                    Text(buttonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
            }
            .background(
                (token.isEmpty || isLoading)
                    ? Color.gray.opacity(0.3) : Color.accentColor
            )
            .foregroundColor(.white)
            .cornerRadius(14)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .disabled(token.isEmpty || isLoading)

            Spacer()
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
    }

    // 按钮文字根据状态变化
    private var buttonTitle: String {
        if loginFailed {
            return "重试"
        } else if tokenExpiry != nil {
            return "下一步"
        } else {
            return "校验 Token"
        }
    }

    private func handleAction() {
        errorMessage = nil
        isLoading = true
        loginFailed = false

        Task {
            do {
                if tokenExpiry == nil {
                    // 第一步：校验 Token
                    let t = try await onValidate(token)
                    await MainActor.run {
                        tokenExpiry = t.goodForDays
                        isLoading = false
                    }
                } else {
                    // 第二步：登录
                    try await onLogin(token)
                    await MainActor.run {
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    loginFailed = true
                }
            }
        }
    }

    private func formattedExpiry(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct TokenRenewPage: View {
    let currentToken: Token
    @State private var newToken: String?

    var body: some View {
        List {
            Section {
                if let token = currentToken.token {
                    HStack {
                        Text("Token")
                        Spacer()
                        Text(token)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                            .contextMenu {
                                Button(
                                    "复制原始 Token",
                                    systemImage:
                                        "document.on.document"
                                ) {
                                    UIPasteboard.general
                                        .string = token
                                }
                            }
                    }
                }
                if let created = currentToken.created {
                    HStack {
                        Text("创建时间")
                        Spacer()
                        Text("\(formatDate(created))")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if let lastUsed = currentToken.lastUsed {
                    HStack {
                        Text("上次使用时间")
                        Spacer()
                        Text("\(formatDate(lastUsed))")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if let expiration = currentToken.expiration {
                    HStack {
                        Text("有效期")
                        Spacer()
                        Text("\(expiration/86400) 天")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if let created = currentToken.created,
                    let expiration = currentToken.expiration
                {
                    // 当前时间戳（秒）
                    let now = Date().timeIntervalSince1970
                    // 过期时间戳
                    let expireAt = Double(created) + Double(expiration)
                    // 剩余秒数（小于 0 时强制为 0）
                    let remainingSeconds = max(0, expireAt - now)
                    // 转换成天数（保留 1 位小数）
                    let remainingDays = remainingSeconds / 86400

                    HStack {
                        Text("剩余天数")
                        Spacer()
                        Text("\(Int(remainingDays.rounded())) 天")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .navigationTitle("Token 详情")
        .navigationBarTitleDisplayMode(.inline)
    }
    //
    //    func renewToken() {
    //        // 模拟续期逻辑，这里实际应该调用你的接口
    //        newToken = currentToken + "_NEW"
    //    }
}

func maskedToken(_ token: String) -> String {
    guard token.count > 8 else { return token }  // 不足8位直接返回原始token
    let start = token.prefix(4)
    let end = token.suffix(4)
    return "\(start)****\(end)"
}

func formatDate(_ timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"  // 年-月-日
    return formatter.string(from: date)
}

#Preview {
    let token = Token(
        token: "1298312381209381290381029",
        scope: "",
        expiration: 2_592_000,
        goodForDays: 3,
        totalUsed: 1,
        lastUsed: 1,
        created: 1
    )
    TokenRenewPage(currentToken: token)
}
