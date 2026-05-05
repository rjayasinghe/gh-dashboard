import Foundation

struct GQLSearchResponse: Decodable {
    let data: GQLData
}

struct GQLData: Decodable {
    let search: GQLSearch
}

struct GQLSearch: Decodable {
    let nodes: [GQLNode]
    let pageInfo: GQLPageInfo
}

struct GQLPageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor: String?
}

enum GQLNode: Decodable {
    case pullRequest(GQLPR)
    case issue(GQLIssue)
    case unknown

    private enum CodingKeys: String, CodingKey {
        case typename = "__typename"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typename = try container.decode(String.self, forKey: .typename)
        let singleValue = try decoder.singleValueContainer()
        switch typename {
        case "PullRequest":
            self = .pullRequest(try singleValue.decode(GQLPR.self))
        case "Issue":
            self = .issue(try singleValue.decode(GQLIssue.self))
        default:
            self = .unknown
        }
    }
}

struct GQLPR: Decodable {
    let number: Int
    let title: String
    let url: String
    let state: String
    let isDraft: Bool
    let createdAt: Date
    let updatedAt: Date
    let author: GQLActor?
    let labels: GQLLabelConnection
    let repository: GQLRepository
    let reviews: GQLReviewConnection
    let comments: GQLCommentConnection
}

struct GQLIssue: Decodable {
    let number: Int
    let title: String
    let url: String
    let state: String
    let createdAt: Date
    let updatedAt: Date
    let author: GQLActor?
    let labels: GQLLabelConnection
    let repository: GQLRepository
    let comments: GQLCommentConnection
}

struct GQLActor: Decodable {
    let login: String
}

struct GQLLabelConnection: Decodable {
    let nodes: [GQLLabel]
}

struct GQLLabel: Decodable {
    let name: String
}

struct GQLRepository: Decodable {
    let nameWithOwner: String
}

struct GQLReviewConnection: Decodable {
    let nodes: [GQLReview]
}

struct GQLReview: Decodable {
    let state: String
}

struct GQLCommentConnection: Decodable {
    let nodes: [GQLCommentNode]
}

struct GQLCommentNode: Decodable {
    let author: GQLActor?
    let body: String
    let createdAt: Date
}
