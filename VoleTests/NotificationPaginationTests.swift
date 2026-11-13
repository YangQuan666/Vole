import Testing
@testable import Vole

struct NotificationPaginationTests {
    @Test func refreshWithNewNotificationsLoadsThePartiallyCoveredPageNext() {
        let loadedCount = 34
        let pageSize = 10

        let currentPage = NotificationPagination.lastFullyLoadedPage(
            loadedCount: loadedCount,
            pageSize: pageSize
        )

        #expect(currentPage == 3)
        #expect(currentPage + 1 == 4)
    }

    @Test func exactPageBoundaryKeepsTheNextPageSequential() {
        let currentPage = NotificationPagination.lastFullyLoadedPage(
            loadedCount: 30,
            pageSize: 10
        )

        #expect(currentPage == 3)
        #expect(currentPage + 1 == 4)
    }

    @Test func appendingOverlappingPageDoesNotDuplicateNotifications() {
        let existing = (101...134).reversed().map(notification)
        let overlappingPage = stride(from: 104, through: 95, by: -1).map(notification)

        let result = NotificationPagination.appendingUnique(
            overlappingPage,
            to: existing
        )

        #expect(result.count == 40)
        #expect(Set(result.map(\.id)).count == result.count)
        #expect(Array(result.suffix(6).map(\.id)) == [100, 99, 98, 97, 96, 95])
    }

    @Test func appendingPageAlsoRemovesDuplicatesAlreadyInLoadedRows() {
        let loaded = [notification(3), notification(2), notification(2)]
        let page = [notification(2), notification(1), notification(1)]

        let result = NotificationPagination.appendingUnique(page, to: loaded)

        #expect(result.map(\.id) == [3, 2, 1])
    }

    @Test func paginationCursorHandlesEmptyPageSize() {
        #expect(NotificationPagination.lastFullyLoadedPage(loadedCount: 0, pageSize: 0) == 1)
    }

    private func notification(_ id: Int) -> Notification {
        Notification(
            id: id,
            memberID: nil,
            forMemberID: nil,
            text: nil,
            payload: nil,
            payloadRendered: nil,
            created: nil,
            member: nil
        )
    }
}
