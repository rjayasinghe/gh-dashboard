import Foundation
import Testing

@testable import Core

@Suite struct SnapshotPersistenceTests {
    @Test func persistedSnapshotEncodesDecodesRoundTrip() throws {
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

        #expect(decoded.schemaVersion == PersistedSnapshot.currentSchemaVersion)
        #expect(decoded.items.count == 1)
        #expect(decoded.items[0].id == "gh-pr-org/repo-7")
        #expect(decoded.items[0].state == .open)
        #expect(decoded.items[0].section == .myPRs)
        #expect(decoded.items[0].reviewStatus == .approved)
    }

    @Test func snapshotStoreSaveLoadRoundTrip() throws {
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
        #expect(loaded != nil)
        #expect(loaded?.items.contains(where: { $0.id == item.id }) == true)
    }
}
