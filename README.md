# gh-dashboard

A native macOS app that aggregates your GitHub pull requests and issues across multiple GitHub hosts (github.com and GitHub Enterprise Server instances) into a single dashboard.

Built with SwiftUI and targeting macOS 14+.

## Prerequisites

- macOS 14 (Sonoma) or later
- [Swift](https://www.swift.org) 6.0+ (included with Xcode or Command Line Tools)
- [gh CLI](https://cli.github.com) authenticated for each host you want to use

## Authentication

The app reads OAuth tokens from the gh CLI's credential store (`~/.config/gh/hosts.yml`), so you must authenticate with `gh` before using the dashboard.

**github.com**

```sh
gh auth login
```

Follow the prompts — choose HTTPS and authenticate via browser or token.

**GitHub Enterprise Server**

```sh
gh auth login --hostname github.mycompany.com
```

Replace `github.mycompany.com` with your instance's hostname. You'll need a personal access token with `repo` and `read:org` scopes, or browser-based OAuth if your instance supports it.

**Verify authentication**

```sh
gh auth status                            # check github.com
gh auth status --hostname github.mycompany.com   # check an enterprise host
```

**Token scopes required**

The app queries pull requests and issues via GraphQL. Your token needs at minimum:
- `repo` — read access to repositories (includes PRs and issues)
- `read:org` — required if you want items from org-owned repositories

If you authenticated via browser OAuth, these scopes are granted automatically.

## Configuration

Create the config file at `~/.config/gh-dashboard/config.toml`:

```sh
mkdir -p ~/.config/gh-dashboard
```

```toml
# ~/.config/gh-dashboard/config.toml

[github]
hosts = [
  "github.com",
  "github.mycompany.com",
]
```

Only the hosts listed here will be contacted. The app reads their OAuth tokens
from the gh CLI config (`~/.config/gh/hosts.yml`) — no tokens are stored in the
dashboard config file.

## Build & run

### Run directly with Swift

```sh
cd macOS
swift build
swift run GhDashboard
```

Or open `macOS/Package.swift` in Xcode for previews and the full IDE experience.

### Build a .app bundle

```sh
cd macOS
./build-app.sh
```

This produces `macOS/GhDashboard.app` — ad-hoc signed and ready to run. To install:

```sh
cp -r macOS/GhDashboard.app /Applications/
open /Applications/GhDashboard.app
```

## Local cache

Fetched data is cached locally at:

```
~/Library/Application Support/GhDashboard/snapshot.json
```

Sync is **uni-directional** — data flows only from GitHub to the local cache, never
the other way. On each successful refresh, items for that host are replaced in the
cache. If a host's fetch fails (network error, expired token, etc.), its previously
cached items are preserved so the dashboard stays populated. On launch, the cache is
loaded immediately for an instant UI before the first network request completes.

## Tests

```sh
cd macOS
swift run CoreTests
```

Covers: GraphQL JSON decoding, review status derivation, comment ordering, TOML
config loading, `DashboardItem` properties and badges, snapshot round-trip
encoding/decoding, `SnapshotStore` file I/O, and merge-by-host cache preservation.

## Architecture

```
└── macOS/
    ├── Package.swift
    ├── build-app.sh               # Assembles GhDashboard.app bundle
    ├── Sources/
    │   ├── GhDashboard/          # SwiftUI app (@main, views, view model)
    │   │   ├── GhDashboardApp.swift
    │   │   ├── DashboardViewModel.swift
    │   │   └── Views/
    │   │       ├── ContentView.swift
    │   │       ├── SidebarView.swift
    │   │       ├── ItemListView.swift
    │   │       ├── ItemRow.swift
    │   │       └── DetailView.swift
    │   └── Core/                  # Shared library (testable)
    │       ├── Config/            # TOML config loader
    │       ├── Credentials/       # gh hosts.yml token reader
    │       ├── GitHub/            # GraphQL client, models, Codable types
    │       └── Persistence/       # SnapshotStore — local cache read/write
    └── Tests/
        └── CoreTests/             # Custom test runner (no Xcode required)
```

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘R` | Refresh all hosts |
| Click link / Safari icon | Open selected item in browser |
| Standard macOS selection | Navigate sidebar and list |
