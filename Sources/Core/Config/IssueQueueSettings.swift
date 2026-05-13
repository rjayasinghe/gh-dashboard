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
        if trimmed.count == 1 {
            let inner = trimmed[0].replacingOccurrences(of: "\"", with: "")
            parts.append("label:\"\(inner)\"")
        } else {
            let labelOr = trimmed.map { label in
                let inner = label.replacingOccurrences(of: "\"", with: "")
                return "label:\"\(inner)\""
            }.joined(separator: " OR ")
            parts.append("(\(labelOr))")
        }
        return parts.joined(separator: " ")
    }

    /// Parses `[issue_queue]` from TOML. Returns `nil` if the section is missing or **`host`**, **`repository`**,
    /// or **`include_labels`** (after parsing) is empty.
    public static func parse(fromToml toml: String) -> IssueQueueSettings? {
        var hasSection = false
        var result = IssueQueueSettings(host: "", repository: "", includeLabels: [])
        var inSection = false

        for rawLine in toml.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { continue }

            if line == "[issue_queue]" {
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
                result = IssueQueueSettings(host: value, repository: result.repository, includeLabels: result.includeLabels)
            case "repository", "repo":
                result = IssueQueueSettings(host: result.host, repository: value, includeLabels: result.includeLabels)
            case "include_labels", "includeLabels", "include_label", "includeLabel":
                result = IssueQueueSettings(
                    host: result.host,
                    repository: result.repository,
                    includeLabels: MyDoDIssuesSettings.parseCommaSeparatedLabels(value)
                )
            default: break
            }
        }

        guard hasSection else { return nil }
        let host = result.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let repo = result.repository.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !repo.isEmpty, !result.includeLabels.isEmpty else { return nil }
        return IssueQueueSettings(host: host, repository: repo, includeLabels: result.includeLabels)
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
