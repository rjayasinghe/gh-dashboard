import XCTest

@testable import Core

final class DashboardModelsTests: XCTestCase {
    func testDashboardSectionRawValuesStable() {
        XCTAssertEqual(DashboardSection.myPRs.rawValue, 0)
        XCTAssertEqual(DashboardSection.reviewNeeded.rawValue, 1)
        XCTAssertEqual(DashboardSection.myIssues.rawValue, 2)
        XCTAssertEqual(DashboardSection.myDoDIssues.rawValue, 3)
        XCTAssertEqual(DashboardSection.issueQueue.rawValue, 4)
        XCTAssertEqual(DashboardSection.allCases.count, 5)
    }

    func testDashboardSectionCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for sec in DashboardSection.allCases {
            let data = try encoder.encode(sec)
            let decoded = try decoder.decode(DashboardSection.self, from: data)
            XCTAssertEqual(decoded, sec)
        }
    }

    func testDashboardItemDisplayHostStripsProtocol() {
        let item = DashboardItem(
            id: "t",
            number: 1,
            title: "T",
            body: "",
            url: "https://github.com/o/r/pull/1",
            host: "https://github.com",
            repo: "o/r",
            state: "OPEN",
            isDraft: false,
            createdAt: .now,
            updatedAt: .now,
            author: "a",
            labels: [],
            section: .myPRs,
            comments: [],
            reviewStatus: "approved"
        )
        XCTAssertEqual(item.displayHost, "github.com")
    }

    func testDashboardItemReviewBadges() {
        func badge(_ status: String) -> String? {
            DashboardItem(
                id: "t",
                number: 1,
                title: "T",
                body: "",
                url: "",
                host: "h",
                repo: "r",
                state: "OPEN",
                isDraft: false,
                createdAt: .now,
                updatedAt: .now,
                author: "a",
                labels: [],
                section: .myPRs,
                comments: [],
                reviewStatus: status
            ).reviewBadge
        }

        XCTAssertEqual(badge("approved"), "checkmark.circle.fill")
        XCTAssertEqual(badge("changes_requested"), "xmark.circle.fill")
        XCTAssertEqual(badge("pending"), "clock.fill")
        XCTAssertNil(badge(""))
    }
}

