import Testing

@testable import Core

@Suite struct NotificationSettingsTests {
    @Test func absentSectionUsesAllOnDefault() {
        let toml = """
        [github]
        hosts = ["github.com"]
        """
        let s = NotificationSettings.parse(fromToml: toml)
        #expect(s == .default)
        #expect(s.enabled)
        #expect(s.notifyNewItems)
        #expect(s.notifyUpdates)
        #expect(s.notifyComments)
        #expect(s.notifyStateChanges)
    }

    @Test func masterSwitchOff() {
        let toml = """
        [notifications]
        enabled = false
        """
        let s = NotificationSettings.parse(fromToml: toml)
        #expect(!s.enabled)
        // Other flags retain their defaults — the master switch is what gates dispatch.
        #expect(s.notifyNewItems)
    }

    @Test func individualFlagsParsed() {
        let toml = """
        [notifications]
        enabled = true
        new_items = false
        updates = true
        comments = false
        state_changes = true
        """
        let s = NotificationSettings.parse(fromToml: toml)
        #expect(s.enabled)
        #expect(!s.notifyNewItems)
        #expect(s.notifyUpdates)
        #expect(!s.notifyComments)
        #expect(s.notifyStateChanges)
    }

    @Test func camelCaseAliasesAccepted() {
        let toml = """
        [notifications]
        newItems = false
        stateChanges = false
        """
        let s = NotificationSettings.parse(fromToml: toml)
        #expect(!s.notifyNewItems)
        #expect(!s.notifyStateChanges)
    }

    @Test func partialKeysFallBackToDefault() {
        let toml = """
        [notifications]
        comments = false
        """
        let s = NotificationSettings.parse(fromToml: toml)
        #expect(s.enabled)              // default
        #expect(s.notifyNewItems)       // default
        #expect(s.notifyUpdates)        // default
        #expect(!s.notifyComments)      // explicit
        #expect(s.notifyStateChanges)   // default
    }

    @Test func malformedBoolFallsBackToDefault() {
        let toml = """
        [notifications]
        enabled = maybe
        """
        let s = NotificationSettings.parse(fromToml: toml)
        #expect(s.enabled)  // default
    }

    @Test func numericAndYesNoAccepted() {
        let toml = """
        [notifications]
        enabled = 1
        new_items = no
        updates = 0
        comments = yes
        """
        let s = NotificationSettings.parse(fromToml: toml)
        #expect(s.enabled)
        #expect(!s.notifyNewItems)
        #expect(!s.notifyUpdates)
        #expect(s.notifyComments)
    }
}
