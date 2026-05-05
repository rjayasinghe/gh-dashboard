import Foundation
@testable import Core

// Minimal test harness that works with Command Line Tools (no Xcode / XCTest).
// Run: swift run CoreTests

nonisolated(unsafe) var passed = 0
nonisolated(unsafe) var failed = 0

@MainActor
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        let f = (file as NSString).lastPathComponent
        print("  FAIL \(f):\(line): \(msg)")
    }
}

@MainActor
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: String = #file, line: Int = #line) {
    if a == b {
        passed += 1
    } else {
        failed += 1
        let f = (file as NSString).lastPathComponent
        print("  FAIL \(f):\(line): \(msg.isEmpty ? "expected \(b), got \(a)" : msg)")
    }
}

@MainActor
func section(_ name: String) { print("--- \(name)") }

// ──────────────────────────────────────────────
// GraphQL decoding
// ──────────────────────────────────────────────

section("GraphQL decoding")

let fixture = """
{
  "data": {
    "search": {
      "nodes": [
        {
          "__typename": "PullRequest",
          "number": 42,
          "title": "Fix widget alignment",
          "url": "https://github.com/org/repo/pull/42",
          "state": "OPEN",
          "isDraft": true,
          "createdAt": "2025-12-01T10:00:00Z",
          "updatedAt": "2025-12-02T15:30:00Z",
          "author": { "login": "alice" },
          "labels": { "nodes": [{ "name": "bug" }, { "name": "ui" }] },
          "repository": { "nameWithOwner": "org/repo" },
          "reviews": { "nodes": [{ "state": "APPROVED" }, { "state": "CHANGES_REQUESTED" }] },
          "comments": {
            "nodes": [
              { "author": { "login": "bob" }, "body": "Looks good", "createdAt": "2025-12-01T12:00:00Z" },
              { "author": { "login": "carol" }, "body": "One nit", "createdAt": "2025-12-02T09:00:00Z" }
            ]
          }
        },
        {
          "__typename": "Issue",
          "number": 99,
          "title": "Track performance regression",
          "url": "https://github.com/org/repo/issues/99",
          "state": "OPEN",
          "createdAt": "2025-11-15T08:00:00Z",
          "updatedAt": "2025-11-20T14:00:00Z",
          "author": { "login": "dave" },
          "labels": { "nodes": [] },
          "repository": { "nameWithOwner": "org/repo" },
          "comments": { "nodes": [] }
        }
      ],
      "pageInfo": { "hasNextPage": false, "endCursor": null }
    }
  }
}
"""

do {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let response = try decoder.decode(GQLSearchResponse.self, from: Data(fixture.utf8))

    assertEqual(response.data.search.nodes.count, 2, "node count")
    assert(!response.data.search.pageInfo.hasNextPage, "hasNextPage should be false")

    if case .pullRequest(let pr) = response.data.search.nodes[0] {
        assertEqual(pr.number, 42, "PR number")
        assertEqual(pr.title, "Fix widget alignment", "PR title")
        assert(pr.isDraft, "PR isDraft")
        assertEqual(pr.state, "OPEN", "PR state")
        assertEqual(pr.author?.login, "alice", "PR author")
        assertEqual(pr.labels.nodes.count, 2, "PR label count")
        assertEqual(pr.repository.nameWithOwner, "org/repo", "PR repo")
        assertEqual(pr.reviews.nodes.count, 2, "PR review count")
        assertEqual(pr.comments.nodes.count, 2, "PR comment count")
    } else {
        assert(false, "Expected PullRequest at index 0")
    }

    if case .issue(let issue) = response.data.search.nodes[1] {
        assertEqual(issue.number, 99, "Issue number")
        assertEqual(issue.title, "Track performance regression", "Issue title")
        assertEqual(issue.author?.login, "dave", "Issue author")
        assert(issue.comments.nodes.isEmpty, "Issue should have no comments")
    } else {
        assert(false, "Expected Issue at index 1")
    }
} catch {
    failed += 1
    print("  FAIL decoding fixture: \(error)")
}

