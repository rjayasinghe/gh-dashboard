import Foundation

public struct AppConfig: Sendable {
    public let hosts: [String]
}

public enum ConfigLoader {
    public static let defaultPath = "~/.config/dev-dashboard/config.toml"

    public static func load(path: String = defaultPath) throws -> AppConfig {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        guard FileManager.default.fileExists(atPath: expanded) else {
            throw ConfigError.notFound(expanded)
        }
        let contents = try String(contentsOf: url, encoding: .utf8)
        let hosts = parseHosts(from: contents)
        guard !hosts.isEmpty else {
            throw ConfigError.noHosts(expanded)
        }
        return AppConfig(hosts: hosts)
    }

    private static func parseHosts(from toml: String) -> [String] {
        // Minimal TOML parser: extract hosts = ["...", "..."] from [github] section.
        var inGithub = false
        var inArray = false
        var hosts: [String] = []

        for rawLine in toml.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { continue }

            if line == "[github]" {
                inGithub = true
                continue
            }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                inGithub = false
                inArray = false
                continue
            }

            guard inGithub else { continue }

            if line.hasPrefix("hosts") && line.contains("=") {
                inArray = true
            }
            if inArray {
                for match in extractQuotedStrings(line) {
                    let stripped = match
                        .trimmingCharacters(in: .whitespaces)
                    if !stripped.isEmpty { hosts.append(stripped) }
                }
                if line.contains("]") { inArray = false }
            }
        }
        return hosts
    }

    private static func extractQuotedStrings(_ line: String) -> [String] {
        var results: [String] = []
        var inQuote = false
        var current = ""
        for ch in line {
            if ch == "\"" {
                if inQuote {
                    results.append(current)
                    current = ""
                }
                inQuote.toggle()
            } else if inQuote {
                current.append(ch)
            }
        }
        return results
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
