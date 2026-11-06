//
//  ReportService.swift
//  Vole
//

import Foundation

enum ReportServiceError: LocalizedError {
    case notConfigured
    case requestFailed(Int?)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "举报通道未配置，请稍后再试"
        case .requestFailed(let statusCode):
            if let statusCode {
                return "提交失败（HTTP \(statusCode)），请稍后再试"
            }
            return "提交失败，请检查网络后重试"
        }
    }
}

/// 屏蔽 / 举报上报。
///
/// Webhook 地址从本地 `Secrets.plist`（已加入 .gitignore）的 `ReportWebhookURL` 读取，
/// 不再写在源码中。参考仓库根目录的 `Secrets.example.plist`。
struct ReportService {
    static let shared = ReportService()

    private let webhookURL: URL? = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url),
            let value = dict["ReportWebhookURL"] as? String,
            !value.isEmpty
        else { return nil }
        return URL(string: value)
    }()

    func blockTopic(_ topic: Topic, reporter: String?) async throws {
        try await send("""
            用户屏蔽内容
            ID: \(topic.id)
            标题: \(topic.title ?? "未知")
            作者: \(topic.member?.username ?? "")
            操作用户: \(reporter ?? "未知")
            """)
    }

    func blockUser(_ member: Member, reporter: String?) async throws {
        try await send("""
            用户屏蔽成员
            被屏蔽用户: \(member.username)
            操作用户: \(reporter ?? "未知")
            """)
    }

    func report(_ topic: Topic, reason: String) async throws {
        try await send("""
            --用户举报内容--
            ID: \(topic.id)
            标题: \(topic.title ?? "未知")
            作者: \(topic.member?.username ?? "")
            举报原因: \(reason)
            """)
    }

    private func send(_ content: String) async throws {
        guard let webhookURL else { throw ReportServiceError.notConfigured }

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["content": content]
        )

        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ReportServiceError.requestFailed(nil)
        }
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        guard let statusCode, (200..<300).contains(statusCode) else {
            throw ReportServiceError.requestFailed(statusCode)
        }
    }
}
