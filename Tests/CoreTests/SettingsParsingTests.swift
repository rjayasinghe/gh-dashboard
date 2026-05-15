import XCTest

@testable import Core

final class SettingsParsingTests: XCTestCase {
    func testMyDoDIssuesSearchQueryWithExcludeLabel() {
        let filteredIssues = MyDoDIssuesSettings(
            host: "git.example.com",
            repository: "acme/widget",
            excludeLabels: ["waiting on customer"]
        )
        XCTAssertEqual(
            filteredIssues.searchQuery,
            "repo:acme/widget is:issue is:open assignee:@me archived:false -label:\"waiting on customer\""
        )
    }

    func testMyDoDIssuesSearchQueryWithMultipleExcludeLabels() {
        let filteredMulti = MyDoDIssuesSettings(
            host: "git.example.com",
            repository: "acme/widget",
            excludeLabels: ["waiting on customer", "blocked"]
        )
        XCTAssertEqual(
            filteredMulti.searchQuery,
            "repo:acme/widget is:issue is:open assignee:@me archived:false -label:\"waiting on customer\" -label:\"blocked\""
        )
    }

    func testParseCommaSeparatedLabels() {
        XCTAssertEqual(
            MyDoDIssuesSettings.parseCommaSeparatedLabels(" Author Action , Foo Bar ").joined(separator: "|"),
            "Author Action|Foo Bar"
        )
    }

    func testParseMyIssuesToml() {
        let myIssuesToml = """
        [github]
        hosts = ["git.example.com"]

        [my_issues]
        host = "git.example.com"
        repository = "org/custom"
        exclude_labels = "Foo Bar, Baz Qux"
        """
        let parsed = MyDoDIssuesSettings.parse(fromToml: myIssuesToml)
        XCTAssertEqual(parsed?.repository, "org/custom")
        XCTAssertEqual(parsed?.excludeLabels, ["Foo Bar", "Baz Qux"])
    }

    func testParseLegacyMyDodIssuesToml() {
        let legacyToml = """
        [github]
        hosts = ["git.example.com"]

        [my_dod_issues]
        host = "git.example.com"
        repository = "legacy/repo"
        exclude_labels = "Stale"
        """
        let parsed = MyDoDIssuesSettings.parse(fromToml: legacyToml)
        XCTAssertEqual(parsed?.repository, "legacy/repo")
        XCTAssertEqual(parsed?.excludeLabels, ["Stale"])
    }

    func testParseMyIssuesAbsentOrIncomplete() {
        XCTAssertNil(MyDoDIssuesSettings.parse(fromToml: "[github]\nhosts = [\"a\"]\n"))
        XCTAssertNil(MyDoDIssuesSettings.parse(fromToml: "[github]\nhosts = [\"a\"]\n\n[my_issues]\n"))
        XCTAssertNil(MyDoDIssuesSettings.parse(fromToml: "[github]\nhosts = [\"a\"]\n\n[my_issues]\nhost = \"a\"\n"))
    }

    func testMyIssuesSearchQueryWithoutExcludeLabels() {
        XCTAssertEqual(
            MyDoDIssuesSettings(host: "h", repository: "o/r", excludeLabels: []).searchQuery,
            "repo:o/r is:issue is:open assignee:@me archived:false"
        )
    }

    func testBlankExcludeLabelsSkippedInQuery() {
        XCTAssertEqual(
            MyDoDIssuesSettings(host: "h", repository: "o/r", excludeLabels: ["", "   "]).searchQuery,
            "repo:o/r is:issue is:open assignee:@me archived:false"
        )
    }

    func testParseRepoAliasAndLegacyExcludeLabel() {
        let myIssuesAliasToml = """
        [github]
        hosts = ["git.example.com"]

        [my_issues]
        host = "git.example.com"
        repo = "alias/repo"
        exclude_label = "Foo, Bar"
        """
        let parsed = MyDoDIssuesSettings.parse(fromToml: myIssuesAliasToml)
        XCTAssertEqual(parsed?.repository, "alias/repo")
        XCTAssertEqual(parsed?.excludeLabels, ["Foo", "Bar"])
    }

    func testIssueQueueSingleLabelQuery() {
        let queueOne = IssueQueueSettings(host: "git.example.com", repository: "acme/inbox", includeLabels: ["ready"])
        XCTAssertEqual(
            queueOne.searchQuery,
            "repo:acme/inbox is:issue is:open no:assignee archived:false label:\"ready\""
        )
    }

    func testIssueQueueMultipleLabelsOrQuery() {
        let queueMulti = IssueQueueSettings(host: "git.example.com", repository: "acme/inbox", includeLabels: ["ready", "queued"])
        XCTAssertEqual(
            queueMulti.searchQuery,
            "repo:acme/inbox is:issue is:open no:assignee archived:false (label:\"ready\" OR label:\"queued\")"
        )
    }

    func testParseIssueQueueToml() {
        let queueToml = """
        [github]
        hosts = ["git.example.com"]

        [issue_queue]
        host = "git.example.com"
        repository = "acme/inbox"
        include_labels = "ready, queued"
        """
        let parsed = IssueQueueSettings.parse(fromToml: queueToml)
        XCTAssertEqual(parsed?.repository, "acme/inbox")
        XCTAssertEqual(parsed?.includeLabels, ["ready", "queued"])
    }

    func testParseIssueQueueAbsentOrIncomplete() {
        XCTAssertNil(IssueQueueSettings.parse(fromToml: "[github]\nhosts = [\"a\"]\n"))
        XCTAssertNil(
            IssueQueueSettings.parse(fromToml: "[github]\nhosts = [\"a\"]\n\n[issue_queue]\nhost = \"a\"\nrepository = \"b/c\"\n")
        )
    }

    func testParseRepoAliasAndLegacyIncludeLabel() {
        let queueAliasToml = """
        [github]
        hosts = ["git.example.com"]

        [issue_queue]
        host = "git.example.com"
        repo = "alias/queue"
        include_label = "ready, queued"
        """
        let parsed = IssueQueueSettings.parse(fromToml: queueAliasToml)
        XCTAssertEqual(parsed?.repository, "alias/queue")
        XCTAssertEqual(parsed?.includeLabels, ["ready", "queued"])
    }

    func testWhitespaceOnlyIncludeLabelsNil() {
        let toml = """
        [github]
        hosts = ["git.example.com"]

        [issue_queue]
        host = "git.example.com"
        repository = "o/r"
        include_labels = ",  ,"
        """
        XCTAssertNil(IssueQueueSettings.parse(fromToml: toml))
    }

    func testIssueQueueSearchQueryEmptyWhenNoLabels() {
        XCTAssertEqual(IssueQueueSettings(host: "h", repository: "o/r", includeLabels: []).searchQuery, "")
        XCTAssertEqual(IssueQueueSettings(host: "h", repository: "o/r", includeLabels: ["", "  "]).searchQuery, "")
    }
}

