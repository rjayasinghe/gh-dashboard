import Foundation

/// macOS notification preferences. When `[notifications]` is absent from `config.toml`,
/// notifications are **on** for every change category (matches the default UX expectation).
/// Set `enabled = false` as a master switch, or flip individual category flags to silence one trigger.
public struct NotificationSettings: Sendable, Equatable {
    /// Master switch. When `false`, no notifications fire and authorization isn't requested.
    public let enabled: Bool
    /// Notify when an item id is in the new fetch but wasn't in the prior set.
    public let notifyNewItems: Bool
    /// Notify when an existing item's `updatedAt` advances.
    public let notifyUpdates: Bool
    /// Notify (one per new comment) when a cached item gains comment ids.
    public let notifyComments: Bool
    /// Notify when an item's `state` or `isDraft` changes (e.g., open → merged).
    public let notifyStateChanges: Bool

    public init(
        enabled: Bool,
        notifyNewItems: Bool,
        notifyUpdates: Bool,
        notifyComments: Bool,
        notifyStateChanges: Bool
    ) {
        self.enabled = enabled
        self.notifyNewItems = notifyNewItems
        self.notifyUpdates = notifyUpdates
        self.notifyComments = notifyComments
        self.notifyStateChanges = notifyStateChanges
    }

    /// All categories on. Used when `[notifications]` is missing from the config.
    public static let `default` = NotificationSettings(
        enabled: true,
        notifyNewItems: true,
        notifyUpdates: true,
        notifyComments: true,
        notifyStateChanges: true
    )

    /// Parses `[notifications]` from TOML. Returns `.default` when the section is absent.
    /// Any individual key that's missing falls back to the `.default` value for that key.
    public static func parse(fromToml toml: String) -> NotificationSettings {
        guard TomlConfigParsing.hasSection("notifications", in: toml) else { return .default }

        let kv = TomlConfigParsing.keyValues(inSection: "notifications", from: toml)
        return NotificationSettings(
            enabled: parseBool(kv["enabled"], default: NotificationSettings.default.enabled),
            notifyNewItems: parseBool(kv["new_items"] ?? kv["newItems"], default: NotificationSettings.default.notifyNewItems),
            notifyUpdates: parseBool(kv["updates"], default: NotificationSettings.default.notifyUpdates),
            notifyComments: parseBool(kv["comments"], default: NotificationSettings.default.notifyComments),
            notifyStateChanges: parseBool(kv["state_changes"] ?? kv["stateChanges"], default: NotificationSettings.default.notifyStateChanges)
        )
    }

    /// Accepts `true`/`false` (case-insensitive) and `1`/`0`. Falls back to `default` for anything else.
    private static func parseBool(_ raw: String?, default fallback: Bool) -> Bool {
        guard let raw else { return fallback }
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "true", "1", "yes", "on": return true
        case "false", "0", "no", "off": return false
        default: return fallback
        }
    }
}
