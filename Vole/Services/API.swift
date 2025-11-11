//
//  API.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import Foundation

public struct V2exAPI {

    private let endpointV1 = "https://v2ex.com/api/"
    private let endpointV2 = "https://www.v2ex.com/api/v2/"

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
        token: String? = nil
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

        if let t = token {
            request.setValue(
                "Bearer " + t,
                forHTTPHeaderField: "Authorization"
            )
        } else if let accessToken = UserManager.shared.token, let t = accessToken.token {
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

        if let remainingStr = httpResponse.value(
            forHTTPHeaderField: "X-Rate-Limit-Remaining"
        ),
            let remaining = Int(remainingStr),
            remaining == 0
        {
            // 已经没有额度了，直接返回
            throw URLError(.resourceUnavailable)
        }
        let decoder = JSONDecoder()

        let obj = try decoder.decode(decodeClass.self, from: data)

        return obj
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
     最新主题
     */
    public func latestTopics() async throws -> [Topic]? {
        return try await request(
            url: endpointV1 + "topics/latest.json",
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

        return try await request(
            url: endpointV1 + "members/show.json",
            args: args,
            decodeClass: Member.self
        )
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

    // =========== V2 ===========

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
            //            useAuth: true
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
    public func notifications(page: Int = 1) async throws -> Response<
        [Notification]?
    >? {
        let path = "notifications"
        return try await request(
            url: endpointV2 + path,
            args: [
                "p": String(page)
            ],
            decodeClass: Response<[Notification]?>.self
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
    public func member() async throws -> Response<Member>? {
        let path = "member"
        return try await request(
            url: endpointV2 + path,
            decodeClass: Response<Member>.self
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
        let path = "token"
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
}
