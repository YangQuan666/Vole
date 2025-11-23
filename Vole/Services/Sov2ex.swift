//
//  Sov2ex.swift
//  Vole
//
//  Created by 杨权 on 11/22/25.
//

import Foundation

// MARK: - Response Models (响应模型)
struct SearchPagingState {
    // 固定的每页大小，作为我们发送给 API 的 size 参数
    let pageSize: Int = 20
    var totalResults: Int? = nil     // 从 API 的 total 字段获取
    var currentOffset: Int = 0       // 当前已加载的条数 (from)
}
/// 顶层响应结构
struct SoV2exResponse: Codable {
    let took: Int
    let timedOut: Bool
    let total: Int
    let hits: [SoV2exHit]

    enum CodingKeys: String, CodingKey {
        case took, total, hits
        case timedOut = "timed_out"
    }
}

/// 搜索结果单项
struct SoV2exHit: Codable, Identifiable {
    let source: SoV2exTopic
    let highlight: SoV2exHighlight?
    let id: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case source = "_source"
        case highlight
    }
}


/// 主题详情 (对应 _source)
struct SoV2exTopic: Codable {
    let id: Int
    let title: String
    let content: String
    let member: String
    let created: String  // ISO8601 格式字符串
    let replies: Int
    let node: Int
}

/// 高亮字段 (对应 highlight)
struct SoV2exHighlight: Codable {
    let title: [String]?
    let content: [String]?
    let postscriptContent: [String]?
    let replyContent: [String]?

    enum CodingKeys: String, CodingKey {
        case title, content
        case postscriptContent = "postscript_list.content"
        case replyContent = "reply_list.content"
    }
}

// MARK: - Request Parameters (请求参数封装)

enum SoV2exSort: String {
    case sumup  // 权重 (默认)
    case created  // 发帖时间
}

enum SoV2exOrder: Int {
    case descending = 0  // 降序 (默认)
    case ascending = 1  // 升序
}

enum SoV2exOperator: String {
    case or  // 默认
    case and
}

/// 搜索请求参数构建器
struct SoV2exSearchRequest {
    let q: String
    var from: Int = 0
    var size: Int = 10
    var sort: SoV2exSort? = nil
    var order: SoV2exOrder? = nil
    var gte: Int? = nil  // 最早发帖时间 (epoch second)
    var lte: Int? = nil  // 最晚发帖时间 (epoch second)
    var node: String? = nil
    var `operator`: SoV2exOperator? = nil
    var username: String? = nil

    /// 转换为 URLQueryItem 数组
    func toQueryItems() -> [URLQueryItem] {
        var items = [URLQueryItem(name: "q", value: q)]

        if from != 0 {
            items.append(URLQueryItem(name: "from", value: String(from)))
        }
        if size != 10 {
            items.append(URLQueryItem(name: "size", value: String(size)))
        }
        if let sort = sort {
            items.append(URLQueryItem(name: "sort", value: sort.rawValue))
        }
        if let order = order {
            items.append(
                URLQueryItem(name: "order", value: String(order.rawValue))
            )
        }
        if let gte = gte {
            items.append(URLQueryItem(name: "gte", value: String(gte)))
        }
        if let lte = lte {
            items.append(URLQueryItem(name: "lte", value: String(lte)))
        }
        if let node = node {
            items.append(URLQueryItem(name: "node", value: node))
        }
        if let op = `operator` {
            items.append(URLQueryItem(name: "operator", value: op.rawValue))
        }
        if let username = username {
            items.append(URLQueryItem(name: "username", value: username))
        }

        return items
    }
}

// MARK: - API Client (API 调用客户端)

class SoV2exService {
    private let baseURL = URL(string: "https://www.sov2ex.com/api/search")!

    public static let shared = SoV2exService()
    
    /// 执行搜索 (Async/Await)
    /// - Parameter request: 搜索参数对象
    /// - Returns: 搜索响应结果
    func search(_ request: SoV2exSearchRequest) async throws -> SoV2exResponse {
        // 1. 构建 URL
        var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: true
        )!
        components.queryItems = request.toQueryItems()

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        // 2. 创建请求
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        // 3. 发送网络请求
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // 4. 检查 HTTP 状态码
        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        // 5. 解析 JSON
        let decoder = JSONDecoder()
        // 如果需要处理日期，可以在这里配置 decoder.dateDecodingStrategy
        // 文档返回的是字符串 "2016-09-04T01:37:41"，默认 string 解析即可，后续可按需转换

        do {
            let result = try decoder.decode(SoV2exResponse.self, from: data)
            return result
        } catch {
            print("Decoding error: \(error)")
            throw error
        }
    }
}

// MARK: - Usage Example (使用示例)

// 假设在一个 View 或 ViewModel 中调用
func performSearchExample() {
    Task {
        let client = SoV2exService()

        // 创建搜索请求：搜索关键词 "Swift"，按时间排序
        let request = SoV2exSearchRequest(
            q: "Swift",
            size: 20,
            sort: .created,
            node: "create"  // 示例：指定节点
        )

        do {
            print("Starting search...")
            let response = try await client.search(request)

            print("搜索耗时: \(response.took)ms")
            print("命中总数: \(response.total)")

            for hit in response.hits {
                print("---")
                print("标题: \(hit.source.title)")
                print("作者: \(hit.source.member)")
                // 如果有高亮内容，优先显示高亮
                if let highlightTitle = hit.highlight?.title?.first {
                    print("高亮标题: \(highlightTitle)")
                }
            }

        } catch {
            print("Search failed: \(error.localizedDescription)")
        }
    }
}
