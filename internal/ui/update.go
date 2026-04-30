package ui

import (
	"context"
	"os/exec"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
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
		// cache header height for mouse coordinate mapping
		m.headerHeight = lipgloss.Height(m.renderHeader())
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
		// clamp cursor in case items shrunk
		if items := m.itemsForSection(m.activeSection); m.cursor >= len(items) {
			if len(items) > 0 {
				m.cursor = len(items) - 1
			} else {
				m.cursor = 0
			}
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
	switch msg.String() {
	case "q", "ctrl+c":
		return m, tea.Quit

	case "j", "down":
		items := m.itemsForSection(m.activeSection)
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
		if item := m.selectedItem(); item != nil && item.URL != "" {
			return m, openBrowserCmd(item.URL)
		}
	}

	return m, nil
}

func (m Model) handleMouse(msg tea.MouseMsg) (tea.Model, tea.Cmd) {
	listW := m.windowWidth * 30 / 100
	if listW < 30 {
		listW = 30
	}

	inListPanel := msg.X < listW

	switch msg.Button {
	case tea.MouseButtonWheelUp:
		if m.listScrollOffset > 0 {
			m.listScrollOffset--
		}

	case tea.MouseButtonWheelDown:
		rows := m.buildRows()
		contentH := m.contentHeight()
		maxScroll := len(rows) - contentH
		if maxScroll > 0 && m.listScrollOffset < maxScroll {
			m.listScrollOffset++
		}

	case tea.MouseButtonLeft:
		if msg.Action != tea.MouseActionRelease {
			break
		}
		if inListPanel {
			// map click Y to a row in the (scrolled) row list
			rowIdx := msg.Y - m.headerHeight + m.listScrollOffset
			rows := m.buildRows()
			if rowIdx >= 0 && rowIdx < len(rows) {
				row := rows[rowIdx]
				switch row.kind {
				case rowSection:
					m.activeSection = row.section
					m.cursor = 0
					m.detailScrollOffset = 0
				case rowItem:
					m.activeSection = row.section
					m.cursor = row.itemIdx
					m.detailScrollOffset = 0
				}
			}
		} else {
			// click in detail panel → open in browser
			if item := m.selectedItem(); item != nil && item.URL != "" {
				return m, openBrowserCmd(item.URL)
			}
		}
	}

	return m, nil
}

func (m Model) contentHeight() int {
	// approximation: 1 line header + 1 line footer
	h := m.windowHeight - 2
	if h < 1 {
		h = 1
	}
	return h
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
