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
    private var credentials: [String: String] = [:]
    private let refreshInterval: TimeInterval = 300

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
            configError = nil
        } catch {
            configError = error.localizedDescription
        }
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

    func refresh() async {
        guard !hosts.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        var allItems: [DashboardItem] = []
        var newErrors: [String: String] = [:]

        await withTaskGroup(of: (String, Result<[DashboardItem], Error>).self) { group in
            for host in hosts {
                guard let token = credentials[host] else {
                    newErrors[host] = "No token"
                    continue
                }
                let client = GraphQLClient(host: host, token: token)
                group.addTask {
                    do {
                        let items = try await client.fetchAll()
                        return (host, .success(items))
                    } catch {
                        return (host, .failure(error))
                    }
                }
            }
            for await (host, result) in group {
                switch result {
                case .success(let fetched):
                    allItems.append(contentsOf: fetched)
                    newErrors.removeValue(forKey: host)
                case .failure(let error):
                    newErrors[host] = error.localizedDescription
                }
            }
        }

        allItems.sort {
            if $0.host != $1.host { return $0.host < $1.host }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.number < $1.number
        }

        items = allItems
        errorsByHost = newErrors
        lastFetch = Date()
    }

    func startPeriodicRefresh() async {
        loadConfig()
        loadCredentials()
        await refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(refreshInterval))
            guard !Task.isCancelled else { break }
            await refresh()
        }
    }
}
