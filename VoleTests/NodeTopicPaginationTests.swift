import Testing
@testable import Vole

struct NodeTopicPaginationTests {
    @Test func appendingOverlappingPagesKeepsOneTopicPerID() {
        let firstPage = [topic(3), topic(2), topic(2)]
        let nextPage = [topic(2), topic(1), topic(1)]

        let result = NodeTopicPagination.appendingUnique(nextPage, to: firstPage)

        #expect(result.map(\.id) == [3, 2, 1])
    }

    @Test func firstPageAlsoRemovesDuplicates() {
        #expect(NodeTopicPagination.unique([topic(1), topic(1)]).map(\.id) == [1])
    }
}

private func topic(_ id: Int) -> Topic {
    Topic(
        id: id,
        node: nil,
        member: nil,
        title: "Topic \(id)",
        url: nil,
        created: nil,
        deleted: nil,
        content: nil,
        contentRendered: nil,
        syntax: nil,
        lastModified: nil,
        replies: nil,
        stars: nil,
        thanks: nil,
        lastReplyBy: nil,
        lastTouched: nil,
        supplements: nil
    )
}
