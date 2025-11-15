//
//  Topic.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import Foundation

public struct Topic: Identifiable, Decodable, Hashable {
    public let id: Int
    public var node: Node?
    public let member: Member?
    public let title: String?
    public let url: String?
    public let created: Int?
    public let deleted: Int?
    public let content: String?
    public let contentRendered: String?
    public let syntax: Int?
    public let lastModified: Int?
    public let replies: Int?
    public let lastReplyBy: String?
    public let lastTouched: Int?
    public let supplements: [Supplement]?

    enum CodingKeys: String, CodingKey {
        case node, member, supplements, title, url, created, deleted, content,
            replies, id, syntax
        case lastReplyBy = "last_reply_by"
        case lastTouched = "last_touched"
        case lastModified = "last_modified"
        case contentRendered = "content_rendered"
    }
}

public struct Supplement: Identifiable, Decodable, Hashable {
    public let id: Int
    public let content: String?
    public let contentRendered: String?
    public let syntax: Int?
    public let created: Int?

    enum CodingKeys: String, CodingKey {
        case id, content, syntax, created
        case contentRendered = "content_rendered"
    }
}
