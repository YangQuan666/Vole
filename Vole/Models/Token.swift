//
//  Token.swift
//  Vole
//
//  Created by 杨权 on 7/27/25.
//

import Foundation

public struct Token: Decodable, Encodable, Equatable, Hashable, Sendable {
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

extension Token {
    static let renewalExpiration = 15_552_000
    static let renewalDays = 180
    static let warningDays = 7

    var expiresAt: Date? {
        guard let created, let expiration else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(created + expiration))
    }

    var needsRenewalWarning: Bool {
        expires(withinDays: Self.warningDays)
    }

    var remainingDays: Int? {
        guard let expiresAt else { return nil }
        let remaining = max(0, expiresAt.timeIntervalSinceNow)
        return Int((remaining / 86_400).rounded())
    }

    func expires(withinDays days: Int, now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) <= TimeInterval(days * 86_400)
    }

    func completed(with details: Token?) -> Token {
        Token(
            token: details?.token ?? token,
            scope: details?.scope ?? scope ?? "everything",
            expiration:
                details?.expiration ?? expiration ?? Self.renewalExpiration,
            goodForDays:
                details?.goodForDays ?? goodForDays ?? Self.renewalDays,
            totalUsed: details?.totalUsed ?? totalUsed,
            lastUsed: details?.lastUsed ?? lastUsed,
            created:
                details?.created ?? created
                ?? Int(Date().timeIntervalSince1970)
        )
    }

    func withRawToken(_ rawToken: String) -> Token {
        Token(
            token: rawToken,
            scope: scope,
            expiration: expiration,
            goodForDays: goodForDays,
            totalUsed: totalUsed,
            lastUsed: lastUsed,
            created: created
        )
    }
}
