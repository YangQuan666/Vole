//
//  UserManager.swift
//  Vole
//
//  Created by 杨权 on 9/9/25.
//

import Foundation

@MainActor
class UserManager: ObservableObject {
    static let shared = UserManager()
    private init() {
        // 启动时尝试加载
        let storedToken = KeychainHelper.shared.read()
        self.currentMember = nil
        self.token = storedToken
        self.didValidateStoredToken = storedToken == nil
        if storedToken == nil {
            UserDefaults.standard.removeObject(forKey: memberKey)
        } else {
            self.currentMember = loadMember()
        }
    }

    @Published var currentMember: Member?
    @Published var token: Token?
    @Published private(set) var didValidateStoredToken: Bool

    private let memberKey = "currentMember"

    func saveMember(_ member: Member) {
        if let data = try? JSONEncoder().encode(member) {
            UserDefaults.standard.set(data, forKey: memberKey)
            self.currentMember = member
        }
    }

    private func loadMember() -> Member? {
        guard let data = UserDefaults.standard.data(forKey: memberKey) else {
            return nil
        }
        return try? JSONDecoder().decode(Member.self, from: data)
    }

    @discardableResult
    func saveToken(_ token: Token) -> Bool {
        guard KeychainHelper.shared.save(token: token) else { return false }
        self.token = token
        return true
    }

    func refreshStoredTokenDetails() async {
        guard let token, let value = token.token else {
            didValidateStoredToken = true
            return
        }

        do {
            guard let response = try await V2exAPI.shared.token(token: value)
            else {
                didValidateStoredToken = true
                return
            }

            if response.success, let details = response.result {
                _ = saveToken(token.completed(with: details))
            } else if response.message == "Invalid token" {
                clear()
            }
        } catch {
            print("刷新 Token 详情失败：", error)
        }

        didValidateStoredToken = true
    }

    func renewToken() async throws {
        let response = try await V2exAPI.shared.createToken(
            expiration: Token.renewalExpiration,
            scope: "everything"
        )
        guard let response, response.success,
            let createdToken = response.result,
            let value = createdToken.token
        else {
            throw TokenRenewalError.api(
                response?.message ?? "无法创建新的 Token"
            )
        }

        let details = try? await V2exAPI.shared.token(token: value)?.result
        guard saveToken(createdToken.completed(with: details)) else {
            throw TokenRenewalError.keychain
        }
    }

    func clear() {
        _ = KeychainHelper.shared.delete()
        UserDefaults.standard.removeObject(forKey: memberKey)
        self.token = nil
        self.currentMember = nil
    }
    
    func search(name: String) async throws -> [Member] {
        guard !name.isEmpty else { return [] }
        let keyword = name.lowercased()
        let member = try await V2exAPI.shared.memberShow(username: keyword)
        if let m = member {
            return [m]
        }
        return []
    }
}

private enum TokenRenewalError: LocalizedError {
    case api(String)
    case keychain

    var errorDescription: String? {
        switch self {
        case .api(let message):
            return message
        case .keychain:
            return "新 Token 已创建，但无法保存到 Keychain"
        }
    }
}
