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

func (m *Model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		fetchCmd(m.clients),
		tea.WindowSize(),
	)
}

func (m *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	case tea.WindowSizeMsg:
		m.windowWidth = msg.Width
		m.windowHeight = msg.Height
		m.resizeSubviews()
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
		host, repo, title := "", "", ""
		number := 0
		hadSel := false
		if it := m.selectedItem(); it != nil {
			hadSel = true
			host, repo = it.Host, it.Repo
			number, title = it.Number, it.Title
		}
		m.items = msg.items
		m.hostErrs = msg.hostErrs
		m.lastFetched = msg.fetchedAt
		m.applyLayoutSizes()
		cmd := m.syncListFromSection()
		if hadSel {
			m.reselectAfterItemsReload(host, repo, number, title)
		} else {
			m.selectFirstSelectable()
		}
		m.syncViewportContent(true)
		return m, tea.Batch(cmd, tickAfter(m.interval))

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

func (m *Model) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "ctrl+c":
		return m, tea.Quit

	case "tab":
		m.activeSection = (m.activeSection + 1) % 3
		cmd := m.syncListFromSection()
		m.selectFirstSelectable()
		m.applyLayoutSizes()
		m.syncViewportContent(true)
		return m, cmd

	case "shift+tab":
		m.activeSection = (m.activeSection + 2) % 3
		cmd := m.syncListFromSection()
		m.selectFirstSelectable()
		m.applyLayoutSizes()
		m.syncViewportContent(true)
		return m, cmd

	case "J":
		vp := m.viewport
		vp.ScrollDown(1)
		m.viewport = vp
		return m, nil

	case "K":
		vp := m.viewport
		vp.ScrollUp(1)
		m.viewport = vp
		return m, nil

	case "r":
		if !m.loading {
			m.loading = true
			return m, tea.Batch(m.spinner.Tick, fetchCmd(m.clients))
		}
		return m, nil

	case "o":
		if item := m.selectedItem(); item != nil {
			return m, openBrowserCmd(item.URL)
		}
		return m, nil
	}

	// List navigation (j/k) — keep viewport from stealing j/k.
	switch msg.String() {
	case "j", "down", "k", "up":
		idxBefore := m.list.GlobalIndex()
		var listCmd tea.Cmd
		m.list, listCmd = m.list.Update(msg)
		switch msg.String() {
		case "j", "down":
			m.reconcileAwayFromSeparator(true)
		default:
			m.reconcileAwayFromSeparator(false)
		}
		// Same pipeline as resize / dataLoaded list leg: SetSize + pager clamp + viewport dims.
		m.applyLayoutSizes()
		m.syncViewportContent(m.list.GlobalIndex() != idxBefore)
		return m, listCmd
	}

	var vpCmd tea.Cmd
	m.viewport, vpCmd = m.viewport.Update(msg)
	return m, vpCmd
}

func (m *Model) handleMouse(msg tea.MouseMsg) (tea.Model, tea.Cmd) {
	listW := m.listWidth()

	switch msg.Button {
	case tea.MouseButtonWheelUp:
		if msg.X < listW {
			idxBefore := m.list.GlobalIndex()
			mm := m.list
			mm.CursorUp()
			m.list = mm
			m.reconcileAwayFromSeparator(false)
			m.applyLayoutSizes()
			m.syncViewportContent(m.list.GlobalIndex() != idxBefore)
		} else {
			var vpCmd tea.Cmd
			m.viewport, vpCmd = m.viewport.Update(msg)
			return m, vpCmd
		}

	case tea.MouseButtonWheelDown:
		if msg.X < listW {
			idxBefore := m.list.GlobalIndex()
			mm := m.list
			mm.CursorDown()
			m.list = mm
			m.reconcileAwayFromSeparator(true)
			m.applyLayoutSizes()
			m.syncViewportContent(m.list.GlobalIndex() != idxBefore)
		} else {
			var vpCmd tea.Cmd
			m.viewport, vpCmd = m.viewport.Update(msg)
			return m, vpCmd
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
	listIdx := y - 1
	if listIdx < 0 {
		return
	}
	// One terminal row per item (ShowDescription=false); was /2 for title+subtitle.
	clicked := listIdx
	items := m.list.VisibleItems()
	if len(items) == 0 {
		return
	}
	start, _ := m.list.Paginator.GetSliceBounds(len(items))
	globalIdx := start + clicked
	if globalIdx >= 0 && globalIdx < len(items) {
		m.list.Select(globalIdx)
		m.reconcileAwayFromSeparator(true)
		m.applyLayoutSizes()
		m.syncViewportContent(true)
	}
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

// renderListBody is the raw list area (inside the list panel border).
func (m *Model) renderListBody(contentH int) string {
	if m.loading && len(m.itemsForSection(m.activeSection)) == 0 {
		return lipgloss.NewStyle().
			Width(max(1, m.list.Width())).
			Height(contentH).
			MaxHeight(contentH).
			Render("")
	}
	return m.list.View()
}

// renderDetailPanel renders the detail viewport inside the padded panel.
func (m *Model) renderDetailPanel(detailW, contentH int) string {
	return detailPanelStyle.Width(detailW).MaxWidth(detailW).Height(contentH).MaxHeight(contentH).Render(m.viewport.View())
}
