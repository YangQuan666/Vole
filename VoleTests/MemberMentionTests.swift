import Foundation
import Testing
@testable import Vole

struct MemberMentionTests {
    @Test func mentionStopsBeforeChineseTextAndIgnoresCaseWhenDeduplicating() {
        #expect(
            MentionParser.usernames(in: "@livid谢谢 @Alice @ALICE @用户")
                == ["livid", "Alice"]
        )
    }

    @Test func mentionLinksToAuthorWithoutMatchingCase() {
        let replies = [
            makeReply(1, author: "livid", content: "第一条"),
            makeReply(2, author: "alice", content: "@LIVID谢谢收到"),
        ]

        let conversation = ReplyConversationIndex(replies: replies)
            .conversation(containing: 2)

        #expect(conversation?.items.map(\.reply.id) == [1, 2])
    }

    @Test func memberShowResponseHandlesFoundAndMissingUsers() throws {
        let found = try JSONDecoder().decode(
            MemberShowResponse.self,
            from: Data(#"{"id":492604,"username":"oligi","status":"found"}"#.utf8)
        )
        #expect(found.memberIfFound?.id == 492604)
        #expect(found.memberIfFound?.username == "oligi")

        let missing = try JSONDecoder().decode(
            MemberShowResponse.self,
            from: Data(#"{"status":"error","message":"Object Not Found"}"#.utf8)
        )
        #expect(missing.memberIfFound == nil)
    }
}

private func makeReply(_ id: Int, author: String, content: String) -> Reply {
    Reply(
        id: id,
        content: content,
        contentRendered: "",
        created: id,
        member: Member(
            id: id,
            username: author,
            url: nil,
            website: nil,
            twitter: nil,
            psn: nil,
            github: nil,
            btc: nil,
            location: nil,
            tagline: nil,
            bio: nil,
            avatar: nil,
            avatarMini: nil,
            avatarNormal: nil,
            avatarLarge: nil,
            avatarXLarge: nil,
            avatarXXLarge: nil,
            avatarXXXLarge: nil,
            created: nil,
            lastModified: nil,
            pro: nil
        )
    )
}