// pageInfo with cursor
do {
    let json = """
    {
      "data": {
        "search": {
          "nodes": [],
          "pageInfo": { "hasNextPage": true, "endCursor": "Y3Vyc29yOnYyOg==" }
        }
      }
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let r = try decoder.decode(GQLSearchResponse.self, from: Data(json.utf8))
    assert(r.data.search.pageInfo.hasNextPage, "hasNextPage with cursor")
    assertEqual(r.data.search.pageInfo.endCursor, "Y3Vyc29yOnYyOg==", "endCursor value")
} catch {
    failed += 1
    print("  FAIL pageInfo with cursor: \(error)")
}

// Unknown typename
do {
    let json = """
    {
      "data": {
        "search": {
          "nodes": [{ "__typename": "Discussion" }],
          "pageInfo": { "hasNextPage": false, "endCursor": null }
        }
      }
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let r = try decoder.decode(GQLSearchResponse.self, from: Data(json.utf8))
    if case .unknown = r.data.search.nodes[0] {
        passed += 1
    } else {
        assert(false, "Expected .unknown for Discussion")
    }
} catch {
    failed += 1
    print("  FAIL unknown typename: \(error)")
}

// ──────────────────────────────────────────────
// Review status derivation
// ──────────────────────────────────────────────

section("Review status derivation")

assertEqual(
    deriveReviewStatus([GQLReview(state: "APPROVED"), GQLReview(state: "CHANGES_REQUESTED")]),
    "changes_requested",
    "changes_requested takes priority over approved"
)
assertEqual(
    deriveReviewStatus([GQLReview(state: "APPROVED"), GQLReview(state: "COMMENTED")]),
    "approved",
    "approved when no changes_requested"
)
assertEqual(deriveReviewStatus([]), "pending", "pending when empty")
assertEqual(
    deriveReviewStatus([GQLReview(state: "COMMENTED")]),
    "pending",
    "pending with only COMMENTED"
)

// ──────────────────────────────────────────────
// Comment ordering
// ──────────────────────────────────────────────

section("Comment ordering")

let old = GQLCommentNode(author: GQLActor(login: "a"), body: "old", createdAt: Date(timeIntervalSince1970: 100))
let new = GQLCommentNode(author: GQLActor(login: "b"), body: "new", createdAt: Date(timeIntervalSince1970: 200))
let ordered = commentsNewestFirst([old, new])
assertEqual(ordered.count, 2, "comment count")
assertEqual(ordered[0].author, "b", "newest first")
assertEqual(ordered[1].author, "a", "oldest second")
assert(commentsNewestFirst([]).isEmpty, "empty in = empty out")

// ──────────────────────────────────────────────
// Config loading
// ──────────────────────────────────────────────

section("Config loading")

// Standard multi-line TOML
do {
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
    assertEqual(cfg.hosts, ["github.com", "github.mycompany.com"], "multi-line hosts")
} catch {
    failed += 1; print("  FAIL standard config: \(error)")
}

// Single-line array
do {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).toml")
    try """
    [github]
    hosts = ["github.com"]
    """.write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let cfg = try ConfigLoader.load(path: tmp.path)
    assertEqual(cfg.hosts, ["github.com"], "single-line hosts")
} catch {
    failed += 1; print("  FAIL single-line config: \(error)")
}

// Missing file
do {
    _ = try ConfigLoader.load(path: "/nonexistent/path.toml")
    assert(false, "should throw for missing file")
} catch {
    passed += 1
}

// Empty hosts
do {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).toml")
    try """
    [github]
    hosts = []
    """.write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }
    _ = try ConfigLoader.load(path: tmp.path)
    assert(false, "should throw for empty hosts")
} catch {
    passed += 1
}

// Comments ignored
do {
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
    assertEqual(cfg.hosts, ["github.com"], "comments filtered")
} catch {
    failed += 1; print("  FAIL comments config: \(error)")
}

// ──────────────────────────────────────────────
// DashboardItem properties
// ──────────────────────────────────────────────

section("DashboardItem properties")

let item = DashboardItem(
    id: "t", number: 1, title: "T", url: "https://github.com/o/r/pull/1",
    host: "https://github.com", repo: "o/r", state: "OPEN", isDraft: false,
    createdAt: .now, updatedAt: .now, author: "a", labels: [],
    section: .myPRs, comments: [], reviewStatus: "approved"
)
assertEqual(item.displayHost, "github.com", "displayHost strips protocol")

func badge(_ status: String) -> String? {
    DashboardItem(
        id: "t", number: 1, title: "T", url: "", host: "h", repo: "r",
        state: "OPEN", isDraft: false, createdAt: .now, updatedAt: .now,
        author: "a", labels: [], section: .myPRs, comments: [],
        reviewStatus: status
    ).reviewBadge
}
assertEqual(badge("approved"), "checkmark.circle.fill", "approved badge")
assertEqual(badge("changes_requested"), "xmark.circle.fill", "changes_requested badge")
assertEqual(badge("pending"), "clock.fill", "pending badge")
assert(badge("") == nil, "empty status has no badge")

// ──────────────────────────────────────────────
// Summary
// ──────────────────────────────────────────────

print("\n\(passed + failed) tests: \(passed) passed, \(failed) failed")
if failed > 0 {
    print("TESTS FAILED")
    exit(1)
} else {
    print("ALL TESTS PASSED")
}
