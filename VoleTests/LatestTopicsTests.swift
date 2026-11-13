import Foundation
import Testing
@testable import Vole

@MainActor
struct LatestTopicsTests {
    @Test func decodesV2LatestTopicIncludingAvatarsAndPagination() throws {
        let response = try JSONDecoder().decode(
            Response<[Topic]>.self, from: Data(latestTopicFixture.utf8)
        )
        let topic = try #require(response.result?.first)
        #expect(response.success)
        #expect(topic.id == 1255073)
        #expect(topic.title == "给小孩做了个游戏 15 分钟搞定了")
        #expect(topic.member?.username == "callmeZola")
        #expect(topic.member?.avatarNormal == nil)
        #expect(topic.member?.getHighestQualityAvatar() == topic.member?.avatar)
        #expect(topic.member?.getHighestQualityAvatar()?.hasPrefix("https://cdn.v2ex.com/gravatar/") == true)
        #expect(topic.node?.name == "promotions")
        #expect(topic.node?.title == "推广")
        #expect(topic.node?.getHighestQualityAvatar() == topic.node?.avatar)
        #expect(topic.contentRendered?.contains("https://plaingame.games") == true)
        #expect(topic.created == 1793961986)
        #expect(topic.replies == 0)
        #expect(response.pagination?.perPage == 20)
        #expect(response.pagination?.pages == 47459)
        #expect(response.pagination?.total == 949165)
    }

