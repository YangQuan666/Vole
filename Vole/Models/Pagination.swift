//
//  Pagination.swift
//  Vole
//
//  Created by 杨权 on 11/11/25.
//

import Foundation

public struct Pagination: Decodable, Sendable {
    public let perPage: Int
    public let total: Int
    public let pages: Int

    enum CodingKeys: String, CodingKey {
        case total, pages
        case perPage = "per_page"
    }
}
