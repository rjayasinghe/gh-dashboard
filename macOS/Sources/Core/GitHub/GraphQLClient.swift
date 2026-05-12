import Foundation

public struct GraphQLClient: Sendable {
    public let host: String
    private let token: String

    public init(host: String, token: String) {
        self.host = host
        self.token = token
    }

    private var endpointURL: URL {
        if host == "github.com" {
            return URL(string: "https://api.github.com/graphql")!
        }
        return URL(string: "https://\(host)/api/graphql")!
    }

    private static let searchQuery = """
    query($query: String!, $first: Int!, $after: String) {
      search(query: $query, type: ISSUE, first: $first, after: $after) {
        nodes {
          __typename
          ... on PullRequest {
            number
            title
            body
            url
            state
            isDraft
            createdAt
            updatedAt
            author { login }
            labels(first: 10) { nodes { name } }
            repository { nameWithOwner }
            reviews(last: 10) { nodes { state } }
            comments(last: 50) { nodes { author { login } body createdAt } }
          }
          ... on Issue {
            number
            title
            body
            url
            state
            createdAt
            updatedAt
            author { login }
            labels(first: 10) { nodes { name } }
            repository { nameWithOwner }
            comments(last: 50) { nodes { author { login } body createdAt } }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
    """

    private static let sectionQueries: [(query: String, section: DashboardSection)] = [
        ("is:pr is:open author:@me archived:false", .myPRs),
        ("is:pr is:open review-requested:@me archived:false", .reviewNeeded),
        ("is:issue is:open assignee:@me archived:false", .myIssues),
    ]

    public func fetchAll(myDoDIssues: MyDoDIssuesSettings?) async throws -> [DashboardItem] {
        var allItems: [DashboardItem] = []
        for sq in Self.sectionQueries {
            let items = try await fetchSection(searchString: sq.query, section: sq.section)
            allItems.append(contentsOf: items)
        }
        if let dod = myDoDIssues, dod.host == host, !dod.repository.isEmpty {
            let items = try await fetchSection(searchString: dod.searchQuery, section: .myDoDIssues)
            allItems.append(contentsOf: items)
        }
        return allItems
    }

    private func fetchSection(searchString: String, section: DashboardSection) async throws -> [DashboardItem] {
        var items: [DashboardItem] = []
        var cursor: String? = nil

        while true {
            var variables: [String: Any] = [
                "query": searchString,
                "first": 50,
            ]
            if let cursor { variables["after"] = cursor }

            let body: [String: Any] = [
                "query": Self.searchQuery,
                "variables": variables,
            ]

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let bodyStr = String(data: data, encoding: .utf8) ?? ""
                throw GraphQLError.httpError(status: http.statusCode, body: bodyStr)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let gql = try decoder.decode(GQLSearchResponse.self, from: data)

            for node in gql.data.search.nodes {
                switch node {
                case .pullRequest(let pr):
                    items.append(DashboardItem(
                        id: "\(host)-pr-\(pr.repository.nameWithOwner)-\(pr.number)",
                        number: pr.number,
                        title: pr.title,
                        body: pr.body,
                        url: pr.url,
                        host: host,
                        repo: pr.repository.nameWithOwner,
                        state: pr.state,
                        isDraft: pr.isDraft,
                        createdAt: pr.createdAt,
                        updatedAt: pr.updatedAt,
                        author: pr.author?.login ?? "",
                        labels: pr.labels.nodes.map(\.name),
                        section: section,
                        comments: commentsNewestFirst(pr.comments.nodes),
                        reviewStatus: deriveReviewStatus(pr.reviews.nodes)
                    ))
                case .issue(let issue):
                    items.append(DashboardItem(
                        id: "\(host)-issue-\(issue.repository.nameWithOwner)-\(issue.number)",
                        number: issue.number,
                        title: issue.title,
                        body: issue.body,
                        url: issue.url,
                        host: host,
                        repo: issue.repository.nameWithOwner,
                        state: issue.state,
                        isDraft: false,
                        createdAt: issue.createdAt,
                        updatedAt: issue.updatedAt,
                        author: issue.author?.login ?? "",
                        labels: issue.labels.nodes.map(\.name),
                        section: section,
                        comments: commentsNewestFirst(issue.comments.nodes),
                        reviewStatus: ""
                    ))
                case .unknown:
                    break
                }
            }

            if !gql.data.search.pageInfo.hasNextPage { break }
            cursor = gql.data.search.pageInfo.endCursor
        }

        return items
    }
}

public enum GraphQLError: Error, LocalizedError {
    case httpError(status: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .httpError(let status, let body):
            "HTTP \(status): \(body.prefix(200))"
        }
    }
}

func deriveReviewStatus(_ nodes: [GQLReview]) -> String {
    if nodes.contains(where: { $0.state == "CHANGES_REQUESTED" }) { return "changes_requested" }
    if nodes.contains(where: { $0.state == "APPROVED" }) { return "approved" }
    return "pending"
}

func commentsNewestFirst(_ nodes: [GQLCommentNode]) -> [ItemComment] {
    nodes.reversed().map {
        ItemComment(author: $0.author?.login ?? "", body: $0.body, createdAt: $0.createdAt)
    }
}
