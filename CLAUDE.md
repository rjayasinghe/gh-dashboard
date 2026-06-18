# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run tests (requires Command Line Tools only — no Xcode needed)
swift test

# Run a single test
swift test --filter ConfigLoaderTests/multiLineHosts

# Build debug binary
swift build

# Build distributable .app bundle (ad-hoc signed, macOS only)
./build-app.sh

# Build release binary only (no .app bundle)
swift build -c release --product GhDashboard
```

Tests use the `swift-testing` package (not XCTest) because Command Line Tools don't ship `XCTest`. The `swift-testing` package deprecation warnings are cosmetic — the package is still required since CLT Swift 6.3 ships the `Testing` module headers but not `_TestingInternals`.

## Architecture

Two targets: **Core** (pure Swift library, no SwiftUI) and **GhDashboard** (SwiftUI app that depends on Core).

### Core

- **Config/** — reads a TOML config file (via Yams). `ConfigLoader` is the entry point; `TomlConfigParsing` handles the raw TOML-to-struct mapping. `MyDoDIssuesSettings` and `IssueQueueSettings` are optional tabs; when absent from config the view model hides those sections entirely.
- **Credentials/** — `CredentialStore` reads GitHub tokens from the macOS keychain (the same keychain entries written by the `gh` CLI).
- **GitHub/** — `GraphQLClient` + `HTTPTransport` fire paginated GraphQL search queries. `GraphQLModels` decodes the raw response; `DashboardItem` is the app-level model produced from those responses.
- **Persistence/** — `SnapshotStore` saves/loads a `PersistedSnapshot` (JSON) to `~/Library/Application Support/`. On a failed host refresh the cached items for that host are kept (merge-by-host strategy in `DashboardViewModel.refresh()`).
- **Services/** — `DashboardServices` wires the protocol abstractions (`ConfigLoading`, `CredentialProviding`, `SnapshotPersisting`, `ItemFetching`) to their live implementations. All four are injected into `DashboardViewModel` for testability.

### GhDashboard (SwiftUI app)

- **`DashboardViewModel`** — single `@Observable` view model shared across the whole app. Owns `section` (active sidebar tab), `items` (all fetched items, all sections), `selectedItemID`, and search state. `filteredItems` filters by section; `groupedByHost` groups the result for display.
- **`ContentView`** — `NavigationSplitView` with three columns: `SidebarView` | `ItemListView` | `DetailView`. The search overlay (`SearchOverlayView`) is layered via `ZStack`.
- **`ItemListView`** — renders `groupedByHost` as a sectioned `List` bound to `$viewModel.selectedItemID`.
- **`DetailView`** — read-only; renders the selected `DashboardItem` with markdown body/comments.
- **`FontScaleSettings`** — `@Observable` injected via `@Environment`; drives `scaleEffect` on `ContentView` for Cmd+/- text sizing.

### Data flow

```
TOML config → ConfigLoader → hosts + optional section settings
                                  ↓
gh keychain → CredentialStore → tokens per host
                                  ↓
GraphQL API → GraphQLClient → [DashboardItem] → SnapshotStore (cache)
                                  ↓
                          DashboardViewModel
                                  ↓
                  SidebarView / ItemListView / DetailView
```

Refresh runs on a 5-minute timer in `startPeriodicRefresh()`, paused while the app is backgrounded (`scenePhase`). Per-host failures retain cached items for that host.

## Changelog

Maintain `changelog.md` alongside any notable change — new features, bug fixes, user-visible behavior changes, config or schema changes, and release-workflow changes. Add an entry under `## [Unreleased]` (grouped as **Added / Changed / Fixed / Removed**) in the same change as the code; promote `[Unreleased]` to a versioned section when tagging a release. Skip purely internal refactors, test-only changes, and doc tweaks that have no user impact.
