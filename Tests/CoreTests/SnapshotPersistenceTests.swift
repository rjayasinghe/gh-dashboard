import Foundation
import XCTest

@testable import Core

final class SnapshotPersistenceTests: XCTestCase {
    func testPersistedSnapshotEncodesDecodesRoundTrip() throws {
        let comment = ItemComment(id: "IC_1", author: "bob", body: "lgtm", createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let item = DashboardItem(
            id: "gh-pr-org/repo-7",
            number: 7,
            title: "Add caching",
            body: "",
            url: "https://github.com/org/repo/pull/7",
            host: "github.com",
            repo: "org/repo",
            state: .open,
            isDraft: false,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_100_000),
            author: "alice",
            labels: ["perf"],
            section: .myPRs,
            comments: [comment],
            reviewStatus: .approved
        )

        let snapshot = PersistedSnapshot(items: [item], savedAt: Date(timeIntervalSince1970: 1_700_200_000))

        let data = try JSONCoding.encoder().encode(snapshot)
        let decoded = try JSONCoding.decoder().decode(PersistedSnapshot.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, PersistedSnapshot.currentSchemaVersion)
        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertEqual(decoded.items[0].id, "gh-pr-org/repo-7")
        XCTAssertEqual(decoded.items[0].state, .open)
        XCTAssertEqual(decoded.items[0].section, .myPRs)
        XCTAssertEqual(decoded.items[0].reviewStatus, .approved)
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
            state: .open,
            isDraft: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_100_000),
            author: "z",
            labels: ["ci"],
            section: .myIssues,
            comments: [],
            reviewStatus: nil
        )
        let snap = PersistedSnapshot(items: [item], savedAt: Date(timeIntervalSince1970: 1_700_200_000))

        SnapshotStore.save(snap)
        let loaded = SnapshotStore.load()
        XCTAssertNotNil(loaded)
        XCTAssertTrue(loaded?.items.contains(where: { $0.id == item.id }) == true)
    }
}
