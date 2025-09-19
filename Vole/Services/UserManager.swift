//
//  UserManager.swift
//  Vole
//
//  Created by 杨权 on 9/9/25.
//

import Foundation

class UserManager: ObservableObject {
    static let shared = UserManager()
    private init() {
        // 启动时尝试加载
        self.currentMember = loadMember()
        self.token = KeychainHelper.shared.read()
    }

    @Published var currentMember: Member?
    @Published var token: Token?

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

    func saveToken(_ token: Token) {
        if KeychainHelper.shared.save(token: token) {
            self.token = token
        }
    }

    func clear() {
        _ = KeychainHelper.shared.delete()
        UserDefaults.standard.removeObject(forKey: memberKey)
        self.token = nil
        self.currentMember = nil
    }
}
