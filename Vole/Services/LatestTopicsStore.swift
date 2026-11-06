import Combine
import Foundation

@MainActor
final class LatestTopicsStore: ObservableObject {
    typealias PageLoader = (Int, String?) async throws -> Response<[Topic]>?

    @Published private(set) var topics: [Topic]?
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var contentVersion = 0
    private(set) var currentPage = 0

    private var token: String?
    private var requestID: UUID?
    private var failedPage: Int?
    private let loadPage: PageLoader

    init(loadPage: @escaping PageLoader = { page, token in
        try await V2exAPI.shared.latestTopics(page: page, token: token)
    }) {
        self.loadPage = loadPage
    }

    func updateToken(_ value: String?) {
        let value = value.flatMap { $0.isEmpty ? nil : $0 }
        guard token != value else { return }
        token = value
        requestID = nil
        topics = nil
        currentPage = 0
        hasMore = false
        isLoading = false
        errorMessage = nil
        failedPage = nil
    }

    func loadIfNeeded() async {
        guard topics == nil, !isLoading else { return }
        await refresh()
    }

    func refresh() async {
        await load(page: 1)
    }

    func loadMore() async {
        guard hasMore, token != nil, currentPage > 0 else { return }
        await load(page: currentPage + 1)
    }

    func retry() async {
        await load(page: failedPage ?? 1)
    }

    private func load(page: Int) async {
        // Refresh may replace an older request; only its result can update the list.
        guard page == 1 || !isLoading else { return }
        let id = UUID()
        requestID = id
        isLoading = true
        errorMessage = nil
        failedPage = nil
        defer {
            if requestID == id {
                isLoading = false
                requestID = nil
            }
        }

        do {
            let response = try await loadPage(page, token)
            try Task.checkCancellation()
            guard requestID == id else { return }
            guard let response, response.success, let pageTopics = response.result else {
                throw V2exAPIError.apiFailure(
                    message: response?.message ?? "加载最新主题失败"
                )
            }

            var seen = Set<Int>()
            let combined = page == 1 ? pageTopics : (topics ?? []) + pageTopics
            topics = combined.filter { seen.insert($0.id).inserted }
            currentPage = page
            hasMore = token != nil && !pageTopics.isEmpty
                && (response.pagination.map { page < $0.pages } ?? true)
            contentVersion += 1
        } catch {
            guard requestID == id else { return }
            if error is CancellationError || Task.isCancelled { return }
            if topics == nil { topics = [] }
            errorMessage = error.localizedDescription
            failedPage = page
        }
    }
}
