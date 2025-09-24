//
//  Member.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import Foundation

public struct Member: Identifiable, Decodable, Encodable, Hashable {
    public var id: Int
    public var username: String
    public var url: String?
    public var website: String?
    public var twitter: String?
    public var psn: String?
    public var github: String?
    public var btc: String?
    public var location: String?
    public var tagline: String?
    public var bio: String?
    public var avatar: String?
    public var avatarMini: String?
    public var avatarNormal: String?
    public var avatarLarge: String?
    public var avatarXLarge: String?
    public var avatarXXLarge: String?
    public var avatarXXXLarge: String?
    public var created: Int?
    public var lastModified: Int?
    public var pro: Int?

    enum CodingKeys: String, CodingKey {
        case id, username, url, website, twitter, psn, github, btc, location,
            tagline, bio, created, pro, avatar
        case avatarMini = "avatar_mini"
        case avatarNormal = "avatar_normal"
        case avatarLarge = "avatar_large"
        case avatarXLarge = "avatar_xlarge"
        case avatarXXLarge = "avatar_xxlarge"
        case avatarXXXLarge = "avatar_xxxlarge"
        case lastModified = "last_modified"
    }

    // 获取最高清的头像
    public func getHighestQualityAvatar() -> String? {
        // 返回第一个有效的头像 URL，从 mini 到 XXXLarge
        if let avatarXXXLarge = avatarXXXLarge, !avatarXXXLarge.isEmpty {
            print(avatarXXXLarge)
            return avatarXXXLarge
        }
        if let avatarXXLarge = avatarXXLarge, !avatarXXLarge.isEmpty {
            return avatarXXLarge
        }
        if let avatarXLarge = avatarXLarge, !avatarXLarge.isEmpty {
            return avatarXLarge
        }
        if let avatarLarge = avatarLarge, !avatarLarge.isEmpty {
            return avatarLarge
        }
        if let avatarNormal = avatarNormal, !avatarNormal.isEmpty {
            return avatarNormal
        }
        if let avatar = avatar, !avatar.isEmpty {
            return avatar
        }
        if let avatarMini = avatarMini, !avatarMini.isEmpty {
            return avatarMini
        }
        // 如果都没有有效的头像，返回 nil
        return nil
    }
}
