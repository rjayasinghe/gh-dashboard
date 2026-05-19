# Testing

## Layout

| Target | What it covers |
|--------|----------------|
| **CoreTests** | Config, GraphQL decoding, persistence, and **pure logic** (e.g. `DashboardItemSearch`) with no SwiftUI |
| **GhDashboardTests** | `@MainActor` **view-model** behavior via `@testable import GhDashboard` |

Run everything:

```bash
swift test
```

## Frontend (SwiftUI) strategy

SwiftUI views are thin; behavior lives in **Core** or **DashboardViewModel** so CI can test without rendering:

1. **Search** — `DashboardItemSearch` in Core (unit tests) + `DashboardViewModel.searchResults` / `selectSearchResult` (GhDashboardTests).
2. **Views** — `ItemSearchField` only binds to the view model; no business rules in the view file.

### Improving UI coverage later (optional)

- **Snapshot tests** ([swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)) for `ItemRow`, `SearchResultRow`, and empty states — catches layout regressions; needs reference images per macOS version.
- **ViewInspector** for asserting view hierarchy in tests — useful but adds a dependency and can be brittle across OS releases.
- **XCUITest** — full app launch on macOS; slowest, best for smoke tests (open app, refresh, search).

Prefer keeping new features testable by extracting logic from views first, then adding snapshots only for high-value UI.
