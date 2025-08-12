//
//  Reply.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import Foundation

public struct Reply: Identifiable, Decodable, Hashable {

    public let id: Int
    public let content: String
    public let contentRendered: String
    public let created: Int
    public let member: Member

    enum CodingKeys: String, CodingKey {
        case id, content, created, member
        case contentRendered = "content_rendered"
    }
}
