//
//  UserInfoView.swift
//  Vole
//
//  Created by 杨权 on 9/22/25.
//

import Kingfisher
import SwiftUI

struct MemberDetailView: View {
    @ObservedObject private var userManager: UserManager = .shared
    @Environment(\.openURL) private var openURL
    var member: Member?

    var body: some View {
        if let member = member {
            // 顶部用户信息
            Section {
                HStack(spacing: 8) {
                    if let avatarURL = member.getHighestQualityAvatar(),
                        let url = URL(string: avatarURL)
                    {
                        KFImage(url)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 128, height: 128)
                            .clipShape(Circle())
                            .padding(.top, 8)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 128, height: 128)
                            .padding(.top, 8)
                    }
                    VStack(spacing: 8) {
                        Text(member.username)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if let id = member.id {
                            Text("第 \(id) 位会员")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }

                        if let tagline = member.tagline,
                            !tagline.isEmpty
                        {
                            Text("\"\(tagline)\"")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowSeparator(.hidden)

                if let bio = member.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .center)
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

                if let location = member.location, !location.isEmpty {
                    HStack {
                        Label("所在地区", systemImage: "mappin.and.ellipse")
                        Spacer()
                        Text(location)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if let website = member.website, !website.isEmpty {
                    Button {
                        if let url = URL(string: website) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Label("个人网站", systemImage: "house")
                            Spacer()
                            Text(website)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let btc = member.btc, !btc.isEmpty {
                    Button {
                        if let url = URL(string: btc) {
                            openURL(url)
                        }
                    } label: {
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
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let github = member.github, !github.isEmpty {
                    Button {
                        if let url = URL(
                            string: "https://github.com/\(github)"
                        ) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Label("GitHub", systemImage: "network")
                            Spacer()
                            Text(github)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let twitter = member.twitter, !twitter.isEmpty {
                    Button {
                        if let url = URL(
                            string: "https://x.com/\(twitter)"
                        ) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Label("Twitter", systemImage: "network")
                            Spacer()
                            Text(twitter)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let psn = member.psn, !psn.isEmpty {
                    Button {
                        if let url = URL(
                            string: "https://psnprofiles.com/\(psn)"
                        ) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Label("Twitter", systemImage: "network")
                            Spacer()
                            Text(psn)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .buttonStyle(.plain)
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
    MemberDetailView(member: member)
}
