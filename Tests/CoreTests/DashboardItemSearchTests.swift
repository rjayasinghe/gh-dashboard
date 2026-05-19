import XCTest

@testable import Core

final class DashboardItemSearchTests: XCTestCase {
    private func item(
        id: String = "1",
        number: Int = 1,
        title: String = "Title",
        repo: String = "org/repo",
        author: String = "alice",
        body: String = "",
        host: String = "github.com",
        section: DashboardSection = .myPRs,
        labels: [String] = [],
        updatedAt: Date = Date(timeIntervalSince1970: 100)
    ) -> DashboardItem {
        DashboardItem(
            id: id,
            number: number,
            title: title,
            body: body,
            url: "https://github.com/\(repo)/pull/\(number)",
            host: host,
            repo: repo,
            state: .open,
            isDraft: false,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            author: author,
            labels: labels,
            section: section,
            comments: [],
            reviewStatus: nil
        )
    }

    func testParseTermsTrimsAndLowercases() {
        XCTAssertEqual(DashboardItemSearch.parseTerms(from: "  Foo BAR "), ["foo", "bar"])
    }

    func testParseTermsEmptyQuery() {
        XCTAssertTrue(DashboardItemSearch.parseTerms(from: "   ").isEmpty)
    }

    func testHaystackIncludesNumberAndSection() {
        let h = DashboardItemSearch.haystack(for: item(number: 42, title: "Fix bug", section: .reviewNeeded))
        XCTAssertTrue(h.contains("fix bug"))
        XCTAssertTrue(h.contains("#42"))
        XCTAssertTrue(h.contains("review needed"))
    }

    func testMatchesAllTerms() {
        let i = item(title: "Widget alignment fix", repo: "org/widgets", author: "bob")
        XCTAssertTrue(DashboardItemSearch.matches(item: i, terms: ["widget", "bob"]))
        XCTAssertFalse(DashboardItemSearch.matches(item: i, terms: ["widget", "carol"]))
    }

    func testSearchFiltersByVisibleSection() {
        let items = [
            item(id: "pr", section: .myPRs, title: "shared keyword"),
            item(id: "issue", section: .myIssues, title: "shared keyword"),
        ]
        let results = DashboardItemSearch.search(
            items: items,
            visibleSections: [.myPRs],
            query: "shared"
        )
        XCTAssertEqual(results.map(\.id), ["pr"])
    }

    func testSearchSortsByUpdatedAtNewestFirst() {
        let older = item(id: "old", title: "needle", updatedAt: Date(timeIntervalSince1970: 100))
        let newer = item(id: "new", title: "needle", updatedAt: Date(timeIntervalSince1970: 200))
        let results = DashboardItemSearch.search(
            items: [older, newer],
            visibleSections: DashboardSection.allCases,
            query: "needle"
        )
        XCTAssertEqual(results.map(\.id), ["new", "old"])
    }

    func testSearchRespectsLimit() {
        let items = (1...5).map { n in
            item(id: "\(n)", number: n, title: "match", updatedAt: Date(timeIntervalSince1970: TimeInterval(n)))
        }
        let results = DashboardItemSearch.search(
            items: items,
            visibleSections: DashboardSection.allCases,
            query: "match",
            limit: 2
        )
        XCTAssertEqual(results.count, 2)
    }

    func testSearchEmptyQueryReturnsEmpty() {
        let results = DashboardItemSearch.search(
            items: [item()],
            visibleSections: DashboardSection.allCases,
            query: ""
        )
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchMatchesLabel() {
        let i = item(labels: ["bug", "regression"])
        XCTAssertTrue(
            DashboardItemSearch.search(
                items: [i],
                visibleSections: DashboardSection.allCases,
                query: "regression"
            ).count == 1
        )
    }
}
