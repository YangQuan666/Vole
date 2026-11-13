//
//  API.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import Foundation

enum V2exAPIError: LocalizedError {
    case apiFailure(message: String)
    case httpFailure(
        statusCode: Int,
        method: String,
        url: String,
        allowedMethods: String?,
        message: String?
    )
    case invalidResponse(statusCode: Int, details: String, body: String)

    var errorDescription: String? {
        switch self {
        case let .apiFailure(message):
            return message
        case let .httpFailure(statusCode, method, url, allowedMethods, message):
            let allowed = allowedMethods.map { "；允许的方法：\($0)" } ?? ""
            return "请求失败（HTTP \(statusCode)）：\(method) \(url)\(allowed)\n\(message ?? "服务器未提供错误说明")"
        case let .invalidResponse(statusCode, details, body):
            return "服务器返回的数据无法解析（HTTP \(statusCode)）。\(details)\n响应：\(body)"
        }
    }
}

struct MemberShowResponse: Decodable {
    let status: String?
    let message: String?
    let member: Member?

    var memberIfFound: Member? {
        guard status != "error", message != "Object Not Found" else {
            return nil
        }
        return member
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        member = try? Member(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case status, message
    }
}

public struct V2exAPI: Sendable {

    private var endpointV1: String { SiteConfiguration.endpointV1 }
    private var endpointV2: String { SiteConfiguration.endpointV2 }

    public static let shared = V2exAPI()

    public var session = URLSession.shared
    /**
     HTTP 请求
     */
    private func request<T>(
        httpMethod: String = "GET",
        url: String,
        args: [String: Any]? = nil,
        decodeClass: T.Type,
        token: String? = nil,
        useStoredToken: Bool = true
    ) async throws -> (
        T?
    ) where T: Decodable {
        let urlComponents = NSURLComponents(string: url)!

        if httpMethod != "POST" && args != nil {
            urlComponents.queryItems =
                args?.map({ (k, v) in
                    return NSURLQueryItem(name: k, value: "\(v)")
                }) as [URLQueryItem]?
        }

        guard let requestUrl = urlComponents.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = httpMethod
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let authenticationToken: String?
        if let token {
            authenticationToken = token
        } else if useStoredToken {
            authenticationToken = await MainActor.run { UserManager.shared.token?.token }
        } else {
            authenticationToken = nil
        }
        if let t = authenticationToken {
            request.setValue(
                "Bearer " + t,
                forHTTPHeaderField: "Authorization"
            )
        }

        if httpMethod == "POST" && args != nil {
            request.httpBody = try? JSONSerialization.data(
                withJSONObject: args as Any
            )
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            // 请求失败
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw V2exAPIError.httpFailure(
                statusCode: httpResponse.statusCode,
                method: request.httpMethod ?? httpMethod,
                url: httpResponse.url?.absoluteString ?? requestUrl.absoluteString,
                allowedMethods: httpResponse.value(forHTTPHeaderField: "Allow"),
                message: Self.serverMessage(from: data)
            )
        }

        let decoder = JSONDecoder()
        let obj: T
        do {
            obj = try decoder.decode(decodeClass.self, from: data)
        } catch let error as DecodingError {
            throw V2exAPIError.invalidResponse(
                statusCode: httpResponse.statusCode,
                details: error.localizedDescription,
                body: Self.responsePreview(from: data)
            )
        }

        return obj
    }

    private static func serverMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data),
            let object = json as? [String: Any]
        else {
            return responsePreview(from: data)
        }

