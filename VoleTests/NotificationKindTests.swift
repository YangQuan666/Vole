import SwiftSoup
import Testing
@testable import Vole

struct NotificationKindTests {
    @Test func topicAndMemberLinksDoNotOverrideThanksAction() throws {
        let document = try SwiftSoup.parse(
            #"<a href="/member/收藏者">收藏者</a> 感谢了你发布的主题 <a href="/t/42" class="topic-link">关于打赏和收藏的主题</a>"#
        )

        let kind = try NotificationKind(document: document)

        #expect(kind == .thanks)
    }

    @Test func linkedTipTextAndTopicTitleDoNotOverrideTipAction() throws {
        let document = try SwiftSoup.parse(
            #"<a href="/member/打赏者">打赏者</a> 打赏了你 <a href="/solana/42">收藏</a> <a href="/t/42">感谢和收藏</a>"#
        )

        let kind = try NotificationKind(document: document)

        #expect(kind == .tip)
    }

    @Test func unrelatedActionDoesNotMatchKeywordsInTopicTitle() throws {
        let document = try SwiftSoup.parse(
            #"<a href="/member/member">member</a> 发布了新主题 <a href="/t/42">收藏、打赏和感谢</a>"#
        )

        let kind = try NotificationKind(document: document)

        #expect(kind == .notice)
    }
}
