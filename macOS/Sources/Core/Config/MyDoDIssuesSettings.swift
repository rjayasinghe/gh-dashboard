import Foundation

/// Settings for the "My DoD issues" sidebar tab: open issues assigned to you on one repo,
/// excluding a label (default: CAP on SAP GitHub Enterprise).
public struct MyDoDIssuesSettings: Sendable, Equatable {
    public let host: String
    public let repository: String
    public let excludeLabel: String

    public init(host: String, repository: String, excludeLabel: String) {
        self.host = host
        self.repository = repository
        self.excludeLabel = excludeLabel
    }

    /// Default targets `github.tools.sap` / SAP CAP; override in `[my_dod_issues]` if needed.
    public static let builtInDefault = MyDoDIssuesSettings(
        host: "github.tools.sap",
        repository: "SAP/cap",
        excludeLabel: "Author Action"
    )

    /// GitHub issue search string for the GraphQL `search` API.
    public var searchQuery: String {
        var parts = [
            "repo:\(repository)",
            "is:issue",
            "is:open",
            "assignee:@me",
            "archived:false",
        ]
        let trimmed = excludeLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let inner = trimmed.replacingOccurrences(of: "\"", with: "")
            parts.append("-label:\"\(inner)\"")
        }
        return parts.joined(separator: " ")
    }

    /// Parses optional `[my_dod_issues]` from TOML; keys override `builtInDefault` when present.
    public static func parse(fromToml toml: String) -> MyDoDIssuesSettings {
        var result = builtInDefault
        var inSection = false

        for rawLine in toml.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { continue }

            if line == "[my_dod_issues]" {
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
            case "host": result = MyDoDIssuesSettings(host: value, repository: result.repository, excludeLabel: result.excludeLabel)
            case "repository", "repo":
                result = MyDoDIssuesSettings(host: result.host, repository: value, excludeLabel: result.excludeLabel)
            case "exclude_label", "excludeLabel":
                result = MyDoDIssuesSettings(host: result.host, repository: result.repository, excludeLabel: value)
            default: break
            }
        }
        return result
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
