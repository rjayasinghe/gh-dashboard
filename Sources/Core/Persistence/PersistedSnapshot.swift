import Foundation

public struct PersistedSnapshot: Codable, Sendable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let items: [DashboardItem]
    public let savedAt: Date

    public init(items: [DashboardItem], savedAt: Date = Date()) {
        self.schemaVersion = Self.currentSchemaVersion
        self.items = items
        self.savedAt = savedAt
    }
}

// MARK: - Schema v1 migration

private struct LegacyPersistedSnapshot: Decodable {
    let schemaVersion: Int
    let items: [LegacyDashboardItem]
    let savedAt: Date
}

private struct LegacyDashboardItem: Decodable {
    let id: String
    let number: Int
    let title: String
    let body: String
    let url: String
    let host: String
    let repo: String
    let state: String
    let isDraft: Bool
    let createdAt: Date
    let updatedAt: Date
    let author: String
    let labels: [String]
    let section: Int
    let comments: [LegacyItemComment]
    let reviewStatus: String
}

private struct LegacyItemComment: Decodable {
    let author: String
    let body: String
    let createdAt: Date
    let id: String?

    enum CodingKeys: String, CodingKey {
        case author, body, createdAt, id
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        author = try c.decode(String.self, forKey: .author)
        body = try c.decode(String.self, forKey: .body)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        id = try c.decodeIfPresent(String.self, forKey: .id)
    }
}

enum SnapshotMigration {
    static func migrateV1Data(_ data: Data) -> PersistedSnapshot? {
        guard let legacy = try? JSONCoding.decoder().decode(LegacyPersistedSnapshot.self, from: data) else {
            return nil
        }
        let items = legacy.items.compactMap(migrateItem(_:))
        guard !items.isEmpty || legacy.items.isEmpty else { return nil }
        return PersistedSnapshot(items: items, savedAt: legacy.savedAt)
    }

    private static func migrateItem(_ legacy: LegacyDashboardItem) -> DashboardItem? {
        guard let section = DashboardSection(legacyRawValue: legacy.section) else { return nil }
        let review: ReviewStatus? = legacy.reviewStatus.isEmpty
            ? nil
            : ReviewStatus(rawValue: legacy.reviewStatus)
        let comments = legacy.comments.map { c in
            ItemComment(
                id: c.id ?? "\(c.author)-\(c.createdAt.timeIntervalSince1970)",
                author: c.author,
                body: c.body,
                createdAt: c.createdAt
            )
        }
        return DashboardItem(
            id: legacy.id,
            number: legacy.number,
            title: legacy.title,
            body: legacy.body,
            url: legacy.url,
            host: legacy.host,
            repo: legacy.repo,
            state: IssueState(graphQLState: legacy.state),
            isDraft: legacy.isDraft,
            createdAt: legacy.createdAt,
            updatedAt: legacy.updatedAt,
            author: legacy.author,
            labels: legacy.labels,
            section: section,
            comments: comments,
            reviewStatus: review
        )
    }
}
