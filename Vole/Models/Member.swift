//
//  Member.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import Foundation

public struct Member: Identifiable, Decodable, Hashable {
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
    public var avatarMini: String?
    public var avatarNormal: String?
    public var avatarLarge: String?
    public var created: Int?
    public var lastModified: Int?
    public var pro: Int?

    enum CodingKeys: String, CodingKey {
        case id, username, url, website, twitter, psn, github, btc, location,
            tagline, bio, created, pro, avatar
        case avatarMini = "avatar_mini"
        case avatarNormal = "avatar_normal"
        case avatarLarge = "avatar_large"
        case lastModified = "last_modified"
    }
    
    public init(from decoder: Decoder) throws {
         let container = try decoder.container(keyedBy: CodingKeys.self)

         self.id = try container.decode(Int.self, forKey: .id)
         self.username = try container.decode(String.self, forKey: .username)
         self.url = try container.decodeIfPresent(String.self, forKey: .url)
         self.website = try container.decodeIfPresent(String.self, forKey: .website)
         self.twitter = try container.decodeIfPresent(String.self, forKey: .twitter)
         self.psn = try container.decodeIfPresent(String.self, forKey: .psn)
         self.github = try container.decodeIfPresent(String.self, forKey: .github)
         self.btc = try container.decodeIfPresent(String.self, forKey: .btc)
         self.location = try container.decodeIfPresent(String.self, forKey: .location)
         self.tagline = try container.decodeIfPresent(String.self, forKey: .tagline)
         self.bio = try container.decodeIfPresent(String.self, forKey: .bio)
         self.avatarMini = try container.decodeIfPresent(String.self, forKey: .avatarMini)
         self.avatarLarge = try container.decodeIfPresent(String.self, forKey: .avatarLarge)
         self.created = try container.decodeIfPresent(Int.self, forKey: .created)
         self.lastModified = try container.decodeIfPresent(Int.self, forKey: .lastModified)
         self.pro = try container.decodeIfPresent(Int.self, forKey: .pro)

         // 👇 重点：avatarNormal 需要兼容两个 key
         self.avatarNormal =
             try container.decodeIfPresent(String.self, forKey: .avatarNormal)
             ?? container.decodeIfPresent(String.self, forKey: .avatar)
     }
}
