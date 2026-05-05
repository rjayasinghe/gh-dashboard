import Foundation

public enum DashboardSection: Int, Sendable, CaseIterable, Identifiable, Hashable {
    case myPRs = 0
    case reviewNeeded = 1
    case myIssues = 2

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .myPRs: "My PRs"
        case .reviewNeeded: "Review Needed"
        case .myIssues: "Issues"
        }
    }

    public var systemImage: String {
        switch self {
        case .myPRs: "arrow.triangle.pull"
        case .reviewNeeded: "eye"
        case .myIssues: "exclamationmark.circle"
        }
    }
}

public struct ItemComment: Sendable, Hashable, Codable, Identifiable {
    public var id: String { "\(author)-\(createdAt.timeIntervalSince1970)" }
    public let author: String
    public let body: String
    public let createdAt: Date
}

public struct DashboardItem: Sendable, Identifiable, Hashable {
    public let id: String
    public let number: Int
    public let title: String
    public let url: String
    public let host: String
    public let repo: String
    public let state: String
    public let isDraft: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let author: String
    public let labels: [String]
    public let section: DashboardSection
    public let comments: [ItemComment]
    public let reviewStatus: String

    public var displayHost: String {
        host
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    public var stateLabel: String { state.lowercased() }

    public var reviewBadge: String? {
        switch reviewStatus {
        case "approved": "checkmark.circle.fill"
        case "changes_requested": "xmark.circle.fill"
        case "pending": "clock.fill"
        default: nil
        }
    }

    public var reviewBadgeLabel: String {
        switch reviewStatus {
        case "approved": "Approved"
        case "changes_requested": "Changes Requested"
        case "pending": "Pending Review"
        default: ""
        }
    }
}
