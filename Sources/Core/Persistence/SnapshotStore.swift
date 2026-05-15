import Foundation
import os

public enum SnapshotStore {
    private static let log = Logger(subsystem: "com.ghdashboard.app", category: "snapshot")
    private static let fileName = "snapshot.json"

    public static var directoryURL: URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory unavailable")
        }
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
            if let current = try? JSONCoding.decoder().decode(PersistedSnapshot.self, from: data) {
                guard current.schemaVersion <= PersistedSnapshot.currentSchemaVersion else {
                    log.warning("Snapshot schema \(current.schemaVersion) is newer than supported; ignoring cache")
                    return nil
                }
                return current
            }
            if let migrated = SnapshotMigration.migrateV1Data(data) {
                log.info("Migrated snapshot from schema v1 to v\(PersistedSnapshot.currentSchemaVersion)")
                save(migrated)
                return migrated
            }
            log.error("Failed to decode snapshot at \(url.path, privacy: .public)")
            return nil
        } catch {
            log.error("Snapshot load failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    public static func save(_ snapshot: PersistedSnapshot) {
        let dir = directoryURL
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONCoding.encoder()
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
            log.error("Snapshot save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
