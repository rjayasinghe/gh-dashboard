import Foundation
import Testing

@testable import Core

@Suite struct ReviewStatusAndCommentsTests {
    @Test func changesRequestedTakesPriorityOverApproved() {
        #expect(
            deriveReviewStatus([GQLReview(state: "APPROVED"), GQLReview(state: "CHANGES_REQUESTED")]) == .changesRequested
        )
    }

    @Test func approvedWhenNoChangesRequested() {
        #expect(
            deriveReviewStatus([GQLReview(state: "APPROVED"), GQLReview(state: "COMMENTED")]) == .approved
        )
    }

    @Test func pendingWhenEmpty() {
        #expect(deriveReviewStatus([]) == .pending)
    }

    @Test func pendingWithOnlyCommented() {
        #expect(deriveReviewStatus([GQLReview(state: "COMMENTED")]) == .pending)
    }

    @Test func newestFirstCommentOrdering() {
        let old = GQLCommentNode(id: "1", author: GQLActor(login: "a"), body: "old", createdAt: Date(timeIntervalSince1970: 100))
        let new = GQLCommentNode(id: "2", author: GQLActor(login: "b"), body: "new", createdAt: Date(timeIntervalSince1970: 200))
        let ordered = commentsNewestFirst([old, new])
        #expect(ordered.count == 2)
        #expect(ordered[0].author == "b")
        #expect(ordered[0].id == "2")
        #expect(ordered[1].author == "a")
    }

    @Test func emptyCommentOrdering() {
        #expect(commentsNewestFirst([]).isEmpty)
    }
}
