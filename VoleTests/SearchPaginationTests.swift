import Testing
@testable import Vole

struct SearchPaginationTests {
    @Test func appendingOverlappingHitsKeepsOneResultPerTopic() {
        let firstPage = [hit(topicID: 3), hit(topicID: 2), hit(topicID: 2)]
        let nextPage = [hit(topicID: 2), hit(topicID: 1), hit(topicID: 1)]

        let result = SearchPagination.appendingUnique(nextPage, to: firstPage)

        #expect(result.map(\.source.id) == [3, 2, 1])
    }

    @Test func paginationOffsetAdvancesByFetchedRowsEvenWhenTheyOverlap() {
        #expect(
            SearchPagination.nextOffset(
                currentOffset: 20,
                fetchedCount: 20,
                totalCount: 100
            ) == 40
        )
        #expect(
            SearchPagination.nextOffset(
                currentOffset: 40,
                fetchedCount: 0,
                totalCount: 100
            ) == 100
        )
    }
}

private func hit(topicID: Int) -> SoV2exHit {
    SoV2exHit(
        source: SoV2exTopic(
            id: topicID,
            title: "Topic \(topicID)",
            content: "",
            member: "member",
            created: "2026-11-13T00:00:00Z",
            replies: 0,
            node: 1
        ),
        highlight: nil,
        id: "document-\(topicID)"
    )
}
