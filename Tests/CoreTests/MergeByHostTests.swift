import Testing

@testable import Core

@Suite struct MergeByHostTests {
    @Test func failedHostRetainsCachedItems() {
        let cached = [
            DashboardItem(
                id: "a-pr-1",
                number: 1,
                title: "A1",
                body: "",
                url: "",
                host: "hostA",
                repo: "r",
                state: .open,
                isDraft: false,
                createdAt: .now,
                updatedAt: .now,
                author: "x",
                labels: [],
                section: .myPRs,
                comments: [],
                reviewStatus: nil
            ),
            DashboardItem(
                id: "b-pr-2",
                number: 2,
                title: "B2",
                body: "",
                url: "",
                host: "hostB",
                repo: "r",
                state: .open,
                isDraft: false,
                createdAt: .now,
                updatedAt: .now,
                author: "y",
                labels: [],
                section: .reviewNeeded,
                comments: [],
                reviewStatus: nil
            ),
        ]

        let freshFromA = [
            DashboardItem(
                id: "a-pr-3",
                number: 3,
                title: "A3-new",
                body: "",
                url: "",
                host: "hostA",
                repo: "r",
                state: .open,
                isDraft: false,
                createdAt: .now,
                updatedAt: .now,
                author: "x",
                labels: [],
                section: .myPRs,
                comments: [],
                reviewStatus: nil
            ),
        ]

        let successfulHosts: Set<String> = ["hostA"]

        var merged = freshFromA
        for item in cached where !successfulHosts.contains(item.host) {
            merged.append(item)
        }

        #expect(merged.count == 2)
        #expect(merged.contains(where: { $0.id == "a-pr-3" }))
        #expect(!merged.contains(where: { $0.id == "a-pr-1" }))
        #expect(merged.contains(where: { $0.id == "b-pr-2" }))
    }
}
