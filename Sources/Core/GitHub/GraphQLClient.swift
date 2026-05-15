import Foundation

public struct GraphQLClient: Sendable {
    public let host: String
    private let token: String
    private let transport: URLSessionTransport

    public init(host: String, token: String, transport: URLSessionTransport = URLSessionTransport()) {
        self.host = host
        self.token = token
        self.transport = transport
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
            comments(last: 50) { nodes { id author { login } body createdAt } }
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
            comments(last: 50) { nodes { id author { login } body createdAt } }
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

    private static let requestTimeout: TimeInterval = 60
    private static let maxAttempts = 3

    public func fetchAll(myDoDIssues: MyDoDIssuesSettings?, issueQueue: IssueQueueSettings?) async throws -> [DashboardItem] {
        var allItems: [DashboardItem] = []
        for sq in Self.sectionQueries {
            let items = try await fetchSection(searchString: sq.query, section: sq.section)
            allItems.append(contentsOf: items)
        }
        if let dod = myDoDIssues, dod.host == host, !dod.repository.isEmpty {
            let items = try await fetchSection(searchString: dod.searchQuery, section: .myDoDIssues)
            allItems.append(contentsOf: items)
        }
        if let queue = issueQueue, queue.host == host, !queue.repository.isEmpty {
            let q = queue.searchQuery
            if !q.isEmpty {
                let items = try await fetchSection(searchString: q, section: .issueQueue)
                allItems.append(contentsOf: items)
            }
        }
        return allItems
    }

    private func fetchSection(searchString: String, section: DashboardSection) async throws -> [DashboardItem] {
        var items: [DashboardItem] = []
        var cursor: String?

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
            request.timeoutInterval = Self.requestTimeout
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let data = try await performRequest(request)

            let gql = try JSONCoding.decoder().decode(GQLSearchResponse.self, from: data)
            if let errors = gql.errors, !errors.isEmpty {
                let messages = errors.map(\.message).joined(separator: "; ")
                if gql.data == nil {
                    throw GraphQLError.queryErrors(messages)
                }
            }
            guard let search = gql.data?.search else {
                throw GraphQLError.missingData
            }

            for node in search.nodes {
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
                        state: IssueState(graphQLState: pr.state),
                        isDraft: pr.isDraft,
                        createdAt: pr.createdAt,
                        updatedAt: pr.updatedAt,
                        author: pr.author?.login ?? "",
                        labels: pr.labels.nodes.map(\.name),
                        section: section,
                        comments: GraphQLMapping.commentsNewestFirst(pr.comments.nodes),
                        reviewStatus: GraphQLMapping.deriveReviewStatus(pr.reviews.nodes)
                    ))
                case .issue(let issue):
                    let issueIdTag = (section == .issueQueue) ? "issue-queue" : "issue"
                    items.append(DashboardItem(
                        id: "\(host)-\(issueIdTag)-\(issue.repository.nameWithOwner)-\(issue.number)",
                        number: issue.number,
                        title: issue.title,
                        body: issue.body,
                        url: issue.url,
                        host: host,
                        repo: issue.repository.nameWithOwner,
                        state: IssueState(graphQLState: issue.state),
                        isDraft: false,
                        createdAt: issue.createdAt,
                        updatedAt: issue.updatedAt,
                        author: issue.author?.login ?? "",
                        labels: issue.labels.nodes.map(\.name),
                        section: section,
                        comments: GraphQLMapping.commentsNewestFirst(issue.comments.nodes),
                        reviewStatus: nil
                    ))
                case .unknown:
                    break
                }
            }

            if !search.pageInfo.hasNextPage { break }
            cursor = search.pageInfo.endCursor
        }

        return items
    }

    private func performRequest(_ request: URLRequest) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<Self.maxAttempts {
            do {
                let (data, response) = try await transport.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw GraphQLError.invalidResponse
                }
                if (200...299).contains(http.statusCode) {
                    return data
                }
                let bodyStr = String(data: data, encoding: .utf8) ?? ""
                let error = GraphQLError.httpError(status: http.statusCode, body: bodyStr)
                if Self.shouldRetry(status: http.statusCode), attempt < Self.maxAttempts - 1 {
                    try await Task.sleep(for: .milliseconds(250 * (1 << attempt)))
                    continue
                }
                throw error
            } catch let error as GraphQLError {
                throw error
            } catch {
                lastError = error
                if Self.shouldRetry(error: error), attempt < Self.maxAttempts - 1 {
                    try await Task.sleep(for: .milliseconds(250 * (1 << attempt)))
                    continue
                }
                throw error
            }
        }
        throw lastError ?? GraphQLError.invalidResponse
    }

    private static func shouldRetry(status: Int) -> Bool {
        status == 429 || status == 502 || status == 503
    }

    private static func shouldRetry(error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}

public enum GraphQLError: Error, LocalizedError {
    case httpError(status: Int, body: String)
    case queryErrors(String)
    case missingData
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .httpError(let status, let body):
            "HTTP \(status): \(body.prefix(200))"
        case .queryErrors(let messages):
            "GraphQL errors: \(messages.prefix(200))"
        case .missingData:
            "GraphQL response missing data"
        case .invalidResponse:
            "Invalid HTTP response"
        }
    }
}

enum GraphQLMapping {
    static func deriveReviewStatus(_ nodes: [GQLReview]) -> ReviewStatus {
        ReviewStatus(graphQLReviewStates: nodes.map(\.state))
    }

    static func commentsNewestFirst(_ nodes: [GQLCommentNode]) -> [ItemComment] {
        nodes.reversed().map {
            ItemComment(
                id: $0.id,
                author: $0.author?.login ?? "",
                body: $0.body,
                createdAt: $0.createdAt
            )
        }
    }
}

// Legacy entry points for tests.
func deriveReviewStatus(_ nodes: [GQLReview]) -> ReviewStatus {
    GraphQLMapping.deriveReviewStatus(nodes)
}

func commentsNewestFirst(_ nodes: [GQLCommentNode]) -> [ItemComment] {
    GraphQLMapping.commentsNewestFirst(nodes)
}
