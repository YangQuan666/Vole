import Foundation
import Testing
@testable import Vole

struct SoV2exSearchRequestTests {
    @Test func plusSignsArePercentEncodedInSearchQuery() throws {
        let request = SoV2exSearchRequest(q: "C++")
        let url = try request.makeURL(
            baseURL: URL(string: "https://www.sov2ex.com/api/search")!
        )

        #expect(url.absoluteString.contains("q=C%2B%2B"))
        let queryItems = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        )
        #expect(queryItems.first(where: { $0.name == "q" })?.value == "C++")
    }
}
