import Foundation

/// Settings for the filtered **My issues** sidebar tab: open issues assigned to you in one repository,
/// excluding configured labels. Enable by adding `[my_issues]` (or legacy `[my_dod_issues]`) with **`host`**
/// and **`repository`** in `config.toml`.
public struct MyDoDIssuesSettings: Sendable, Equatable {
    public let host: String
    public let repository: String
    /// Labels to exclude from results (each becomes `-label:"…"` in GitHub search).
    public let excludeLabels: [String]

    public init(host: String, repository: String, excludeLabels: [String]) {
        self.host = host
        self.repository = repository
        self.excludeLabels = excludeLabels
    }

    /// GitHub issue search string for the GraphQL `search` API.
    public var searchQuery: String {
        var parts = [
            "repo:\(repository)",
            "is:issue",
            "is:open",
            "assignee:@me",
            "archived:false",
        ]
        for label in excludeLabels {
            let t = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            let inner = t.replacingOccurrences(of: "\"", with: "")
            parts.append("-label:\"\(inner)\"")
        }
        return parts.joined(separator: " ")
    }

    /// Parses `[my_issues]` or legacy `[my_dod_issues]` from TOML. Returns `nil` if neither section exists,
    /// or if **`host`** or **`repository`** is missing or empty after parsing (feature off).
    public static func parse(fromToml toml: String) -> MyDoDIssuesSettings? {
        let sectionName: String? = {
            if TomlConfigParsing.hasSection("my_issues", in: toml) { return "my_issues" }
            if TomlConfigParsing.hasSection("my_dod_issues", in: toml) { return "my_dod_issues" }
            return nil
        }()
        guard let sectionName else { return nil }

        let kv = TomlConfigParsing.keyValues(inSection: sectionName, from: toml)
        let host = (kv["host"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let repo = (kv["repository"] ?? kv["repo"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !repo.isEmpty else { return nil }

        let excludeRaw = kv["exclude_labels"] ?? kv["excludeLabels"] ?? kv["exclude_label"] ?? kv["excludeLabel"] ?? ""
        let excludeLabels = TomlConfigParsing.parseCommaSeparatedLabels(excludeRaw)

        return MyDoDIssuesSettings(host: host, repository: repo, excludeLabels: excludeLabels)
    }

    /// Splits a comma-separated label list; trims whitespace; drops empty entries.
    public static func parseCommaSeparatedLabels(_ raw: String) -> [String] {
        TomlConfigParsing.parseCommaSeparatedLabels(raw)
    }
}
