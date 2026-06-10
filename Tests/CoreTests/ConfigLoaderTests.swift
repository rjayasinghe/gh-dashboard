import Testing
import Foundation

@testable import Core

@Suite struct ConfigLoaderTests {
    @Test func multiLineHosts() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).toml")
        try """
        [github]
        hosts = [
          "github.com",
          "github.mycompany.com",
        ]
        """.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let cfg = try ConfigLoader.load(path: tmp.path)
        #expect(cfg.hosts == ["github.com", "github.mycompany.com"])
        #expect(cfg.myDoDIssues == nil)
        #expect(cfg.issueQueue == nil)
    }

    @Test func singleLineHosts() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).toml")
        try """
        [github]
        hosts = ["github.com"]
        """.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let cfg = try ConfigLoader.load(path: tmp.path)
        #expect(cfg.hosts == ["github.com"])
    }

    @Test func missingFileThrows() {
        #expect(throws: (any Error).self) { try ConfigLoader.load(path: "/nonexistent/path.toml") }
    }

    @Test func emptyHostsThrows() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).toml")
        try """
        [github]
        hosts = []
        """.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        #expect(throws: (any Error).self) { try ConfigLoader.load(path: tmp.path) }
    }

    @Test func myIssuesAndIssueQueueTogether() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).toml")
        try """
        [github]
        hosts = ["git.example.com"]

        [my_issues]
        host = "git.example.com"
        repository = "team/app"
        exclude_labels = "blocked"

        [issue_queue]
        host = "git.example.com"
        repository = "team/app"
        include_labels = "ready, queued"
        """.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let cfg = try ConfigLoader.load(path: tmp.path)
        #expect(cfg.myDoDIssues?.repository == "team/app")
        #expect(cfg.myDoDIssues?.excludeLabels == ["blocked"])
        #expect(cfg.issueQueue?.repository == "team/app")
        #expect(cfg.issueQueue?.includeLabels == ["ready", "queued"])
    }

    @Test func commentsIgnoredInHosts() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).toml")
        try """
        # Main config
        [github]
        hosts = [
          "github.com",
          # "github.internal.com",
        ]
        """.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let cfg = try ConfigLoader.load(path: tmp.path)
        #expect(cfg.hosts == ["github.com"])
    }
}
