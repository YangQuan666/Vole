//
//  UserInfoView.swift
//  Vole
//
//  Created by 杨权 on 9/22/25.
//

import Kingfisher
import SwiftUI

struct UserInfoView: View {
    var member: Member?
    @ObservedObject private var userManager = UserManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var onLogout: () -> Void

    var body: some View {
        NavigationView {
            List {
                if let member = member {
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

                                if let bio = member.bio, !bio.isEmpty {
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
                                    .lineLimit(1)
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
                                    .lineLimit(1)
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
                                    .lineLimit(1)
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
                                    .lineLimit(1)
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
                                    .lineLimit(1)
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
                    }

                    // 是当前登录用户
                    if let m = UserManager.shared.currentMember,
                        member.id == m.id
                    {
                        if let token = userManager.token,
                            let tokenStr = token.token
                        {
                            Section {
                                HStack {
                                    // 续期按钮
                                    NavigationLink(
                                        destination: TokenRenewPage(
                                            currentToken: token
                                        )
                                    ) {
                                        HStack {
                                            Label(
                                                "Token",
                                                systemImage: "key.viewfinder"
                                            )
                                            Spacer()
                                            Text(maskedToken(tokenStr))
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(
                                                    .trailing
                                                )
                                                .contextMenu {
                                                    Button(
                                                        "复制原始 Token",
                                                        systemImage:
                                                            "document.on.document"
                                                    ) {
                                                        UIPasteboard.general
                                                            .string = tokenStr
                                                    }
                                                }
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }

                        Section {
                            HStack {
                                NavigationLink(
                                    destination: SettingView()
                                ) {
                                    HStack {
                                        Label(
                                            "应用设置",
                                            systemImage: "gear"
                                        )
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.borderless)
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
}

#Preview {
    Text("")
}
