import Foundation

public protocol ConfigLoading: Sendable {
    func loadConfig() throws -> AppConfig
}

public protocol CredentialProviding: Sendable {
    func token(forHost host: String) async -> String?
}

public protocol SnapshotPersisting: Sendable {
    func load() -> PersistedSnapshot?
    func save(_ snapshot: PersistedSnapshot)
}

public protocol ItemFetching: Sendable {
    func fetchItems(
        host: String,
        token: String,
        myDoDIssues: MyDoDIssuesSettings?,
        issueQueue: IssueQueueSettings?
    ) async throws -> [DashboardItem]
}

/// One detected change between two refresh snapshots. `ChangeDetector` produces these;
/// `NotificationDispatching` consumes them.
public enum DashboardChange: Sendable, Equatable {
    /// Item appeared in the new fetch but wasn't in the prior set.
    case newItem(DashboardItem)
    /// Same id, but `updatedAt` advanced (and not categorized as state change).
    case updated(old: DashboardItem, new: DashboardItem)
    /// Same id, with a comment whose id wasn't in the prior cached value.
    case newComment(item: DashboardItem, comment: ItemComment)
    /// Same id, but `state` or `isDraft` changed (e.g., open → merged).
    case stateChanged(old: DashboardItem, new: DashboardItem)
}

public protocol NotificationDispatching: Sendable {
    /// Request banner permission once. Idempotent — safe to call on every launch.
    func requestAuthorizationIfNeeded() async
    /// Deliver a single notification for one detected change.
    func notify(_ change: DashboardChange) async
}

public struct LiveConfigLoader: ConfigLoading {
    private let path: String

    public init(path: String = ConfigLoader.defaultPath) {
        self.path = path
    }

    public func loadConfig() throws -> AppConfig {
        try ConfigLoader.load(path: path)
    }
}

public struct LiveCredentialProvider: CredentialProviding {
    public init() {}

    public func token(forHost host: String) async -> String? {
        await Task.detached {
            CredentialStore.token(forHost: host)
        }.value
    }
}

public struct LiveSnapshotStore: SnapshotPersisting {
    public init() {}

    public func load() -> PersistedSnapshot? {
        SnapshotStore.load()
    }

    public func save(_ snapshot: PersistedSnapshot) {
        SnapshotStore.save(snapshot)
    }
}

public struct LiveItemFetcher: ItemFetching {
    private let transport: URLSessionTransport

    public init(transport: URLSessionTransport = URLSessionTransport()) {
        self.transport = transport
    }

    public func fetchItems(
        host: String,
        token: String,
        myDoDIssues: MyDoDIssuesSettings?,
        issueQueue: IssueQueueSettings?
    ) async throws -> [DashboardItem] {
        let client = GraphQLClient(host: host, token: token, transport: transport)
        return try await client.fetchAll(myDoDIssues: myDoDIssues, issueQueue: issueQueue)
    }
}
