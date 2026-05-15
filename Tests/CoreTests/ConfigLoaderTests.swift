import XCTest

@testable import Core

final class ConfigLoaderTests: XCTestCase {
    func testMultiLineHosts() throws {
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
        XCTAssertEqual(cfg.hosts, ["github.com", "github.mycompany.com"])
        XCTAssertNil(cfg.myDoDIssues)
        XCTAssertNil(cfg.issueQueue)
    }

    func testSingleLineHosts() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).toml")
        try """
        [github]
        hosts = ["github.com"]
        """.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let cfg = try ConfigLoader.load(path: tmp.path)
        XCTAssertEqual(cfg.hosts, ["github.com"])
    }

    func testMissingFileThrows() throws {
        XCTAssertThrowsError(try ConfigLoader.load(path: "/nonexistent/path.toml"))
    }

    func testEmptyHostsThrows() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).toml")
        try """
        [github]
        hosts = []
        """.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertThrowsError(try ConfigLoader.load(path: tmp.path))
    }

    func testMyIssuesAndIssueQueueTogether() throws {
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
        XCTAssertEqual(cfg.myDoDIssues?.repository, "team/app")
        XCTAssertEqual(cfg.myDoDIssues?.excludeLabels, ["blocked"])
        XCTAssertEqual(cfg.issueQueue?.repository, "team/app")
        XCTAssertEqual(cfg.issueQueue?.includeLabels, ["ready", "queued"])
    }

    func testCommentsIgnoredInHosts() throws {
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
        XCTAssertEqual(cfg.hosts, ["github.com"])
    }
}

