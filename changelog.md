# Changelog

All notable changes for this project are described in this file. Release tags refer to the app and automation as shipped in the repository at that commit.

## [Unreleased]

### Added

- **Adjustable text size**: increase or decrease the UI font scale with **⌘+** / **⌘−** (reset with **⌘0**); the chosen scale persists across launches.
- **⌘F search overlay**: Spotlight-style floating panel searches all loaded items across every section by title, repo, author, issue/PR number, and labels. Clicking a result switches to that item's section and opens it in the detail pane; keyboard navigation (↑↓ / Return) and Escape to dismiss are supported.

## [1.0.0] — 2026-05-06

First tagged version of **gh-dashboard** as a native macOS app (commit `586f221`).

### Scope

- **Platform**: macOS 14+ app built with **SwiftUI** and Swift 6 (Swift Package at the repo root; originally lived under `macOS/` and was flattened post-1.0.0).
- **Multi-host GitHub**: Query **github.com** and **GitHub Enterprise Server** hosts listed in `~/.config/gh-dashboard/config.toml`; only configured hosts are contacted.
- **Authentication**: Reuses **GitHub CLI** (`gh`) OAuth tokens from `~/.config/gh/hosts.yml` — no separate token storage in the app config.
- **Data source**: **GraphQL** search for open **pull requests** and **issues**; shows repo, author, labels, draft state, URLs, and derived **review status** for PRs.
- **UI**: Sidebar sections, list and **detail** views; **Markdown** rendering for PR/issue bodies and comments.
- **Offline / resilience**: **Local JSON cache** under `~/Library/Application Support/GhDashboard/snapshot.json`; cache loads on launch; failed host refreshes keep that host’s previous items while successful hosts update (merge-by-host behavior).
- **Distribution**: **`build-app.sh`** assembles **GhDashboard.app** (ad-hoc signed) with app icon resources.
- **Quality**: **`CoreTests`** executable harness (GraphQL decoding, review status, comments ordering, TOML config, snapshot round-trip, `SnapshotStore` I/O, merge-by-host coverage).
- **Automation (at this tag)**: **Release** workflow on `v*` tags (ZIP of the app bundle) and **CI** workflow for pull requests to `main` (build + test runner).

### GitHub Releases note for v1.0.0

The **v1.0.0** tag was created before workflow token permissions allowed uploading assets, so **no GitHub Release binaries** were published for this tag. Use **v1.0.1** or later for downloadable **ZIP** and **DMG** artifacts on the [Releases](https://github.com/rjayasinghe/gh-dashboard/releases) page.
