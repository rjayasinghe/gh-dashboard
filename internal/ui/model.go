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

	// scroll offsets
	detailScrollOffset int

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
