//
//  Response.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import Foundation

/// V2EX API Response
public struct Response<T: Decodable & Sendable>: Decodable, Sendable {
    public let success: Bool
    public let message: String?
    public let result: T?
    public let pagination: Pagination?
}

public struct APIWriteResponse<T: Decodable>: Decodable {
    public let success: Bool
    public let message: String?
    public let result: T?

    private enum CodingKeys: String, CodingKey {
        case success, message, result
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.success) || container.contains(.result)
            || container.contains(.message)
        {
            success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
            message = try container.decodeIfPresent(String.self, forKey: .message)
            result = try container.decodeIfPresent(T.self, forKey: .result)
        } else {
            success = true
            message = nil
            result = try T(from: decoder)
        }
    }
}

public enum JSONValue: Decodable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }
}
