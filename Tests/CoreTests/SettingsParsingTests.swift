import Testing

@testable import Core

@Suite struct SettingsParsingTests {
    @Test func myDoDIssuesSearchQueryWithExcludeLabel() {
        let filteredIssues = MyDoDIssuesSettings(
            host: "git.example.com",
            repository: "acme/widget",
            excludeLabels: ["waiting on customer"]
        )
        #expect(
            filteredIssues.searchQuery ==
            "repo:acme/widget is:issue is:open assignee:@me archived:false -label:\"waiting on customer\""
        )
    }

    @Test func myDoDIssuesSearchQueryWithMultipleExcludeLabels() {
        let filteredMulti = MyDoDIssuesSettings(
            host: "git.example.com",
            repository: "acme/widget",
            excludeLabels: ["waiting on customer", "blocked"]
        )
        #expect(
            filteredMulti.searchQuery ==
            "repo:acme/widget is:issue is:open assignee:@me archived:false -label:\"waiting on customer\" -label:\"blocked\""
        )
    }

    @Test func parseCommaSeparatedLabels() {
        #expect(
            MyDoDIssuesSettings.parseCommaSeparatedLabels(" Author Action , Foo Bar ").joined(separator: "|") ==
            "Author Action|Foo Bar"
        )
    }

    @Test func parseMyIssuesToml() {
        let myIssuesToml = """
        [github]
        hosts = ["git.example.com"]

        [my_issues]
        host = "git.example.com"
        repository = "org/custom"
        exclude_labels = "Foo Bar, Baz Qux"
        """
        let parsed = MyDoDIssuesSettings.parse(fromToml: myIssuesToml)
        #expect(parsed?.repository == "org/custom")
        #expect(parsed?.excludeLabels == ["Foo Bar", "Baz Qux"])
    }

    @Test func parseLegacyMyDodIssuesToml() {
        let legacyToml = """
        [github]
        hosts = ["git.example.com"]

        [my_dod_issues]
        host = "git.example.com"
        repository = "legacy/repo"
        exclude_labels = "Stale"
        """
        let parsed = MyDoDIssuesSettings.parse(fromToml: legacyToml)
        #expect(parsed?.repository == "legacy/repo")
        #expect(parsed?.excludeLabels == ["Stale"])
    }

    @Test func parseMyIssuesAbsentOrIncomplete() {
        #expect(MyDoDIssuesSettings.parse(fromToml: "[github]\nhosts = [\"a\"]\n") == nil)
        #expect(MyDoDIssuesSettings.parse(fromToml: "[github]\nhosts = [\"a\"]\n\n[my_issues]\n") == nil)
        #expect(MyDoDIssuesSettings.parse(fromToml: "[github]\nhosts = [\"a\"]\n\n[my_issues]\nhost = \"a\"\n") == nil)
    }

    @Test func myIssuesSearchQueryWithoutExcludeLabels() {
        #expect(
            MyDoDIssuesSettings(host: "h", repository: "o/r", excludeLabels: []).searchQuery ==
            "repo:o/r is:issue is:open assignee:@me archived:false"
        )
    }

    @Test func blankExcludeLabelsSkippedInQuery() {
        #expect(
            MyDoDIssuesSettings(host: "h", repository: "o/r", excludeLabels: ["", "   "]).searchQuery ==
            "repo:o/r is:issue is:open assignee:@me archived:false"
        )
    }

    @Test func parseRepoAliasAndLegacyExcludeLabel() {
        let myIssuesAliasToml = """
        [github]
        hosts = ["git.example.com"]

        [my_issues]
        host = "git.example.com"
        repo = "alias/repo"
        exclude_label = "Foo, Bar"
        """
        let parsed = MyDoDIssuesSettings.parse(fromToml: myIssuesAliasToml)
        #expect(parsed?.repository == "alias/repo")
        #expect(parsed?.excludeLabels == ["Foo", "Bar"])
    }

    @Test func issueQueueSingleLabelQuery() {
        let queueOne = IssueQueueSettings(host: "git.example.com", repository: "acme/inbox", includeLabels: ["ready"])
        #expect(
            queueOne.searchQuery ==
            "repo:acme/inbox is:issue is:open no:assignee archived:false label:\"ready\""
        )
    }

    @Test func issueQueueMultipleLabelsOrQuery() {
        let queueMulti = IssueQueueSettings(host: "git.example.com", repository: "acme/inbox", includeLabels: ["ready", "queued"])
        #expect(
            queueMulti.searchQuery ==
            "repo:acme/inbox is:issue is:open no:assignee archived:false (label:\"ready\" OR label:\"queued\")"
        )
    }

    @Test func parseIssueQueueToml() {
        let queueToml = """
        [github]
        hosts = ["git.example.com"]

        [issue_queue]
        host = "git.example.com"
        repository = "acme/inbox"
        include_labels = "ready, queued"
        """
        let parsed = IssueQueueSettings.parse(fromToml: queueToml)
        #expect(parsed?.repository == "acme/inbox")
        #expect(parsed?.includeLabels == ["ready", "queued"])
    }

    @Test func parseIssueQueueAbsentOrIncomplete() {
        #expect(IssueQueueSettings.parse(fromToml: "[github]\nhosts = [\"a\"]\n") == nil)
        #expect(
            IssueQueueSettings.parse(fromToml: "[github]\nhosts = [\"a\"]\n\n[issue_queue]\nhost = \"a\"\nrepository = \"b/c\"\n") == nil
        )
    }

    @Test func parseRepoAliasAndLegacyIncludeLabel() {
        let queueAliasToml = """
        [github]
        hosts = ["git.example.com"]

        [issue_queue]
        host = "git.example.com"
        repo = "alias/queue"
        include_label = "ready, queued"
        """
        let parsed = IssueQueueSettings.parse(fromToml: queueAliasToml)
        #expect(parsed?.repository == "alias/queue")
        #expect(parsed?.includeLabels == ["ready", "queued"])
    }

    @Test func whitespaceOnlyIncludeLabelsNil() {
        let toml = """
        [github]
        hosts = ["git.example.com"]

        [issue_queue]
        host = "git.example.com"
        repository = "o/r"
        include_labels = ",  ,"
        """
        #expect(IssueQueueSettings.parse(fromToml: toml) == nil)
    }

    @Test func issueQueueSearchQueryEmptyWhenNoLabels() {
        #expect(IssueQueueSettings(host: "h", repository: "o/r", includeLabels: []).searchQuery == "")
        #expect(IssueQueueSettings(host: "h", repository: "o/r", includeLabels: ["", "  "]).searchQuery == "")
    }
}
