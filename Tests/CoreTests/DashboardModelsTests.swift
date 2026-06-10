import Foundation
import Testing

@testable import Core

@Suite struct DashboardModelsTests {
    @Test func dashboardSectionStringRawValues() {
        #expect(DashboardSection.myPRs.rawValue == "myPRs")
        #expect(DashboardSection.reviewNeeded.rawValue == "reviewNeeded")
        #expect(DashboardSection.myIssues.rawValue == "myIssues")
        #expect(DashboardSection.myDoDIssues.rawValue == "myDoDIssues")
        #expect(DashboardSection.issueQueue.rawValue == "issueQueue")
        #expect(DashboardSection.allCases.count == 5)
    }

    @Test func dashboardSectionLegacyIntMapping() {
        #expect(DashboardSection(legacyRawValue: 0) == .myPRs)
        #expect(DashboardSection(legacyRawValue: 4) == .issueQueue)
        #expect(DashboardSection(legacyRawValue: 99) == nil)
    }

    @Test func dashboardSectionCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for sec in DashboardSection.allCases {
            let data = try encoder.encode(sec)
            let decoded = try decoder.decode(DashboardSection.self, from: data)
            #expect(decoded == sec)
        }
    }

    @Test func dashboardSectionIsPRSection() {
        #expect(DashboardSection.myPRs.isPRSection)
        #expect(DashboardSection.reviewNeeded.isPRSection)
        #expect(!DashboardSection.myIssues.isPRSection)
    }

    @Test func dashboardItemDisplayHostStripsProtocol() {
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
        #expect(item.displayHost == "github.com")
    }

    @Test func dashboardItemReviewBadges() {
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

        #expect(badge(.approved) == "checkmark.circle.fill")
        #expect(badge(.changesRequested) == "xmark.circle.fill")
        #expect(badge(.pending) == "clock.fill")
        #expect(badge(nil) == nil)
    }
}
