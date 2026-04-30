package ui

import (
	"context"
	"os/exec"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	gh "github.com/i540498/dev-dashboard/internal/github"
)

func (m Model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		fetchCmd(m.clients),
		tea.WindowSize(),
	)
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	case tea.WindowSizeMsg:
		m.windowWidth = msg.Width
		m.windowHeight = msg.Height
		return m, nil

	case spinner.TickMsg:
		if m.loading {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			return m, cmd
		}
		return m, nil

	case dataLoadedMsg:
		m.loading = false
		m.items = msg.items
		m.hostErrs = msg.hostErrs
		m.lastFetched = msg.fetchedAt
		if items := m.itemsForSection(m.activeSection); m.cursor >= len(items) {
			m.cursor = max(0, len(items)-1)
		}
		return m, tickAfter(m.interval)

	case tickMsg:
		m.loading = true
		return m, tea.Batch(m.spinner.Tick, fetchCmd(m.clients))

	case tea.KeyMsg:
		return m.handleKey(msg)

	case tea.MouseMsg:
		return m.handleMouse(msg)
	}

	return m, nil
}

func (m Model) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	items := m.itemsForSection(m.activeSection)

	switch msg.String() {
	case "q", "ctrl+c":
		return m, tea.Quit

	case "j", "down":
		if m.cursor < len(items)-1 {
			m.cursor++
			m.detailScrollOffset = 0
		}

	case "k", "up":
		if m.cursor > 0 {
			m.cursor--
			m.detailScrollOffset = 0
		}

	case "tab":
		m.activeSection = (m.activeSection + 1) % 3
		m.cursor = 0
		m.detailScrollOffset = 0

	case "shift+tab":
		m.activeSection = (m.activeSection + 2) % 3
		m.cursor = 0
		m.detailScrollOffset = 0

	case "J":
		m.detailScrollOffset++

	case "K":
		if m.detailScrollOffset > 0 {
			m.detailScrollOffset--
		}

	case "r":
		if !m.loading {
			m.loading = true
			return m, tea.Batch(m.spinner.Tick, fetchCmd(m.clients))
		}

	case "o":
		if item := m.selectedItem(); item != nil {
			return m, openBrowserCmd(item.URL)
		}
	}

	return m, nil
}

func (m Model) handleMouse(msg tea.MouseMsg) (tea.Model, tea.Cmd) {
	listW := m.listWidth()

	switch msg.Button {
	case tea.MouseButtonWheelUp:
		if msg.X < listW {
			if m.cursor > 0 {
				m.cursor--
				m.detailScrollOffset = 0
			}
		} else {
			if m.detailScrollOffset > 0 {
				m.detailScrollOffset--
			}
		}

	case tea.MouseButtonWheelDown:
		if msg.X < listW {
			items := m.itemsForSection(m.activeSection)
			if m.cursor < len(items)-1 {
				m.cursor++
				m.detailScrollOffset = 0
			}
		} else {
			m.detailScrollOffset++
		}

	case tea.MouseButtonLeft:
		if msg.Action != tea.MouseActionRelease {
			break
		}
		if msg.X < listW {
			m.handleListClick(msg.Y)
		} else {
			if item := m.selectedItem(); item != nil {
				return m, openBrowserCmd(item.URL)
			}
		}
	}

	return m, nil
}

func (m *Model) handleListClick(y int) {
	// tab bar is row 0, list starts at row 1
	listIdx := y - 1
	if listIdx < 0 {
		return
	}
	items := m.itemsForSection(m.activeSection)
	// each item occupies 2 rows (title + subtitle)
	clicked := listIdx / 2
	if clicked < len(items) {
		m.cursor = clicked
		m.detailScrollOffset = 0
	}
}

func (m Model) listWidth() int {
	w := m.windowWidth * 30 / 100
	if w < 32 {
		w = 32
	}
	return w
}

func fetchCmd(clients []gh.HostClient) tea.Cmd {
	return func() tea.Msg {
		ctx := context.Background()
		results := gh.FetchAll(ctx, clients)

		var items []gh.Item
		hostErrs := make(map[string]error)
		for _, r := range results {
			if r.Err != nil {
				hostErrs[r.Host] = r.Err
			} else {
				items = append(items, r.Items...)
			}
		}
		return dataLoadedMsg{
			items:     items,
			hostErrs:  hostErrs,
			fetchedAt: time.Now(),
		}
	}
}

func tickAfter(d time.Duration) tea.Cmd {
	return tea.Tick(d, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func openBrowserCmd(url string) tea.Cmd {
	return func() tea.Msg {
		_ = exec.Command("open", url).Start()
		return nil
	}
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
