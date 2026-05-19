import Foundation

/// Pure search/filter logic for dashboard items (testable without SwiftUI).
public enum DashboardItemSearch: Sendable {
    public static let defaultResultLimit = 20

    /// Whitespace-separated terms; empty query yields no terms (caller returns no results).
    public static func parseTerms(from query: String) -> [String] {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).lowercased() }
    }

    /// Lowercased text used for substring matching across item fields.
    public static func haystack(for item: DashboardItem) -> String {
        [
            item.title,
            item.repo,
            item.author,
            item.body,
            item.host,
            item.displayHost,
            item.labels.joined(separator: " "),
            "#\(item.number)",
            String(item.number),
            item.section.label,
        ]
        .joined(separator: " ")
        .lowercased()
    }

    public static func matches(item: DashboardItem, terms: [String]) -> Bool {
        guard !terms.isEmpty else { return false }
        let haystack = haystack(for: item)
        return terms.allSatisfy { haystack.contains($0) }
    }

    /// Returns items in `visibleSections` matching all query terms, newest first, capped at `limit`.
    public static func search(
        items: [DashboardItem],
        visibleSections: some Sequence<DashboardSection>,
        query: String,
        limit: Int = defaultResultLimit
    ) -> [DashboardItem] {
        let terms = parseTerms(from: query)
        guard !terms.isEmpty else { return [] }

        let visible = Set(visibleSections)
        return items
            .filter { visible.contains($0.section) }
            .filter { matches(item: $0, terms: terms) }
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                if $0.host != $1.host { return $0.host < $1.host }
                return $0.number < $1.number
            }
            .prefix(max(0, limit))
            .map { $0 }
    }
}