        for key in ["message", "error", "detail"] {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }
        return responsePreview(from: data)
    }

    private static func responsePreview(from data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
        else {
            return "响应内容为空或不是 UTF-8 文本"
        }
        return String(text.prefix(240))
    }

    // =========== V1 ===========

    /**
     获取节点列表
     */
    public func nodesList(
        fields: [String]? = nil,
        sortBy: String = "topics",
        reverse: String = "1"
    ) async throws -> [Node]? {
        var fieldsList = ["id", "name", "title", "url", "topics", "stars", "aliases", "parent_node_name", "avatar_large", "header"]
        if let fields {
            fieldsList = fields
        }
        return try await request(
            url: endpointV1 + "nodes/list.json",
            args: [
                "fields": fieldsList.joined(separator: ","),
                "sort_by": sortBy,
                "reverse": reverse,
            ],
            decodeClass: [Node].self
        )
    }

    /**
     最热主题
     */
    public func hotTopics() async throws -> [Topic]? {
        return try await request(
            url: endpointV1 + "topics/hot.json",
            decodeClass: [Topic].self
        )
    }

    /**
     节点信息
    
     获得指定节点的名字，简介，URL 及头像图片的地址。
    
     - parameter  name: 节点名（V2EX 的节点名全是半角英文或者数字）
     */
    public func nodesShow(name: String) async throws -> Node? {
        return try await request(
            url: endpointV1 + "nodes/show.json",
            args: [
                "name": name
            ],
            decodeClass: Node.self
        )
    }

    /**
     用户主页
    
     获得指定用户的自我介绍，及其登记的社交网站信息。
    
     - parameter  username: 用户名
     - parameter  id: 用户在 V2EX 的数字 ID
     */
    public func memberShow(username: String? = nil, id: Int? = nil) async throws
        -> Member?
    {
        var args: [String: String] = [:]
        if let username = username {
            args["username"] = username
        }
        if let id = id {
            args["id"] = String(id)
        }

        if args.isEmpty {
            return nil
        }

        do {
            let response = try await request(
                url: endpointV1 + "members/show.json",
                args: args,
                decodeClass: MemberShowResponse.self
            )
            return response?.memberIfFound
        } catch let V2exAPIError.httpFailure(_, _, _, _, message)
            where message == "Object Not Found"
        {
            return nil
        }
    }

    /**
     获取指定主题下的回复列表
    
     - parameter  topicId: 主题ID
     */
    public func repliesAll(topicId: Int) async throws -> [Reply]? {
        let path = "replies/show.json"
        return try await request(
            url: endpointV1 + path,
            args: [
                "topic_id": topicId
            ],
            decodeClass: [Reply].self
        )
    }

    /**
     获取节点下的主题列表
    
     - parameter  topicId: 主题ID
     */
    public func topics(nodeName: String) async throws -> [Topic]? {
        let path = "topics/show.json"
        return try await request(
            url: endpointV1 + path,
            args: [
                "node_name": nodeName
            ],
            decodeClass: [Topic].self
        )
    }

    /**
     获取指定主题

     V1 `topics/show.json` 按 `id` 查询时返回的仍然是数组，
     这里保持和原始接口一致。

     - parameter topicId: 主题ID
     */
    public func topicV1(topicId: Int) async throws -> [Topic]? {
        let path = "topics/show.json"
        return try await request(
            url: endpointV1 + path,
            args: [
                "id": topicId
            ],
            decodeClass: [Topic].self
        )
    }

    // =========== V2 ===========

    /**
     最新主题，未登录时使用 V1
     - parameter page: V2 分页页码，默认为 1；V1 仅支持第一页
     */
    public func latestTopics(page: Int = 1) async throws -> Response<[Topic]>? {
        let token = await MainActor.run { UserManager.shared.token?.token }
        return try await latestTopics(page: page, token: token)
    }

    func latestTopics(page: Int, token: String?) async throws -> Response<[Topic]>? {
        guard let token, !token.isEmpty else {
            guard page == 1 else { return nil }
            let topics = try await request(
                url: endpointV1 + "topics/latest.json",
                decodeClass: [Topic].self,
                useStoredToken: false
            )
            return Response(
                success: true, message: nil, result: topics, pagination: nil
            )
        }

        let response = try await request(
            url: endpointV2 + "topics/latest",
            args: ["p": page],
            decodeClass: Response<[Topic]>.self,
            token: token,
            useStoredToken: false
        )
        if let response, !response.success {
            throw V2exAPIError.apiFailure(
                message: response.message ?? "加载最新主题失败"
            )
        }
        return response
    }

    /**
     获取指定节点下的主题
    
     - parameter  nodeName: 节点名，如 "swift"
     - parameter  page: 分页页码，默认为 1
     */
    public func topics(nodeName: String, page: Int = 1) async throws
        -> Response<[Topic]>?
    {
        let path = "nodes/\(nodeName)/topics"
        return try await request(
            url: endpointV2 + path,
            args: [
                "p": String(page)
            ],
            decodeClass: Response<[Topic]>.self,
        )
    }

    /**
     获取指定主题下的回复
    
     - parameter  topicId: 主题ID
     - parameter  page: 分页页码，默认为 1
     */
    public func replies(topicId: Int, page: Int = 1) async throws -> Response<
        [Reply]?
    >? {
        let path = "topics/\(topicId)/replies"
        return try await request(
            url: endpointV2 + path,
            args: [
                "p": String(page)
            ],
            decodeClass: Response<[Reply]?>.self
        )
    }

    /**
     获取指定主题
    
     - parameter  topicId: 主题ID
     */
    public func topic(topicId: Int) async throws -> Response<Topic?>? {
        let path = "topics/\(topicId)"
        return try await request(
            url: endpointV2 + path,
            decodeClass: Response<Topic?>.self,
            //            token: accessToken
        )
    }

    /**
     获取指定节点
    
     - parameter  nodeName: 节点名
     */
    public func getNode(nodeName: String) async throws -> Response<Node?>? {
        let path = "nodes/\(nodeName)"
        return try await request(
            url: endpointV2 + path,
            decodeClass: Response<Node?>.self
        )
    }

    /**
     获取最新的提醒
    
     - parameter  page: 分页页码，默认为 1
     */
    public func notifications(page: Int = 1, token: String) async throws -> Response<
        [Notification]
    >? {
        let path = "notifications"
        return try await request(
            url: endpointV2 + path,
            args: [
                "p": String(page)
            ],
            decodeClass: Response<[Notification]>.self,
            token: token
        )
    }

    /**
     获取最新的提醒
    
     - parameter  notification_id: 提醒ID
     */
    public func deleteNotification(notificationId: Int) async throws
        -> Response<Data>?
    {
        let path = "notifications/\(notificationId)"
        return try await request(
            httpMethod: "DELETE",
            url: endpointV2 + path,
            decodeClass: Response<Data>.self
        )
    }

    /**
     获取自己的 Profile
     */
    public func member(token: String? = nil) async throws -> Response<Member>? {
        let path = "member"
        return try await request(
            url: endpointV2 + path,
            decodeClass: Response<Member>.self,
            token: token
        )
    }

    /**
     查看当前使用的令牌
     */
    public func token(token: String) async throws -> Response<Token>? {
        let path = "token"
        return try await request(
            url: endpointV2 + path,
            decodeClass: Response<Token>.self,
            token: token
        )
    }

    /**
     创建新的令牌
    
     你可以在系统中最多创建 10 个 Personal Access Token。
    
     - parameter  scope: 可选 everything 或者 regular，如果是 regular 类型的 Token 将不能用于进一步创建新的 token
     - parameter  expiration: 可支持的值：2592000，5184000，7776000 或者 15552000，即 30 天，60 天，90 天或者 180 天的秒数
     */
    public func createToken(expiration: Int, scope: String? = nil) async throws
        -> Response<Token>?
    {
        let path = "tokens"
        var args: [String: Any] = ["expiration": expiration]
        if let scope = scope {
            args["scope"] = scope
        }

        return try await request(
            httpMethod: "POST",
            url: endpointV2 + path,
            args: args,
            decodeClass: Response<Token>.self
        )
    }

    /// 创建主题
    public func createTopic(
        nodeName: String,
        title: String,
        content: String? = nil,
        syntax: String = "markdown"
    ) async throws -> APIWriteResponse<Topic>? {
        var args: [String: Any] = [
            "node_name": nodeName,
            "title": title,
            "syntax": syntax,
        ]
        if let content, !content.isEmpty {
            args["content"] = content
        }

        return try await request(
            httpMethod: "POST",
            url: endpointV2 + "topics",
            args: args,
            decodeClass: APIWriteResponse<Topic>.self
        )
    }

    /// 创建主题回复
    public func createReply(topicId: Int, content: String) async throws
        -> APIWriteResponse<JSONValue>?
    {
        return try await request(
            httpMethod: "POST",
            url: endpointV2 + "topics/\(topicId)/replies",
            args: ["content": content],
            decodeClass: APIWriteResponse<JSONValue>.self
        )
    }
}
