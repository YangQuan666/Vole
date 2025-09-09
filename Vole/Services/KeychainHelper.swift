//
//  KeychainHelper.swift
//  Vole
//
//  Created by 杨权 on 9/8/25.
//

import Foundation
import Security

class KeychainHelper {

    static let shared = KeychainHelper()
    private init() {}

    private let service = "quark.yeung.Vole"
    private let account = "currentUser"

    // 保存 Token 对象
    func save(token: Token) -> Bool {
        guard let data = try? JSONEncoder().encode(token) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    // 读取 Token 对象
    func read() -> Token? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return try? JSONDecoder().decode(Token.self, from: data)
        }
        return nil
    }

    // 删除 Token
    func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
