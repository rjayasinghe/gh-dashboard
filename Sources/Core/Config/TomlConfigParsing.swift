import Foundation

/// Shared minimal TOML helpers for `config.toml` section scanning.
enum TomlConfigParsing {
    static func stripTomlString(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 {
            return String(s.dropFirst().dropLast())
        }
        if s.hasPrefix("'"), s.hasSuffix("'"), s.count >= 2 {
            return String(s.dropFirst().dropLast())
        }
        return s.isEmpty ? nil : s
    }

    static func parseCommaSeparatedLabels(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func extractQuotedStrings(_ line: String) -> [String] {
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

    /// Reads key/value pairs from a named TOML section (e.g. `[my_issues]`).
    static func keyValues(inSection sectionName: String, from toml: String) -> [String: String] {
        var values: [String: String] = [:]
        var inSection = false

        for rawLine in toml.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { continue }

            if line == "[\(sectionName)]" {
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
            guard let value = stripTomlString(valueRaw), !value.isEmpty else { continue }
            values[key] = value
        }
        return values
    }

    /// Parses `hosts = ["a", "b"]` from the `[github]` section.
    static func parseGitHubHosts(from toml: String) -> [String] {
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
                    let stripped = match.trimmingCharacters(in: .whitespaces)
                    if !stripped.isEmpty { hosts.append(stripped) }
                }
                if line.contains("]") { inArray = false }
            }
        }
        return hosts
    }

    static func hasSection(_ name: String, in toml: String) -> Bool {
        toml.contains { line in
            line.trimmingCharacters(in: .whitespaces) == "[\(name)]"
        }
    }
}
