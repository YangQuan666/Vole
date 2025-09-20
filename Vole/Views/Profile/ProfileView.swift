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
                UserInfoPage(onLogout: {
                    logout()
                })
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

// MARK: - 用户信息页
struct UserInfoPage: View {
    @ObservedObject private var userManager = UserManager.shared
    // 1. 获取 dismiss 环境值
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var onLogout: () -> Void

    var body: some View {
        NavigationView {
            List {
                if let member = userManager.currentMember {
                    // 顶部用户信息
                    Section {
                        HStack(spacing: 8) {
                            if let avatarURL = member.avatarLarge,
                                let url = URL(string: avatarURL)
                            {
                                KFImage(url)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .padding(.top, 8)
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 80, height: 80)
                                    .padding(.top, 8)
                            }
                            VStack(spacing: 8) {
                                Text(member.username)
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                Text("第 \(member.id) 位会员")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)

                                if let bio = member.bio {
                                    Text(bio)
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                        }
                    }

                    // 账户信息
                    Section {
                        if let created = member.created {
                            HStack {
                                Label("创建日期", systemImage: "calendar")
                                Spacer()
                                Text(formatDate(created))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }

                        if let website = member.website, !website.isEmpty {
                            HStack {
                                Label("个人网站", systemImage: "house")
                                Spacer()
                                Text(website)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .contextMenu {
                                        Button("在浏览器中打开", systemImage: "safari")
                                        {
                                            if let url = URL(string: website) {
                                                openURL(url)
                                            }
                                        }
                                    }
                            }
                        }

                        if let btc = member.btc, !btc.isEmpty {
                            HStack {
                                Label(
                                    "BTC",
                                    systemImage: "bitcoinsign.ring.dashed"
                                )
                                Spacer()
                                Text(btc)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .contextMenu {
                                        Button("在浏览器中打开", systemImage: "safari")
                                        {
                                            if let url = URL(string: btc) {
                                                openURL(url)
                                            }
                                        }
                                    }
                            }
                        }

                        if let github = member.github, !github.isEmpty {
                            HStack {
                                Label("GitHub", systemImage: "network")
                                Spacer()
                                Text(github)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .contextMenu {
                                        Button("在浏览器中打开", systemImage: "safari")
                                        {
                                            if let url = URL(
                                                string:
                                                    "https://github.com/\(github)"
                                            ) {
                                                openURL(url)
                                            }
                                        }
                                    }
                            }
                        }

                        if let twitter = member.twitter, !twitter.isEmpty {
                            HStack {
                                Label("Twitter", systemImage: "network")
                                Spacer()
                                Text(twitter)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .contextMenu {
                                        Button("在浏览器中打开", systemImage: "safari")
                                        {
                                            if let url = URL(string: twitter) {
                                                openURL(url)
                                            }
                                        }
                                    }
                            }
                        }
                        
                        if let psn = member.psn, !psn.isEmpty {
                            HStack {
                                Label("Twitter", systemImage: "network")
                                Spacer()
                                Text(psn)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .contextMenu {
                                        Button("在浏览器中打开", systemImage: "safari")
                                        {
                                            if let url = URL(string: psn) {
                                                openURL(url)
                                            }
                                        }
                                    }
                            }
                        }

                        if let token = userManager.token?.token {
                            HStack {
                                Label("Token", systemImage: "key.viewfinder")
                                Spacer()
                                Text(maskedToken(token))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .contextMenu {
                                        Button(
                                            "复制原始 Token",
                                            systemImage: "document.on.document"
                                        ) {
                                            UIPasteboard.general.string = token
                                        }
                                    }
                            }
                        }
                    }

                    // 退出登录
                    Section {
                        Button(role: .destructive) {
                            onLogout()
                        } label: {
                            HStack {
                                Spacer()
                                Text("退出登录")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                } else {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.exclam")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("未找到用户信息")
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(Color(.blue))
            .navigationTitle("用户信息")
            .navigationBarTitleDisplayMode(.inline)
            // 2. 添加完成按钮
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
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
