# dev-dashboard

A terminal dashboard that aggregates your GitHub pull requests and issues across multiple GitHub hosts (github.com and GitHub Enterprise Server instances) into a single TUI.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  dev-dashboard  My PRs: 3  Review: 2  Issues: 5        Last: 2m ago  r↺ │
├──────────────────────────┬──────────────────────────────────────────────┤
│ ▼ My PRs                 │  Fix: Add retry logic for flaky tests        │
│   [github.com]           │  repo: myorg/myrepo                          │
│ > Fix: Add retry logic.. │  status: open                                │
│   Add pagination suppo.. │  draft: no                                   │
│   [github.mycompany.com] │  reviews: approved                           │
│   Refactor auth module   │  opened: 3d ago                              │
│                          │  author: octocat                             │
│ ▼ Review Needed          │                                              │
│   [github.mycompany.com] │  https://github.com/myorg/myrepo/pull/123   │
│   Update CI pipeline     │                                              │
│                          │  [o] open in browser                         │
│ ▼ My Issues              │                                              │
│   [github.com]           │                                              │
│   Login page broken      │                                              │
└──────────────────────────┴──────────────────────────────────────────────┘
  j/k/scroll: navigate   click: select   tab: section   o/click-detail: browser   r: refresh   q: quit
```

## Prerequisites

- [Go](https://go.dev) 1.22 or later
- [gh CLI](https://cli.github.com) authenticated for each host you want to use

```sh
gh auth login                                    # github.com
gh auth login --hostname github.mycompany.com    # GitHub Enterprise
```

## Build

```sh
git clone <repo-url>
cd dev-dashboard
go build -o dev-dashboard .
```

Or with size optimisations:

```sh
CGO_ENABLED=0 go build -ldflags="-s -w" -o dev-dashboard .
```

The result is a single static binary with no runtime dependencies.

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

Only the hosts listed here will be contacted. The app reads their tokens from
the gh CLI keychain — no tokens are stored in the config file.

### Custom config path

```sh
dev-dashboard --config /path/to/config.toml
```

## Usage

```sh
./dev-dashboard
```

### Flags

| Flag | Default | Description |
|---|---|---|
| `--interval` | `5m` | Auto-refresh interval (e.g. `30s`, `2m`, `1h`) |
| `--config` | `~/.config/dev-dashboard/config.toml` | Path to config file |
| `--debug` | `false` | Write Bubble Tea debug log to `debug.log` |

### Keyboard shortcuts

| Key | Action |
|---|---|
| `j` / `↓` | Move cursor down |
| `k` / `↑` | Move cursor up |
| `Tab` | Next section |
| `Shift+Tab` | Previous section |
| `o` | Open selected item in browser |
| `r` | Force refresh |
| `q` / `Ctrl+C` | Quit |

### Mouse

| Interaction | Action |
|---|---|
| Scroll wheel | Scroll the list |
| Click item | Select it |
| Click section header | Switch to that section |
| Click detail pane | Open selected item in browser |
