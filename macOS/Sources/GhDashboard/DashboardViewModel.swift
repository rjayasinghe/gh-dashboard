import SwiftUI
import Core

@Observable
@MainActor
final class DashboardViewModel {
    var section: DashboardSection = .myPRs
    var items: [DashboardItem] = []
    var selectedItemID: DashboardItem.ID?
    var errorsByHost: [String: String] = [:]
    var isLoading = false
    var lastFetch: Date?
    var configError: String?

    private var hosts: [String] = []
    private var myDoDIssuesSettings: MyDoDIssuesSettings?
    private var credentials: [String: String] = [:]
    private let refreshInterval: TimeInterval = 300

    /// Sidebar rows; omits **My issues** (`.myDoDIssues`) when that feature is not configured.
    var visibleSections: [DashboardSection] {
        DashboardSection.allCases.filter { sec in
            sec != .myDoDIssues || myDoDIssuesSettings != nil
        }
    }

    var selectedItem: DashboardItem? {
        guard let id = selectedItemID else { return nil }
        return items.first { $0.id == id }
    }

    var filteredItems: [DashboardItem] {
        items.filter { $0.section == section }
    }

    var groupedByHost: [(host: String, items: [DashboardItem])] {
        let filtered = filteredItems
        var order: [String] = []
        var dict: [String: [DashboardItem]] = [:]
        for item in filtered {
            if dict[item.host] == nil { order.append(item.host) }
            dict[item.host, default: []].append(item)
        }
        return order.map { ($0, dict[$0]!) }
    }

    func sectionCount(_ sec: DashboardSection) -> Int {
        items.filter { $0.section == sec }.count
    }

    func loadConfig() {
        do {
            let cfg = try ConfigLoader.load()
            hosts = cfg.hosts
            myDoDIssuesSettings = cfg.myDoDIssues
            configError = nil
        } catch {
            configError = error.localizedDescription
            hosts = []
            myDoDIssuesSettings = nil
        }
        normalizeSectionAndSelectionForFilteredIssuesTab()
    }

    func loadCredentials() {
        for host in hosts {
            if let token = CredentialStore.token(forHost: host) {
                credentials[host] = token
            } else {
                errorsByHost[host] = "No token found. Run: gh auth login --hostname \(host)"
            }
        }
    }

    func loadCache() {
        guard let snapshot = SnapshotStore.load() else { return }
        var loaded = snapshot.items
        if myDoDIssuesSettings == nil {
            loaded.removeAll { $0.section == .myDoDIssues }
        }
        items = loaded
        lastFetch = snapshot.savedAt
        normalizeSectionAndSelectionForFilteredIssuesTab()
    }

    private func normalizeSectionAndSelectionForFilteredIssuesTab() {
        if section == .myDoDIssues, myDoDIssuesSettings == nil {
            section = .myPRs
        }
        if let id = selectedItemID, let item = items.first(where: { $0.id == id }) {
            if item.section == .myDoDIssues, myDoDIssuesSettings == nil {
                selectedItemID = nil
            }
        }
    }

    func refresh() async {
        guard !hosts.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let previousItems = items
        var successfulHosts: Set<String> = []
        var fetchedItems: [DashboardItem] = []
        var newErrors: [String: String] = [:]

        let hostsSnapshot = hosts
        let dodSnapshot = myDoDIssuesSettings

        await withTaskGroup(of: (String, Result<[DashboardItem], Error>).self) { group in
            for host in hostsSnapshot {
                guard let token = credentials[host] else {
                    newErrors[host] = "No token"
                    continue
                }
                let client = GraphQLClient(host: host, token: token)
                let dodForHost: MyDoDIssuesSettings? = {
                    guard let dod = dodSnapshot else { return nil }
                    guard hostsSnapshot.contains(dod.host), dod.host == host else { return nil }
                    return dod
                }()
                group.addTask {
                    do {
                        let items = try await client.fetchAll(myDoDIssues: dodForHost)
                        return (host, .success(items))
                    } catch {
                        return (host, .failure(error))
                    }
                }
            }
            for await (host, result) in group {
                switch result {
                case .success(let fetched):
                    fetchedItems.append(contentsOf: fetched)
                    successfulHosts.insert(host)
                case .failure(let error):
                    newErrors[host] = error.localizedDescription
                }
            }
        }

        // Merge: keep cached items for hosts that failed; replace with fresh data for hosts that succeeded.
        var merged = fetchedItems
        for item in previousItems where !successfulHosts.contains(item.host) {
            merged.append(item)
        }

        if dodSnapshot == nil {
            merged.removeAll { $0.section == .myDoDIssues }
        }

        merged.sort {
            if $0.host != $1.host { return $0.host < $1.host }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.number < $1.number
        }

        items = merged
        errorsByHost = newErrors
        lastFetch = Date()
        normalizeSectionAndSelectionForFilteredIssuesTab()

        SnapshotStore.save(PersistedSnapshot(items: merged))
    }

    func startPeriodicRefresh() async {
        loadConfig()
        loadCredentials()
        loadCache()
        await Task.yield()
        await refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(refreshInterval))
            guard !Task.isCancelled else { break }
            await refresh()
        }
    }
}
