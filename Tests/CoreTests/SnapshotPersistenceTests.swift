import Foundation
import XCTest

@testable import Core

final class SnapshotPersistenceTests: XCTestCase {
    func testPersistedSnapshotEncodesDecodesRoundTrip() throws {
        let comment = ItemComment(author: "bob", body: "lgtm", createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let item = DashboardItem(
            id: "gh-pr-org/repo-7",
            number: 7,
            title: "Add caching",
            body: "",
            url: "https://github.com/org/repo/pull/7",
            host: "github.com",
            repo: "org/repo",
            state: "OPEN",
            isDraft: false,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_100_000),
            author: "alice",
            labels: ["perf"],
            section: .myPRs,
            comments: [comment],
            reviewStatus: "approved"
        )

        let snapshot = PersistedSnapshot(items: [item], savedAt: Date(timeIntervalSince1970: 1_700_200_000))

        let data = try JSONCoding.encoder().encode(snapshot)
        let decoded = try JSONCoding.decoder().decode(PersistedSnapshot.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertEqual(decoded.items[0].id, "gh-pr-org/repo-7")
        XCTAssertEqual(decoded.items[0].number, 7)
        XCTAssertEqual(decoded.items[0].host, "github.com")
        XCTAssertEqual(decoded.items[0].repo, "org/repo")
        XCTAssertEqual(decoded.items[0].isDraft, false)
        XCTAssertEqual(decoded.items[0].author, "alice")
        XCTAssertEqual(decoded.items[0].labels, ["perf"])
        XCTAssertEqual(decoded.items[0].section, .myPRs)
        XCTAssertEqual(decoded.items[0].reviewStatus, "approved")
        XCTAssertEqual(decoded.items[0].comments.count, 1)
        XCTAssertEqual(decoded.items[0].comments[0].author, "bob")
        XCTAssertEqual(decoded.items[0].comments[0].body, "lgtm")
    }

    func testSnapshotStoreSaveLoadRoundTrip() throws {
        let item = DashboardItem(
            id: "io-1-\(UUID().uuidString)",
            number: 10,
            title: "IO test",
            body: "",
            url: "",
            host: "github.com",
            repo: "o/r",
            state: "OPEN",
            isDraft: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_100_000),
            author: "z",
            labels: ["ci"],
            section: .myIssues,
            comments: [],
            reviewStatus: ""
        )
        let snap = PersistedSnapshot(items: [item], savedAt: Date(timeIntervalSince1970: 1_700_200_000))

        SnapshotStore.save(snap)
        let loaded = SnapshotStore.load()
        XCTAssertNotNil(loaded)
        XCTAssertTrue(loaded?.items.contains(where: { $0.id == item.id }) == true)
    }
}

