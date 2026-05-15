import Foundation

public struct AppConfig: Sendable {
    public let hosts: [String]
    /// Filtered “My issues” tab; `nil` when `[my_issues]` / `[my_dod_issues]` is absent or incomplete (tab hidden).
    public let myDoDIssues: MyDoDIssuesSettings?
    /// **Issue queue** tab; `nil` when `[issue_queue]` is absent or incomplete (tab hidden).
    public let issueQueue: IssueQueueSettings?
}

public enum ConfigLoader {
    public static let defaultPath = "~/.config/gh-dashboard/config.toml"

    public static func load(path: String = defaultPath) throws -> AppConfig {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConfigError.notFound(expanded)
        }
        let contents = try String(contentsOf: url, encoding: .utf8)
        let hosts = TomlConfigParsing.parseGitHubHosts(from: contents)
        guard !hosts.isEmpty else {
            throw ConfigError.noHosts(expanded)
        }
        let myDoDIssues = MyDoDIssuesSettings.parse(fromToml: contents)
        let issueQueue = IssueQueueSettings.parse(fromToml: contents)
        return AppConfig(hosts: hosts, myDoDIssues: myDoDIssues, issueQueue: issueQueue)
    }
}

public enum ConfigError: Error, LocalizedError {
    case notFound(String)
    case noHosts(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let path):
            """
            Config file not found at \(path)

            Create it with:

            [github]
            hosts = [
              "github.com",
            ]
            """
        case .noHosts(let path):
            "Config at \(path) has no hosts listed under [github]"
        }
    }
}
