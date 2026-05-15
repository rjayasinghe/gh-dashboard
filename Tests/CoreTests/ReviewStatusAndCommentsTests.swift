import Foundation
import XCTest

@testable import Core

final class ReviewStatusAndCommentsTests: XCTestCase {
    func testChangesRequestedTakesPriorityOverApproved() {
        XCTAssertEqual(
            deriveReviewStatus([GQLReview(state: "APPROVED"), GQLReview(state: "CHANGES_REQUESTED")]),
            "changes_requested",
            "changes_requested takes priority over approved"
        )
    }

    func testApprovedWhenNoChangesRequested() {
        XCTAssertEqual(
            deriveReviewStatus([GQLReview(state: "APPROVED"), GQLReview(state: "COMMENTED")]),
            "approved"
        )
    }

    func testPendingWhenEmpty() {
        XCTAssertEqual(deriveReviewStatus([]), "pending")
    }

    func testPendingWithOnlyCommented() {
        XCTAssertEqual(deriveReviewStatus([GQLReview(state: "COMMENTED")]), "pending")
    }

    func testNewestFirstCommentOrdering() {
        let old = GQLCommentNode(author: GQLActor(login: "a"), body: "old", createdAt: Date(timeIntervalSince1970: 100))
        let new = GQLCommentNode(author: GQLActor(login: "b"), body: "new", createdAt: Date(timeIntervalSince1970: 200))
        let ordered = commentsNewestFirst([old, new])
        XCTAssertEqual(ordered.count, 2)
        XCTAssertEqual(ordered[0].author, "b")
        XCTAssertEqual(ordered[1].author, "a")
    }

    func testEmptyCommentOrdering() {
        XCTAssertTrue(commentsNewestFirst([]).isEmpty)
    }
}

