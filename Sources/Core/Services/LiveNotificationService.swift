import Foundation
import UserNotifications

/// Dispatches `DashboardChange`s as macOS user notifications. Wraps `UNUserNotificationCenter`.
///
/// Authorization is requested lazily on first call to `requestAuthorizationIfNeeded()`. Subsequent
/// calls are no-ops (the framework caches the user's decision). If the user denies, `notify(_:)`
/// silently drops banners — there's no in-app fallback by design (notifications are best-effort).
public struct LiveNotificationService: NotificationDispatching {
    public init() {}

    public func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        case .denied, .authorized, .provisional, .ephemeral:
            return
        @unknown default:
            return
        }
    }

    public func notify(_ change: DashboardChange) async {
        let content = UNMutableNotificationContent()
        let (title, body, item, discriminator) = format(change)
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["url": item.url, "itemID": item.id]

        // Identifier coalesces duplicate notifications for the same change (e.g., the same comment
        // re-detected after a transient cache wipe won't double-fire).
        let identifier = "\(item.id)-\(discriminator)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Returns `(title, body, item, identifierDiscriminator)` for a change.
    private func format(_ change: DashboardChange) -> (String, String, DashboardItem, String) {
        switch change {
        case .newItem(let item):
            let kind = item.section.isPRSection ? "PR" : "issue"
            let title = "New \(kind) in \(item.repo)"
            let body = "#\(item.number) \(item.title)"
            return (title, body, item, "new")

        case .updated(_, let new):
            let title = "Updated: \(new.repo)"
            let body = "#\(new.number) \(new.title)"
            return (title, body, new, "upd-\(new.updatedAt.timeIntervalSince1970)")

        case .newComment(let item, let comment):
            let title = "\(comment.author) commented on #\(item.number)"
            let body = trim(comment.body, to: 140)
            return (title, body, item, "cmt-\(comment.id)")

        case .stateChanged(_, let new):
            let title = stateChangeTitle(for: new)
            let body = "#\(new.number) \(new.title)"
            return (title, body, new, "state-\(new.state.rawValue)-\(new.isDraft)")
        }
    }

    private func stateChangeTitle(for item: DashboardItem) -> String {
        let kind = item.section.isPRSection ? "PR" : "Issue"
        switch item.state {
        case .merged: return "PR merged"
        case .closed: return "\(kind) closed"
        case .open: return item.isDraft ? "PR moved to draft" : "PR ready for review"
        }
    }

    private func trim(_ text: String, to max: Int) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > max else { return cleaned }
        return cleaned.prefix(max - 1) + "…"
    }
}
