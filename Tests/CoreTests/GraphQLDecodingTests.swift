import Foundation
import Testing

@testable import Core

@Suite struct GraphQLDecodingTests {
    @Test func decodesPullRequestAndIssueNodes() throws {
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
              { "id": "PRRC_1", "author": { "login": "bob" }, "body": "Looks good", "createdAt": "2025-12-01T12:00:00Z" },
              { "id": "PRRC_2", "author": { "login": "carol" }, "body": "One nit", "createdAt": "2025-12-02T09:00:00Z" }
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
        let data = try #require(response.data)

        #expect(data.search.nodes.count == 2)
        #expect(data.search.pageInfo.hasNextPage == false)

        switch data.search.nodes[0] {
        case .pullRequest(let pr):
            #expect(pr.number == 42)
            #expect(pr.title == "Fix widget alignment")
            #expect(pr.state == "OPEN")
            #expect(pr.author?.login == "alice")
            #expect(pr.labels.nodes.count == 2)
            #expect(pr.repository.nameWithOwner == "org/repo")
            #expect(pr.reviews.nodes.count == 2)
            #expect(pr.comments.nodes.count == 2)
        default:
            Issue.record("Expected PullRequest at index 0")
        }

        switch data.search.nodes[1] {
        case .issue(let issue):
            #expect(issue.number == 99)
            #expect(issue.title == "Track performance regression")
            #expect(issue.author?.login == "dave")
            #expect(issue.comments.nodes.count == 0)
        default:
            Issue.record("Expected Issue at index 1")
        }
    }

    @Test func decodesPageInfoWithCursor() throws {
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
        let data = try #require(r.data)
        #expect(data.search.pageInfo.hasNextPage == true)
        #expect(data.search.pageInfo.endCursor == "Y3Vyc29yOnYyOg==")
    }

    @Test func decodesUnknownTypenameAsUnknown() throws {
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
        let data = try #require(r.data)
        guard case .unknown = data.search.nodes[0] else {
            Issue.record("Expected .unknown for Discussion")
            return
        }
    }
}
