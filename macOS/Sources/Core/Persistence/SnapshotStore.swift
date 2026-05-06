import Foundation

public struct PersistedSnapshot: Codable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let items: [DashboardItem]
    public let savedAt: Date

    public init(items: [DashboardItem], savedAt: Date = Date()) {
        self.schemaVersion = Self.currentSchemaVersion
        self.items = items
        self.savedAt = savedAt
    }
}

public enum SnapshotStore {
    private static let fileName = "snapshot.json"

    public static var directoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("GhDashboard", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    public static func load() -> PersistedSnapshot? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(PersistedSnapshot.self, from: data)
            guard snapshot.schemaVersion <= PersistedSnapshot.currentSchemaVersion else { return nil }
            return snapshot
        } catch {
            return nil
        }
    }

    public static func save(_ snapshot: PersistedSnapshot) {
        let dir = directoryURL
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(snapshot)

            let tmp = dir.appendingPathComponent(".\(fileName).tmp")
            try data.write(to: tmp, options: .atomic)

            let dest = fileURL
            if FileManager.default.fileExists(atPath: dest.path) {
                _ = try FileManager.default.replaceItemAt(dest, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: dest)
            }
        } catch {
            // Persist is best-effort; app continues normally without cache.
        }
    }
}
