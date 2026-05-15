import Foundation
import Security
import Yams
import os

public enum CredentialStore {
    private static let log = Logger(subsystem: "com.ghdashboard.app", category: "credentials")

    /// Reads the OAuth token for a GitHub host.
    ///
    /// Lookup order (mirrors `go-gh` / `gh` CLI behavior):
    /// 1. macOS Keychain — `gh` stores tokens as generic passwords
    ///    with service `gh:<host>` (e.g. `gh:github.com`).
    /// 2. `~/.config/gh/hosts.yml` — the `oauth_token` field, used
    ///    when `gh` is configured with `GH_TOKEN` or plain-text storage.
    ///
    /// The `security` CLI fallback requires a non-sandboxed app and is incompatible
    /// with Mac App Store distribution; it exists because `gh`'s keychain ACL may
    /// deny direct Security-framework access from this binary.
    public static func token(forHost host: String) -> String? {
        if let token = keychainToken(forHost: host) {
            return token
        }
        return hostsYmlToken(forHost: host)
    }

    // MARK: - Keychain

    private static let goKeyringPrefix = "go-keyring-base64:"

    private static func keychainToken(forHost host: String) -> String? {
        if let raw = keychainTokenViaAPI(forHost: host) {
            return decodeGoKeyring(raw)
        }
        log.debug("Keychain API denied for gh:\(host, privacy: .public); trying security CLI fallback")
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
            log.error("security CLI failed for gh:\(host, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func decodeGoKeyring(_ raw: String) -> String? {
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
        for url in possibleHostsURLs() {
            if let token = readYmlToken(from: url, host: host) {
                return token
            }
        }
        return nil
    }

    private static func possibleHostsURLs() -> [URL] {
        var urls: [URL] = []

        if let ghConfigDir = ProcessInfo.processInfo.environment["GH_CONFIG_DIR"] {
            urls.append(URL(fileURLWithPath: ghConfigDir).appending(path: "hosts.yml"))
        }

        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            urls.append(URL(fileURLWithPath: xdg).appending(path: "gh/hosts.yml"))
        }

        urls.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appending(path: ".config/gh/hosts.yml")
        )

        return urls
    }

    private static func readYmlToken(from url: URL, host: String) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            guard let parsed = try Yams.load(yaml: contents) as? [String: Any],
                  let hostEntry = parsed[host] as? [String: Any],
                  let token = hostEntry["oauth_token"] as? String,
                  !token.isEmpty
            else { return nil }
            return token
        } catch {
            log.error("Failed to read hosts.yml at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
