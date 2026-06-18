import Foundation

/// Pure diff between two `DashboardItem` arrays — produces a `[DashboardChange]` filtered by
/// the user's `NotificationSettings`. Side-effect free; tested directly without notification stubs.
public enum ChangeDetector {
    /// Compare `old` (the in-memory items before refresh) to `new` (items after the merge step) and
    /// emit one change per detected delta. Order roughly matches `new` for predictable notification
    /// sequencing.
    ///
    /// Items removed from `new` are intentionally ignored — closed/merged transitions are detected
    /// via `.stateChanged` while the item is still present in the fetch, and an item dropping out of
    /// the search results (e.g., reassigned away) is not a notification-worthy event.
    public static func detect(
        old: [DashboardItem],
        new: [DashboardItem],
        settings: NotificationSettings
    ) -> [DashboardChange] {
        guard settings.enabled else { return [] }

        var oldByID: [String: DashboardItem] = [:]
        oldByID.reserveCapacity(old.count)
        for item in old { oldByID[item.id] = item }

        var changes: [DashboardChange] = []
        for item in new {
            guard let prior = oldByID[item.id] else {
                if settings.notifyNewItems {
                    changes.append(.newItem(item))
                }
                continue
            }

            // State transition supersedes a generic update — they share the same `updatedAt` bump
            // and the state-change framing is more useful (e.g., "PR merged" vs "Updated").
            let stateChanged = prior.state != item.state || prior.isDraft != item.isDraft
            if stateChanged {
                if settings.notifyStateChanges {
                    changes.append(.stateChanged(old: prior, new: item))
                }
            } else if item.updatedAt > prior.updatedAt {
                if settings.notifyUpdates {
                    changes.append(.updated(old: prior, new: item))
                }
            }

            // New comments are emitted independently of `.updated` so a comment-only change still
            // surfaces — and so each new comment gets its own actionable banner.
            if settings.notifyComments {
                let priorCommentIDs = Set(prior.comments.map { $0.id })
                for comment in item.comments where !priorCommentIDs.contains(comment.id) {
                    changes.append(.newComment(item: item, comment: comment))
                }
            }
        }
        return changes
    }
}
