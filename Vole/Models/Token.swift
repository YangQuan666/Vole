//
//  Token.swift
//  Vole
//
//  Created by 杨权 on 7/27/25.
//

import Foundation

public struct Token: Decodable, Equatable, Hashable {
    public let token, scope: String?
    public let expiration, goodForDays, totalUsed, lastUsed: Int?
    public let created: Int?
    
    enum CodingKeys: String, CodingKey {
        case token, scope, expiration
        case goodForDays = "good_for_days"
        case totalUsed = "total_used"
        case lastUsed = "last_used"
        case created
    }
}