    @Test func stillDecodesV1AvatarAndFallsBackFromEmptyLegacyAvatar() throws {
        let v1 = try JSONDecoder().decode(
            [Topic].self,
            from: Data(#"[{"id":1,"member":{"username":"author","avatar_normal":"https://example.com/v1.png"}}]"#.utf8)
        )
        #expect(v1.first?.member?.getHighestQualityAvatar() == "https://example.com/v1.png")
        let v2 = try JSONDecoder().decode(
            Member.self,
            from: Data(#"{"username":"author","avatar_normal":"","avatar":"https://example.com/v2.png"}"#.utf8)
        )
        #expect(v2.getHighestQualityAvatar() == "https://example.com/v2.png")
    }

    @Test func guestLoadsOnceWithoutRequestingAnotherPage() async throws {
        var pages: [Int] = []
        let store = LatestTopicsStore { page, token in
            #expect(token == nil)
            pages.append(page)
            return try latestPage([3, 2], pages: 5)
        }
        await store.loadIfNeeded()
        await store.loadIfNeeded()
        await store.loadMore()
        #expect(pages == [1])
        #expect(store.currentPage == 1)
        #expect(!store.hasMore)
    }

    @Test func appendsUniqueTopicsAndStopsAtLastPage() async throws {
        var pages: [Int] = []
        let store = LatestTopicsStore { page, _ in
            pages.append(page)
            return try latestPage(page == 1 ? [3, 2] : [2, 1], pages: 2)
        }
        store.updateToken("account-a")
        await store.refresh()
        #expect(store.hasMore)
        await store.loadMore()
        await store.loadMore()
        #expect(pages == [1, 2])
        #expect(store.topics?.map(\.id) == [3, 2, 1])
        #expect(store.currentPage == 2)
        #expect(!store.hasMore)
    }

    @Test func missingPaginationStopsOnEmptyPage() async throws {
        var pages: [Int] = []
        let store = LatestTopicsStore { page, _ in
            pages.append(page)
            return try latestPage(page == 1 ? [3] : [], pages: nil)
        }
        store.updateToken("account-a")
        await store.refresh()
        await store.loadMore()
        await store.loadMore()
        #expect(pages == [1, 2])
        #expect(store.topics?.map(\.id) == [3])
        #expect(!store.hasMore)
    }

    @Test func failedNextPageRetainsTopicsAndRetriesTheSamePage() async throws {
        var pages: [Int] = []
        let store = LatestTopicsStore { page, _ in
            pages.append(page)
            if pages.count == 2 { throw URLError(.notConnectedToInternet) }
            return try latestPage(page == 1 ? [3, 2] : [1], pages: 3)
        }
        store.updateToken("account-a")
        await store.refresh()
        await store.loadMore()
        #expect(store.currentPage == 1)
        #expect(store.topics?.map(\.id) == [3, 2])
        #expect(store.errorMessage != nil)
        #expect(store.hasMore)
        await store.retry()
        #expect(pages == [1, 2, 2])
        #expect(store.currentPage == 2)
        #expect(store.topics?.map(\.id) == [3, 2, 1])
        #expect(store.errorMessage == nil)
    }

    @Test func failedRefreshRetriesFirstPageAndReplacesOldTopics() async throws {
        var pages: [Int] = []
        let store = LatestTopicsStore { page, _ in
            pages.append(page)
            if pages.count == 3 { throw URLError(.notConnectedToInternet) }
            return try latestPage(pages.count == 4 ? [9] : [3 - page], pages: 5)
        }
        store.updateToken("account-a")
        await store.refresh()
        await store.loadMore()
        await store.refresh()
        #expect(store.currentPage == 2)
        #expect(store.hasMore)
        #expect(store.errorMessage != nil)
        await store.retry()
        #expect(pages == [1, 2, 1, 1])
        #expect(store.topics?.map(\.id) == [9])
        #expect(store.currentPage == 1)
    }

    @Test func firstPageFailureShowsErrorAndCanBeRetried() async throws {
        var attempts = 0
        let store = LatestTopicsStore { _, _ in
            attempts += 1
            if attempts == 1 {
                return Response(success: false, message: "Invalid token", result: nil, pagination: nil)
            }
            return try latestPage([1], pages: 1)
        }
        store.updateToken("account-a")
        await store.loadIfNeeded()
        #expect(store.topics?.isEmpty == true)
        #expect(store.errorMessage == "Invalid token")
        #expect(!store.isLoading)
        await store.retry()
        #expect(store.topics?.map(\.id) == [1])
        #expect(store.errorMessage == nil)
    }

    @Test func cancelledRefreshPreservesAbilityToLoadNextPage() async throws {
        let pending = PendingLatestPages()
        let store = LatestTopicsStore(loadPage: pending.load)
        store.updateToken("account-a")
        let initial = Task { await store.refresh() }
        let first = await pending.nextRequest()
        first.succeed(try latestPage([3], pages: 3))
        await initial.value

        let refresh = Task { await store.refresh() }
        let cancelled = await pending.nextRequest()
        refresh.cancel()
        cancelled.fail(CancellationError())
        await refresh.value
        #expect(store.hasMore)
        #expect(store.currentPage == 1)
        #expect(store.topics?.map(\.id) == [3])
        #expect(store.errorMessage == nil)
        #expect(!store.isLoading)

        let more = Task { await store.loadMore() }
        let next = await pending.nextRequest()
        #expect(next.page == 2)
        next.succeed(try latestPage([2], pages: 3))
        await more.value
        #expect(store.topics?.map(\.id) == [3, 2])
    }

    @Test func refreshDiscardsOldPageAndConcurrentLoadMoreDoesNotDuplicateRequest() async throws {
        let pending = PendingLatestPages()
        let store = LatestTopicsStore(loadPage: pending.load)
        store.updateToken("account-a")
        let initial = Task { await store.refresh() }
        let first = await pending.nextRequest()
        first.succeed(try latestPage([3], pages: 3))
        await initial.value

        let more = Task { await store.loadMore() }
        let oldPage = await pending.nextRequest()
        await store.loadMore()
        #expect(pending.requestCount == 2)
        let refresh = Task { await store.refresh() }
        let freshPage = await pending.nextRequest()
        #expect(freshPage.page == 1)
        oldPage.succeed(try latestPage([2], pages: 3))
        await more.value
        #expect(store.isLoading)
        #expect(store.topics?.map(\.id) == [3])
        freshPage.succeed(try latestPage([9], pages: 2))
        await refresh.value
        #expect(store.topics?.map(\.id) == [9])
        #expect(store.currentPage == 1)
        #expect(!store.isLoading)
    }

    @Test func accountChangeAndLogoutDiscardOldRequestsAndResetPagination() async throws {
        let pending = PendingLatestPages()
        let store = LatestTopicsStore(loadPage: pending.load)
        store.updateToken("account-a")
        let old = Task { await store.refresh() }
        let oldRequest = await pending.nextRequest()
        #expect(oldRequest.token == "account-a")
        store.updateToken("account-b")
        #expect(store.topics == nil)
        #expect(store.currentPage == 0)
        let fresh = Task { await store.refresh() }
        let freshRequest = await pending.nextRequest()
        #expect(freshRequest.token == "account-b")
        oldRequest.succeed(try latestPage([1], pages: 2))
        await old.value
        #expect(store.topics == nil)
        #expect(store.isLoading)
        freshRequest.succeed(try latestPage([2], pages: 2))
        await fresh.value
        #expect(store.topics?.map(\.id) == [2])

        store.updateToken(nil)
        let guest = Task { await store.refresh() }
        let guestRequest = await pending.nextRequest()
        #expect(guestRequest.token == nil)
        #expect(guestRequest.page == 1)
        guestRequest.succeed(try latestPage([3], pages: nil))
        await guest.value
        #expect(store.topics?.map(\.id) == [3])
        #expect(!store.hasMore)
    }
}

private func latestPage(_ ids: [Int], pages: Int?) throws -> Response<[Topic]> {
    let topics = try JSONDecoder().decode(
        [Topic].self, from: JSONSerialization.data(withJSONObject: ids.map { ["id": $0] })
    )
    return Response(
        success: true, message: nil, result: topics,
        pagination: pages.map { Pagination(perPage: 20, total: $0 * 20, pages: $0) }
    )
}

@MainActor
private final class PendingLatestPages {
    struct Request {
        let page: Int
        let token: String?
        let continuation: CheckedContinuation<Response<[Topic]>?, Error>

        func succeed(_ response: Response<[Topic]>) {
            continuation.resume(returning: response)
        }

        func fail(_ error: Error) {
            continuation.resume(throwing: error)
        }
    }

    private var requests: [Request] = []
    private var waiter: CheckedContinuation<Request, Never>?
    private(set) var requestCount = 0

    func load(page: Int, token: String?) async throws -> Response<[Topic]>? {
        try await withCheckedThrowingContinuation { continuation in
            requestCount += 1
            let request = Request(page: page, token: token, continuation: continuation)
            if let waiter {
                self.waiter = nil
                waiter.resume(returning: request)
            } else {
                requests.append(request)
            }
        }
    }

    func nextRequest() async -> Request {
        if !requests.isEmpty { return requests.removeFirst() }
        return await withCheckedContinuation { waiter = $0 }
    }
}

private let latestTopicFixture = #"""
{
  "success": true,
  "message": "Latest topics found",
  "result": [{
    "id": 1255073,
    "title": "给小孩做了个游戏 15 分钟搞定了",
    "content": "https://plaingame.games",
    "content_rendered": "<p><a href=\"https://plaingame.games\" rel=\"nofollow\">https://plaingame.games</a></p>\n",
    "syntax": 1,
    "url": "https://www.v2ex.com/t/1255073",
    "replies": 0, "stars": 0, "thanks": 0, "last_reply_by": "",
    "created": 1793961986, "last_modified": 1793961986, "last_touched": 1793961806,
    "member": {
      "id": 836526, "username": "callmeZola", "bio": "",
      "website": "https://capafyai.com/", "github": null,
      "url": "https://www.v2ex.com/member/callmeZola",
      "avatar": "https://cdn.v2ex.com/gravatar/ce0235a41cf8148a918ad835b04423be?s=73&d=retro",
      "created": 1786193245, "pro": 0
    },
    "node": {
      "id": 864, "founder_id": 0, "url": "https://www.v2ex.com/go/promotions",
      "name": "promotions", "title": "推广", "header": "推广活动", "footer": "",
      "avatar": "https://cdn.v2ex.com/navatar/1fc2/1400/864_xxxlarge.png?m=1778522847",
      "topics": 15141, "created": 1438866283, "last_modified": 1778522847
    }
  }],
  "pagination": {"total": 949165, "pages": 47459, "per_page": 20}
}
"""#

@MainActor
struct LatestTopicsRequestTests {
    @Test func selectsVersionPassesPageAndHandlesFailures() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LatestTopicsURLProtocol.self]
        var api = V2exAPI()
        api.session = URLSession(configuration: configuration)
        defer { api.session.invalidateAndCancel() }

        LatestTopicsURLProtocol.respond(with: #"[{"id":1}]"#)
        let guest = try await api.latestTopics(page: 1, token: nil)
        #expect(guest?.result?.first?.id == 1)
        #expect(guest?.pagination == nil)
        let guestRequest = try #require(LatestTopicsURLProtocol.lastRequest)
        #expect(guestRequest.httpMethod == "GET")
        #expect(guestRequest.url?.path.hasSuffix("/api/topics/latest.json") == true)
        #expect(guestRequest.value(forHTTPHeaderField: "Authorization") == nil)

        LatestTopicsURLProtocol.respond(with: #"[{"id":2}]"#)
        _ = try await api.latestTopics(page: 1, token: "")
        #expect(LatestTopicsURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == nil)
        let count = LatestTopicsURLProtocol.requestCount
        let guestNext = try await api.latestTopics(page: 2, token: nil)
        #expect(guestNext == nil)
        #expect(LatestTopicsURLProtocol.requestCount == count)

        LatestTopicsURLProtocol.respond(with: latestTopicFixture)
        let secondPage = try await api.latestTopics(page: 2, token: "test-account-a")
        let request = try #require(LatestTopicsURLProtocol.lastRequest)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path.hasSuffix("/api/v2/topics/latest") == true)
        #expect(URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems == [URLQueryItem(name: "p", value: "2")])
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-account-a")
        #expect(secondPage?.pagination?.pages == 47459)

        LatestTopicsURLProtocol.respond(with: #"{"success":false,"message":"Invalid token"}"#)
        do {
            _ = try await api.latestTopics(page: 1, token: "test-account-a")
            Issue.record("An unsuccessful API response must throw")
        } catch let error as V2exAPIError {
            #expect(error.localizedDescription == "Invalid token")
        }

        LatestTopicsURLProtocol.respond(with: #"{"message":"Expired token"}"#, status: 401)
        do {
            _ = try await api.latestTopics(page: 1, token: "test-account-a")
            Issue.record("HTTP 401 must throw")
        } catch let V2exAPIError.httpFailure(status, method, _, _, message) {
            #expect(status == 401)
            #expect(method == "GET")
            #expect(message == "Expired token")
        }
    }
}

private final class LatestTopicsURLProtocol: URLProtocol {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var body = ""
        var status = 200
        var requests: [URLRequest] = []
    }

    private static let state = State()

    static var lastRequest: URLRequest? { state.lock.withLock { state.requests.last } }
    static var requestCount: Int { state.lock.withLock { state.requests.count } }

    static func respond(with body: String, status: Int = 200) {
        state.lock.withLock {
            state.body = body
            state.status = status
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (body, status) = Self.state.lock.withLock {
            Self.state.requests.append(request)
            return (Self.state.body, Self.state.status)
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
