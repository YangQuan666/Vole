//
//  Node.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//
import Foundation

public struct Node: Identifiable, Decodable, Hashable {

    public var id: Int?
    public let name: String
    public let title: String?
    public let url: String?
    public let topics: Int?
    public let footer: String?
    public let header: String?
    public let titleAlternative: String?
    public let avatarMini: String?
    public let avatarNormal: String?
    public let avatarLarge: String?
    public let stars: Int?
    public let aliases: [String]?
    public let root: Bool?
    public let parentNodeName: String?

    enum CodingKeys: String, CodingKey {
        case name, stars, aliases, root, id, title, url, topics, footer, header
        case titleAlternative = "title_alternative"
        case avatarMini = "avatar_mini"
        case avatarNormal = "avatar_normal"
        case avatarLarge = "avatar_large"
        case parentNodeName = "parent_node_name"
    }
}
