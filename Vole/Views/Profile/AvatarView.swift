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
    var size: CGFloat = 36
    @ObservedObject var userManager: UserManager = .shared

    var body: some View {
        Button(action: action) {
            if let member = userManager.currentMember,
                let avatarURL = member.getHighestQualityAvatar(),
                let url = URL(string: avatarURL)
            {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.blue)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AvatarView {}
}
