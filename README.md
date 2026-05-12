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

### My DoD issues (CAP on SAP GitHub Enterprise)

The sidebar tab **My DoD issues** lists open issues assigned to you in the CAP repository on **`github.tools.sap`**, excluding any issue that has **one of** the configured labels. Defaults match the internal CAP project (`repository = SAP/cap`) and a single excluded label **Author Action**; override if your `nameWithOwner` or label filters differ.

```toml
[github]
hosts = [
  "github.com",
  "github.tools.sap",
]

# Optional — omit to use defaults below
[my_dod_issues]
host = "github.tools.sap"
repository = "SAP/cap"
# Comma-separated; each becomes a -label:"…" exclusion in GitHub search
exclude_labels = "Author Action, Waiting on Author"
```

`github.tools.sap` must appear in `hosts` and you must be logged in with `gh auth login --hostname github.tools.sap`. You can use `repo` instead of `repository`. The legacy key `exclude_label` is still accepted and uses the same comma-separated rules.

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

If macOS refuses the first open, use **Control-click the app → Open** (see **First launch: Gatekeeper** under Releases below).

### Releases

Pushing a version tag (`v*`, for example `v1.1.0`) runs `.github/workflows/release.yml`: it attaches **`GhDashboard.zip`** (ZIP of the app bundle) and **`GhDashboard.dmg`** (compressed disk image). The Actions workflow permissions must allow **Read and write** for `GITHUB_TOKEN` on `contents`; otherwise uploads fail and no GitHub Release is created.

#### First launch: Gatekeeper (no Apple Developer account needed)

Release builds are **ad-hoc signed** for open distribution, so macOS may say it **cannot check the app for malicious software** the first time you open it. You do **not** need an Apple Developer membership. Use this workaround:

1. **From the DMG:** double-click **`GhDashboard.dmg`** to mount it.
2. In the Finder window, **Control-click** (or **right-click**) **`GhDashboard.app`**—do not double-click yet.
3. Choose **Open** from the menu, then click **Open** in the security dialog.

**If you already double-clicked and it was blocked:** open **System Settings → Privacy & Security**, scroll to the message about GhDashboard, and click **Open Anyway**.

After you approve it once, you can open the app normally (double-click) including after copying **`GhDashboard.app`** to **Applications**.

#### Optional (maintainers only): Developer ID and notarization

To ship builds that pass Gatekeeper without the steps above, a maintainer would need an **Apple Developer Program** membership, **Developer ID** signing, and **notarization** in CI. Configure the **repository secrets** listed in **`macOS/scripts/sign-release-bundle.sh`** and `.github/workflows/release.yml` (`MACOS_CERTIFICATE_BASE64`, `MACOS_CERTIFICATE_PASSWORD`, and either App Store Connect API key variables or `APPLE_ID` / `APPLE_APP_SPECIFIC_PASSWORD` / `APPLE_TEAM_ID`). If those secrets are **unset**, releases stay ad-hoc signed and end users rely on the **first launch** workaround.

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

## Contributing

`main` is protected. Open changes from a feature branch and merge via pull request after CI passes.
