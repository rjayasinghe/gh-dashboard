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
        var hasSection = false
        var result = MyDoDIssuesSettings(host: "", repository: "", excludeLabels: [])
        var inSection = false

        for rawLine in toml.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { continue }

            if line == "[my_issues]" || line == "[my_dod_issues]" {
                hasSection = true
                inSection = true
                continue
            }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                inSection = false
                continue
            }
            guard inSection, let eq = line.firstIndex(of: "=") else { continue }

            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let valueRaw = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            guard let value = Self.stripTomlString(valueRaw), !value.isEmpty else { continue }

            switch key {
            case "host":
                result = MyDoDIssuesSettings(host: value, repository: result.repository, excludeLabels: result.excludeLabels)
            case "repository", "repo":
                result = MyDoDIssuesSettings(host: result.host, repository: value, excludeLabels: result.excludeLabels)
            case "exclude_labels", "excludeLabels", "exclude_label", "excludeLabel":
                result = MyDoDIssuesSettings(
                    host: result.host,
                    repository: result.repository,
                    excludeLabels: Self.parseCommaSeparatedLabels(value)
                )
            default: break
            }
        }

        guard hasSection else { return nil }
        let host = result.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let repo = result.repository.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !repo.isEmpty else { return nil }
        return MyDoDIssuesSettings(host: host, repository: repo, excludeLabels: result.excludeLabels)
    }

    /// Splits a comma-separated label list; trims whitespace; drops empty entries.
    public static func parseCommaSeparatedLabels(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func stripTomlString(_ raw: String) -> String? {
        var s = raw
        if s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 {
            s = String(s.dropFirst().dropLast())
            return s
        }
        if s.hasPrefix("'"), s.hasSuffix("'"), s.count >= 2 {
            s = String(s.dropFirst().dropLast())
            return s
        }
        return s
    }
}
