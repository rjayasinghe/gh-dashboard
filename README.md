# dev-dashboard

A native macOS app that aggregates your GitHub pull requests and issues across multiple GitHub hosts (github.com and GitHub Enterprise Server instances) into a single dashboard.

Built with SwiftUI and targeting macOS 14+.

## Prerequisites

- macOS 14 (Sonoma) or later
- [Swift](https://www.swift.org) 6.0+ (included with Xcode or Command Line Tools)
- [gh CLI](https://cli.github.com) authenticated for each host you want to use

```sh
gh auth login                                    # github.com
gh auth login --hostname github.mycompany.com    # GitHub Enterprise
```

## Configuration

Create the config file at `~/.config/dev-dashboard/config.toml`:

```sh
mkdir -p ~/.config/dev-dashboard
```

```toml
# ~/.config/dev-dashboard/config.toml

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

```sh
cd macOS
swift build
swift run DevDashboard
```

Or open `macOS/Package.swift` in Xcode for previews and the full IDE experience.

## Local cache

Fetched data is cached locally at:

```
~/Library/Application Support/DevDashboard/snapshot.json
```

Sync is **uni-directional** — data flows only from GitHub to the local cache, never
the other way. On each successful refresh, items for that host are replaced in the
cache. If a host's fetch fails (network error, expired token, etc.), its previously
cached items are preserved so the dashboard stays populated. On launch, the cache is
loaded immediately for an instant UI before the first network request completes.

## Validate config (CLI helper)

A small Go CLI is included to check your config without launching the GUI:

```sh
go build -o dev-dashboard .
./dev-dashboard validate
./dev-dashboard validate --config /path/to/config.toml
```

## Tests

```sh
cd macOS
swift run CoreTests
```

With Xcode installed you can also convert the tests to XCTest and run `swift test`.

## Architecture

```
macOS/
├── Sources/
│   ├── DevDashboard/          # SwiftUI app (@main, views, view model)
│   │   ├── DevDashboardApp.swift
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
│       └── GitHub/            # GraphQL client, models, Codable types
└── Tests/
    └── CoreTests/             # Standalone test runner
```

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘R` | Refresh all hosts |
| Click link / Safari icon | Open selected item in browser |
| Standard macOS selection | Navigate sidebar and list |
