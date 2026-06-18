import Foundation
import Testing

@testable import Core

@Suite struct ChangeDetectorTests {
    private func item(
        id: String = "h-pr-1",
        number: Int = 1,
        title: String = "Title",
        repo: String = "owner/repo",
        host: String = "github.com",
        state: IssueState = .open,
        isDraft: Bool = false,
        updatedAt: Date = Date(timeIntervalSince1970: 1_000_000),
        section: DashboardSection = .myPRs,
        comments: [ItemComment] = []
    ) -> DashboardItem {
        DashboardItem(
            id: id,
            number: number,
            title: title,
            body: "",
            url: "https://example.test/\(id)",
            host: host,
            repo: repo,
            state: state,
            isDraft: isDraft,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: updatedAt,
            author: "alice",
            labels: [],
            section: section,
            comments: comments,
            reviewStatus: nil
        )
    }

    private func comment(id: String, author: String = "bob", body: String = "lgtm") -> ItemComment {
        ItemComment(id: id, author: author, body: body, createdAt: Date(timeIntervalSince1970: 1_500))
    }

    @Test func newItemEmitsNewItem() {
        let new = item(id: "h-pr-1")
        let changes = ChangeDetector.detect(old: [], new: [new], settings: .default)
        #expect(changes.count == 1)
        if case .newItem(let i) = changes[0] {
            #expect(i.id == "h-pr-1")
        } else {
            Issue.record("expected .newItem, got \(changes[0])")
        }
    }

    @Test func unchangedItemEmitsNothing() {
        let a = item(id: "h-pr-1")
        let changes = ChangeDetector.detect(old: [a], new: [a], settings: .default)
        #expect(changes.isEmpty)
    }

    @Test func laterUpdatedAtEmitsUpdated() {
        let old = item(id: "h-pr-1", updatedAt: Date(timeIntervalSince1970: 1_000_000))
        let new = item(id: "h-pr-1", updatedAt: Date(timeIntervalSince1970: 2_000_000))
        let changes = ChangeDetector.detect(old: [old], new: [new], settings: .default)
        #expect(changes.count == 1)
        if case .updated(let o, let n) = changes[0] {
            #expect(o.updatedAt < n.updatedAt)
        } else {
            Issue.record("expected .updated, got \(changes[0])")
        }
    }

    @Test func stateChangeSupersedesUpdate() {
        let old = item(id: "h-pr-1", state: .open, updatedAt: Date(timeIntervalSince1970: 1_000_000))
        let new = item(id: "h-pr-1", state: .merged, updatedAt: Date(timeIntervalSince1970: 2_000_000))
        let changes = ChangeDetector.detect(old: [old], new: [new], settings: .default)
        #expect(changes.count == 1)
        if case .stateChanged(_, let n) = changes[0] {
            #expect(n.state == .merged)
        } else {
            Issue.record("expected .stateChanged, got \(changes[0])")
        }
    }

    @Test func draftFlipIsStateChange() {
        let old = item(id: "h-pr-1", isDraft: true)
        let new = item(id: "h-pr-1", isDraft: false)
        let changes = ChangeDetector.detect(old: [old], new: [new], settings: .default)
        #expect(changes.count == 1)
        if case .stateChanged = changes[0] {} else {
            Issue.record("expected .stateChanged, got \(changes[0])")
        }
    }

    @Test func newCommentEmitsOnePerComment() {
        let old = item(id: "h-pr-1", comments: [comment(id: "c1")])
        let new = item(
            id: "h-pr-1",
            comments: [comment(id: "c1"), comment(id: "c2"), comment(id: "c3")]
        )
        let changes = ChangeDetector.detect(old: [old], new: [new], settings: .default)
        let commentChanges = changes.compactMap { change -> String? in
            if case .newComment(_, let c) = change { return c.id }
            return nil
        }
        #expect(commentChanges == ["c2", "c3"])
    }

    @Test func commentOnlyChangeDoesNotEmitUpdated() {
        // Same updatedAt — only the comments array grew. We should still get the comment notification
        // and NOT a stale .updated.
        let old = item(id: "h-pr-1", comments: [comment(id: "c1")])
        let new = item(id: "h-pr-1", comments: [comment(id: "c1"), comment(id: "c2")])
        let changes = ChangeDetector.detect(old: [old], new: [new], settings: .default)
        #expect(changes.count == 1)
        if case .newComment(_, let c) = changes[0] {
            #expect(c.id == "c2")
        } else {
            Issue.record("expected .newComment, got \(changes[0])")
        }
    }

    @Test func disabledMasterSwitchSuppressesAll() {
        let old = item(id: "h-pr-1", state: .open, comments: [])
        let new = item(id: "h-pr-2", state: .merged, comments: [comment(id: "c1")])
        let off = NotificationSettings(
            enabled: false,
            notifyNewItems: true,
            notifyUpdates: true,
            notifyComments: true,
            notifyStateChanges: true
        )
        #expect(ChangeDetector.detect(old: [old], new: [new], settings: off).isEmpty)
    }

    @Test func disabledNewItemsSuppressesNewItem() {
        let new = item(id: "h-pr-1")
        let settings = NotificationSettings(
            enabled: true,
            notifyNewItems: false,
            notifyUpdates: true,
            notifyComments: true,
            notifyStateChanges: true
        )
        #expect(ChangeDetector.detect(old: [], new: [new], settings: settings).isEmpty)
    }

    @Test func disabledCommentsSuppressesComments() {
        let old = item(id: "h-pr-1", comments: [comment(id: "c1")])
        let new = item(id: "h-pr-1", comments: [comment(id: "c1"), comment(id: "c2")])
        let settings = NotificationSettings(
            enabled: true,
            notifyNewItems: true,
            notifyUpdates: true,
            notifyComments: false,
            notifyStateChanges: true
        )
        #expect(ChangeDetector.detect(old: [old], new: [new], settings: settings).isEmpty)
    }

    @Test func removedItemsAreIgnored() {
        let removed = item(id: "h-pr-1")
        let kept = item(id: "h-pr-2")
        let changes = ChangeDetector.detect(old: [removed, kept], new: [kept], settings: .default)
        #expect(changes.isEmpty)
    }

    @Test func disabledStateChangesSuppressesEvenWhenUpdatedAtAdvances() {
        // When state-change notifications are off but updates are on, a state change with a newer
        // updatedAt should NOT silently become an .updated — the detector treats them as distinct
        // categories. Verify the change is suppressed entirely.
        let old = item(id: "h-pr-1", state: .open, updatedAt: Date(timeIntervalSince1970: 1_000_000))
        let new = item(id: "h-pr-1", state: .merged, updatedAt: Date(timeIntervalSince1970: 2_000_000))
        let settings = NotificationSettings(
            enabled: true,
            notifyNewItems: true,
            notifyUpdates: true,
            notifyComments: true,
            notifyStateChanges: false
        )
        #expect(ChangeDetector.detect(old: [old], new: [new], settings: settings).isEmpty)
    }
}
