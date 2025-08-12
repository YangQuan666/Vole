//
//  Response.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import Foundation

/// V2EX API Response
public struct Response<T: Decodable>: Decodable {
    public let success: Bool
    public let message: String?
    public let result: T
}
