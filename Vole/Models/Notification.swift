//
//  Notification.swift
//  Vole
//
//  Created by 杨权 on 7/27/25.
//

import Foundation

/**
 通知
 */
public struct Notification: Decodable, Identifiable, Hashable {
    public let id, memberID, forMemberID: Int?
    public let text, payload, payloadRendered: String?
    public let created: Int?
    public let member: Member?
    
    enum CodingKeys: String, CodingKey {
        case id
        case memberID = "member_id"
        case forMemberID = "for_member_id"
        case text, payload
        case payloadRendered = "payload_rendered"
        case created, member
    }
}
