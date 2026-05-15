import Foundation
import XCTest

@testable import Core

final class GraphQLDecodingTests: XCTestCase {
    func testDecodesPullRequestAndIssueNodes() throws {
        let fixture = """
        {
          "data": {
            "search": {
              "nodes": [
                {
                  "__typename": "PullRequest",
                  "number": 42,
                  "title": "Fix widget alignment",
                  "body": "Align left column widgets.",
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
                  "body": "Follow up perf work.",
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

        let response = try JSONCoding.decoder().decode(GQLSearchResponse.self, from: Data(fixture.utf8))

        XCTAssertEqual(response.data.search.nodes.count, 2)
        XCTAssertEqual(response.data.search.pageInfo.hasNextPage, false)

        switch response.data.search.nodes[0] {
        case .pullRequest(let pr):
            XCTAssertEqual(pr.number, 42)
            XCTAssertEqual(pr.title, "Fix widget alignment")
            XCTAssertEqual(pr.state, "OPEN")
            XCTAssertEqual(pr.author?.login, "alice")
            XCTAssertEqual(pr.labels.nodes.count, 2)
            XCTAssertEqual(pr.repository.nameWithOwner, "org/repo")
            XCTAssertEqual(pr.reviews.nodes.count, 2)
            XCTAssertEqual(pr.comments.nodes.count, 2)
        default:
            XCTFail("Expected PullRequest at index 0")
        }

        switch response.data.search.nodes[1] {
        case .issue(let issue):
            XCTAssertEqual(issue.number, 99)
            XCTAssertEqual(issue.title, "Track performance regression")
            XCTAssertEqual(issue.author?.login, "dave")
            XCTAssertEqual(issue.comments.nodes.count, 0)
        default:
            XCTFail("Expected Issue at index 1")
        }
    }

    func testDecodesPageInfoWithCursor() throws {
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

        let r = try JSONCoding.decoder().decode(GQLSearchResponse.self, from: Data(json.utf8))
        XCTAssertEqual(r.data.search.pageInfo.hasNextPage, true)
        XCTAssertEqual(r.data.search.pageInfo.endCursor, "Y3Vyc29yOnYyOg==")
    }

    func testDecodesUnknownTypenameAsUnknown() throws {
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

        let r = try JSONCoding.decoder().decode(GQLSearchResponse.self, from: Data(json.utf8))
        guard case .unknown = r.data.search.nodes[0] else {
            return XCTFail("Expected .unknown for Discussion")
        }
    }
}

