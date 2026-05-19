import XCTest

@testable import Core
@testable import GhDashboard

@MainActor
final class DashboardViewModelSearchTests: XCTestCase {
    func testSearchResultsDelegatesToCoreLogic() {
        let vm = DashboardViewModel()
        vm.items = [
            sampleItem(id: "a", title: "Alpha widget", section: .myPRs),
            sampleItem(id: "b", title: "Beta issue", section: .myIssues),
        ]
        vm.searchQuery = "alpha"

        XCTAssertEqual(vm.searchResults.map(\.id), ["a"])
    }

    func testSearchResultsRespectsHiddenOptionalSections() {
        let vm = DashboardViewModel()
        vm.items = [
            sampleItem(id: "dod", title: "secret needle", section: .myDoDIssues),
        ]
        vm.searchQuery = "needle"

        XCTAssertTrue(vm.searchResults.isEmpty, "myDoDIssues tab hidden without config")
    }

    func testSelectSearchResultUpdatesSectionAndClearsQuery() {
        let vm = DashboardViewModel()
        let target = sampleItem(id: "x", title: "Target", section: .reviewNeeded)
        vm.items = [target]
        vm.section = .myPRs
        vm.searchQuery = "target"

        vm.selectSearchResult(target)

        XCTAssertEqual(vm.section, .reviewNeeded)
        XCTAssertEqual(vm.selectedItemID, "x")
        XCTAssertEqual(vm.searchQuery, "")
    }

    func testSearchFocusRequestIncrementsForShortcut() {
        let vm = DashboardViewModel()
        XCTAssertEqual(vm.searchFocusRequest, 0)
        vm.searchFocusRequest += 1
        XCTAssertEqual(vm.searchFocusRequest, 1)
    }

    private func sampleItem(id: String, title: String, section: DashboardSection) -> DashboardItem {
        DashboardItem(
            id: id,
            number: 1,
            title: title,
            body: "",
            url: "",
            host: "github.com",
            repo: "org/repo",
            state: .open,
            isDraft: false,
            createdAt: .now,
            updatedAt: .now,
            author: "alice",
            labels: [],
            section: section,
            comments: [],
            reviewStatus: nil
        )
    }
}
