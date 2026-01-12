//
//  UserInfoView.swift
//  Vole
//
//  Created by 杨权 on 9/22/25.
//

import Kingfisher
import SwiftUI

struct MemberView: View {
    @State private var showAlert = false
    @ObservedObject private var userManager: UserManager = .shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var member: Member?

    var onLogout: (() -> Void)?

    var body: some View {
        NavigationView {
            List {
                // 顶部用户信息
                MemberDetailView(member: member)

                // token管理
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

                // 退出登录
                Section {
                    Button(role: .destructive) {
                        onLogout?()
                    } label: {
                        HStack {
                            Spacer()
                            Text("退出登录")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }

            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的信息")
            .navigationBarTitleDisplayMode(.inline)
            // 2. 添加完成按钮
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        if #available(iOS 26.0, *) {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                                .font(.title)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let member = Member(
        id: 1111,
        username: "oligi",
        location: "陕西",
        tagline: "NS 巫师3 真好玩",
        bio: "我是一名爱打游戏，爱编程、喜欢打羽毛球的INTP人格",
        created: 1
    )
    MemberView(member: member)
}
