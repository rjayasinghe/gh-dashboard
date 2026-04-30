package ui

import (
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	gh "github.com/i540498/dev-dashboard/internal/github"
)

// --- messages ---

type dataLoadedMsg struct {
	items     []gh.Item
	hostErrs  map[string]error
	fetchedAt time.Time
}

type tickMsg time.Time

// --- model ---

type Model struct {
	// data
	items    []gh.Item
	hostErrs map[string]error

	// navigation
	activeSection gh.Section
	cursor        int

	// list scroll state
	listScrollOffset  int // rows scrolled off the top of the list panel
	detailScrollOffset int // lines scrolled in the detail pane
	headerHeight      int // cached so mouse handler can compute row from Y

	// ui state
	loading      bool
	spinner      spinner.Model
	lastFetched  time.Time
	windowWidth  int
	windowHeight int

	// config
	interval time.Duration
	clients  []gh.HostClient
}

func New(clients []gh.HostClient, interval time.Duration) Model {
	s := spinner.New()
	s.Spinner = spinner.Dot

	return Model{
		clients:       clients,
		interval:      interval,
		activeSection: gh.SectionMyPRs,
		loading:       true,
		spinner:       s,
	}
}

func (m Model) itemsForSection(s gh.Section) []gh.Item {
	var out []gh.Item
	for _, item := range m.items {
		if item.Section == s {
			out = append(out, item)
		}
	}
	return out
}

func (m Model) selectedItem() *gh.Item {
	items := m.itemsForSection(m.activeSection)
	if len(items) == 0 || m.cursor >= len(items) {
		return nil
	}
	item := items[m.cursor]
	return &item
}

// adjustListScroll updates m.listScrollOffset so that:
//  1. The selected item is within the visible window.
//  2. The nearest section/host header above the selected item is also visible.
//
// Must be called on a pointer receiver so the mutation is retained.
func (m *Model) adjustListScroll() {
	rows := m.buildRows()

	// visible height: total minus 2 for header+footer (matches contentHeight())
	height := m.windowHeight - 2
	if height < 1 {
		height = 1
	}

	selectedRowIdx := -1
	for i, row := range rows {
		if row.kind == rowItem && row.section == m.activeSection && row.itemIdx == m.cursor {
			selectedRowIdx = i
			break
		}
	}
	if selectedRowIdx < 0 {
		return
	}

	// find the nearest header above the selected item
	anchor := selectedRowIdx
	for i := selectedRowIdx - 1; i >= 0; i-- {
		if rows[i].kind == rowSection || rows[i].kind == rowHost {
			anchor = i
			break
		}
	}

	offset := m.listScrollOffset

	// scroll down: item below visible window
	if selectedRowIdx >= offset+height {
		offset = selectedRowIdx - height + 1
	}

	// scroll up: item or its header above visible window
	if anchor < offset {
		offset = anchor
	}

	// clamp to valid range
	maxOffset := len(rows) - height
	if maxOffset < 0 {
		maxOffset = 0
	}
	if offset > maxOffset {
		offset = maxOffset
	}
	if offset < 0 {
		offset = 0
	}

	m.listScrollOffset = offset
}
