import Foundation
import Security
import Yams

public enum CredentialStore {
    /// Reads the OAuth token for a GitHub host.
    ///
    /// Lookup order (mirrors `go-gh` / `gh` CLI behavior):
    /// 1. macOS Keychain — `gh` stores tokens as generic passwords
    ///    with service `gh:<host>` (e.g. `gh:github.com`).
    /// 2. `~/.config/gh/hosts.yml` — the `oauth_token` field, used
    ///    when `gh` is configured with `GH_TOKEN` or plain-text storage.
    public static func token(forHost host: String) -> String? {
        if let token = keychainToken(forHost: host) {
            return token
        }
        return hostsYmlToken(forHost: host)
    }

    // MARK: - Keychain

    private static let goKeyringPrefix = "go-keyring-base64:"

    private static func keychainToken(forHost host: String) -> String? {
        // Try Security framework first (works when ACL allows this binary).
        if let raw = keychainTokenViaAPI(forHost: host) {
            return decodeGoKeyring(raw)
        }
        // Fallback: shell out to `security` which runs under the user's
        // login session and always has ACL access to their own keychain.
        if let raw = keychainTokenViaCLI(forHost: host) {
            return decodeGoKeyring(raw)
        }
        return nil
    }

    private static func keychainTokenViaAPI(forHost host: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "gh:\(host)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let raw = String(data: data, encoding: .utf8),
              !raw.isEmpty
        else { return nil }

        return raw
    }

    private static func keychainTokenViaCLI(forHost host: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "gh:\(host)", "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let raw, !raw.isEmpty else { return nil }
            return raw
        } catch {
            return nil
        }
    }

    private static func decodeGoKeyring(_ raw: String) -> String? {
        // go-keyring (used by gh) stores tokens as "go-keyring-base64:<base64>"
        if raw.hasPrefix(goKeyringPrefix) {
            let b64 = String(raw.dropFirst(goKeyringPrefix.count))
            guard let decoded = Data(base64Encoded: b64),
                  let token = String(data: decoded, encoding: .utf8)
            else { return nil }
            return token
        }
        return raw
    }

    // MARK: - hosts.yml fallback

    private static func hostsYmlToken(forHost host: String) -> String? {
        let paths = possibleHostsPaths()
        for path in paths {
            if let token = readYmlToken(from: path, host: host) {
                return token
            }
        }
        return nil
    }

    private static func possibleHostsPaths() -> [String] {
        var paths: [String] = []

        if let ghConfigDir = ProcessInfo.processInfo.environment["GH_CONFIG_DIR"] {
            paths.append((ghConfigDir as NSString).appendingPathComponent("hosts.yml"))
        }

        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            paths.append((xdg as NSString).appendingPathComponent("gh/hosts.yml"))
        }

        let home = NSHomeDirectory()
        paths.append((home as NSString).appendingPathComponent(".config/gh/hosts.yml"))

        return paths
    }

    private static func readYmlToken(from path: String, host: String) -> String? {
        guard FileManager.default.fileExists(atPath: path),
              let contents = try? String(contentsOfFile: path, encoding: .utf8),
              let parsed = try? Yams.load(yaml: contents) as? [String: Any],
              let hostEntry = parsed[host] as? [String: Any]
        else { return nil }

        if let token = hostEntry["oauth_token"] as? String, !token.isEmpty {
            return token
        }
        return nil
    }
}
