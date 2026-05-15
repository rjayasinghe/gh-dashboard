import Foundation

public enum DashboardSection: String, Sendable, CaseIterable, Identifiable, Hashable, Codable {
    case myPRs
    case reviewNeeded
    case myIssues
    case myDoDIssues
    case issueQueue

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .myPRs: "My PRs"
        case .reviewNeeded: "Review Needed"
        case .myIssues: "Issues"
        case .myDoDIssues: "My issues"
        case .issueQueue: "Issue queue"
        }
    }

    public var systemImage: String {
        switch self {
        case .myPRs: "arrow.triangle.pull"
        case .reviewNeeded: "eye"
        case .myIssues: "exclamationmark.circle"
        case .myDoDIssues: "checklist"
        case .issueQueue: "tray.2"
        }
    }

    /// Pull-request sidebar tabs (show review metadata in detail).
    public var isPRSection: Bool {
        switch self {
        case .myPRs, .reviewNeeded: true
        case .myIssues, .myDoDIssues, .issueQueue: false
        }
    }

    /// Maps legacy Int-encoded section values from schema v1 snapshots.
    init?(legacyRawValue: Int) {
        switch legacyRawValue {
        case 0: self = .myPRs
        case 1: self = .reviewNeeded
        case 2: self = .myIssues
        case 3: self = .myDoDIssues
        case 4: self = .issueQueue
        default: return nil
        }
    }
}

public enum IssueState: String, Sendable, Hashable, Codable {
    case open = "OPEN"
    case closed = "CLOSED"
    case merged = "MERGED"

    public var label: String { rawValue.lowercased() }

    init(graphQLState: String) {
        self = IssueState(rawValue: graphQLState.uppercased()) ?? .open
    }
}

public enum ReviewStatus: String, Sendable, Hashable, Codable {
    case approved
    case changesRequested = "changes_requested"
    case pending

    public var badgeSymbol: String? {
        switch self {
        case .approved: "checkmark.circle.fill"
        case .changesRequested: "xmark.circle.fill"
        case .pending: "clock.fill"
        }
    }

    public var badgeLabel: String {
        switch self {
        case .approved: "Approved"
        case .changesRequested: "Changes Requested"
        case .pending: "Pending Review"
        }
    }

    init(graphQLReviewStates: [String]) {
        if graphQLReviewStates.contains("CHANGES_REQUESTED") {
            self = .changesRequested
        } else if graphQLReviewStates.contains("APPROVED") {
            self = .approved
        } else {
            self = .pending
        }
    }
}

public struct ItemComment: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let author: String
    public let body: String
    public let createdAt: Date

    public init(id: String, author: String, body: String, createdAt: Date) {
        self.id = id
        self.author = author
        self.body = body
        self.createdAt = createdAt
    }
}

public struct DashboardItem: Sendable, Identifiable, Hashable, Codable {
    public let id: String
    public let number: Int
    public let title: String
    public let body: String
    public let url: String
    public let host: String
    public let repo: String
    public let state: IssueState
    public let isDraft: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let author: String
    public let labels: [String]
    public let section: DashboardSection
    public let comments: [ItemComment]
    public let reviewStatus: ReviewStatus?

    public var displayHost: String {
        host.replacingOccurrences(of: #"^https?://"#, with: "", options: .regularExpression)
    }

    public var stateLabel: String { state.label }

    public var reviewBadge: String? { reviewStatus?.badgeSymbol }

    public var reviewBadgeLabel: String { reviewStatus?.badgeLabel ?? "" }

    public init(
        id: String,
        number: Int,
        title: String,
        body: String,
        url: String,
        host: String,
        repo: String,
        state: IssueState,
        isDraft: Bool,
        createdAt: Date,
        updatedAt: Date,
        author: String,
        labels: [String],
        section: DashboardSection,
        comments: [ItemComment],
        reviewStatus: ReviewStatus?
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.url = url
        self.host = host
        self.repo = repo
        self.state = state
        self.isDraft = isDraft
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.author = author
        self.labels = labels
        self.section = section
        self.comments = comments
        self.reviewStatus = reviewStatus
    }
}
