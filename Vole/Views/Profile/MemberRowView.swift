//
//  UserInfoView.swift
//  Vole
//
//  Created by 杨权 on 9/22/25.
//

import Kingfisher
import SwiftUI

struct MemberRowView: View {
    let member: Member?

    @ObservedObject private var userManager: UserManager = .shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let member = member {
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

            if let bio = member.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

        } else {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.exclam")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("未找到用户信息")
                    .foregroundColor(.red)
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
