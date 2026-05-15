import XCTest

@testable import Core

final class DashboardModelsTests: XCTestCase {
    func testDashboardSectionStringRawValues() {
        XCTAssertEqual(DashboardSection.myPRs.rawValue, "myPRs")
        XCTAssertEqual(DashboardSection.reviewNeeded.rawValue, "reviewNeeded")
        XCTAssertEqual(DashboardSection.myIssues.rawValue, "myIssues")
        XCTAssertEqual(DashboardSection.myDoDIssues.rawValue, "myDoDIssues")
        XCTAssertEqual(DashboardSection.issueQueue.rawValue, "issueQueue")
        XCTAssertEqual(DashboardSection.allCases.count, 5)
    }

    func testDashboardSectionLegacyIntMapping() {
        XCTAssertEqual(DashboardSection(legacyRawValue: 0), .myPRs)
        XCTAssertEqual(DashboardSection(legacyRawValue: 4), .issueQueue)
        XCTAssertNil(DashboardSection(legacyRawValue: 99))
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

    func testDashboardSectionIsPRSection() {
        XCTAssertTrue(DashboardSection.myPRs.isPRSection)
        XCTAssertTrue(DashboardSection.reviewNeeded.isPRSection)
        XCTAssertFalse(DashboardSection.myIssues.isPRSection)
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
            state: .open,
            isDraft: false,
            createdAt: .now,
            updatedAt: .now,
            author: "a",
            labels: [],
            section: .myPRs,
            comments: [],
            reviewStatus: .approved
        )
        XCTAssertEqual(item.displayHost, "github.com")
    }

    func testDashboardItemReviewBadges() {
        func badge(_ status: ReviewStatus?) -> String? {
            DashboardItem(
                id: "t",
                number: 1,
                title: "T",
                body: "",
                url: "",
                host: "h",
                repo: "r",
                state: .open,
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

        XCTAssertEqual(badge(.approved), "checkmark.circle.fill")
        XCTAssertEqual(badge(.changesRequested), "xmark.circle.fill")
        XCTAssertEqual(badge(.pending), "clock.fill")
        XCTAssertNil(badge(nil))
    }
}
