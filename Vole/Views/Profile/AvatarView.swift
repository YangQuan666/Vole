//
//  AvatarView.swift
//  Vole
//
//  Created by 杨权 on 12/19/25.
//

import Kingfisher
import SwiftUI

struct AvatarView: View {
    var action: () -> Void
    var size: CGFloat = 32  // 建议在 Toolbar 里稍微加大到 34 或 36 来抵消视觉差
    @ObservedObject var userManager: UserManager = .shared

    var body: some View {
        Button(action: action) {
            // 不再使用 Group 包裹 Frame，而是直接分别控制
            if let member = userManager.currentMember,
                let avatarURL = member.getHighestQualityAvatar(),
                let url = URL(string: avatarURL)
            {
                KFImage(url)
                    .resizable()
                    .scaledToFill()  // 填满
                    .frame(width: size + 8, height: size + 8)  // 【关键】直接强制 KFImage 的尺寸
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.blue)
                    .frame(width: size, height: size)  // 同样显式限制系统图标
                    .clipShape(Circle())
            }
        }
    }
}

#Preview {
    AvatarView {}
}
