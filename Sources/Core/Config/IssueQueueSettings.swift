import Foundation

/// Settings for the **Issue queue** tab: open, unassigned issues in one repository that match at least one
/// configured label (`OR`). Enable with **`[issue_queue]`** and **`host`**, **`repository`**, and **`include_labels`**.
public struct IssueQueueSettings: Sendable, Equatable {
    public let host: String
    public let repository: String
    /// Issue must have at least one of these labels (GitHub search `label:"…"` combined with `OR`).
    public let includeLabels: [String]

    public init(host: String, repository: String, includeLabels: [String]) {
        self.host = host
        self.repository = repository
        self.includeLabels = includeLabels
    }

    /// GitHub issue search string for the GraphQL `search` API. Empty if there are no include labels.
    public var searchQuery: String {
        let trimmed = includeLabels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return "" }

        var parts = [
            "repo:\(repository)",
            "is:issue",
            "is:open",
            "no:assignee",
            "archived:false",
        ]
        let labelClauses = trimmed.map { label in
            let inner = label.replacingOccurrences(of: "\"", with: "")
            return "label:\"\(inner)\""
        }
        if labelClauses.count == 1 {
            parts.append(labelClauses[0])
        } else {
            parts.append("(\(labelClauses.joined(separator: " OR ")))")
        }
        return parts.joined(separator: " ")
    }

    /// Parses `[issue_queue]` from TOML. Returns `nil` if the section is missing or **`host`**, **`repository`**,
    /// or **`include_labels`** (after parsing) is empty.
    public static func parse(fromToml toml: String) -> IssueQueueSettings? {
        guard TomlConfigParsing.hasSection("issue_queue", in: toml) else { return nil }

        let kv = TomlConfigParsing.keyValues(inSection: "issue_queue", from: toml)
        let host = (kv["host"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let repo = (kv["repository"] ?? kv["repo"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let includeRaw = kv["include_labels"] ?? kv["includeLabels"] ?? kv["include_label"] ?? kv["includeLabel"] ?? ""
        let includeLabels = TomlConfigParsing.parseCommaSeparatedLabels(includeRaw)

        guard !host.isEmpty, !repo.isEmpty, !includeLabels.isEmpty else { return nil }
        return IssueQueueSettings(host: host, repository: repo, includeLabels: includeLabels)
    }
}
