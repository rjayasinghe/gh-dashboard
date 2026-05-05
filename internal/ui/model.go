package ui

import (
	"time"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
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
	items    []gh.Item
	hostErrs map[string]error

	activeSection gh.Section

	list     list.Model
	viewport viewport.Model

	loading     bool
	spinner     spinner.Model
	lastFetched time.Time
	windowWidth int
	windowHeight int

	interval time.Duration
	clients  []gh.HostClient
}

func New(clients []gh.HostClient, interval time.Duration) *Model {
	sp := spinner.New()
	sp.Spinner = spinner.Dot

	l := list.New([]list.Item{}, hostGroupedDelegate{}, 32, 10)
	l.SetFilteringEnabled(false)
	l.SetShowTitle(false)
	l.SetShowFilter(false)
	l.SetShowStatusBar(false)
	l.SetShowPagination(false)
	l.SetShowHelp(false)
	l.DisableQuitKeybindings()
	l.KeyMap.Filter.SetEnabled(false)
	l.KeyMap.GoToStart.SetEnabled(false)
	l.KeyMap.GoToEnd.SetEnabled(false)
	l.Styles.NoItems = normalItemStyle.Copy()

	vp := viewport.New(40, 10)
	vp.MouseWheelEnabled = true
	vp.MouseWheelDelta = 1
	vp.KeyMap.Up = key.NewBinding(key.WithDisabled())
	vp.KeyMap.Down = key.NewBinding(key.WithDisabled())
	vp.KeyMap.PageUp = key.NewBinding(key.WithDisabled())
	vp.KeyMap.PageDown = key.NewBinding(key.WithDisabled())
	vp.KeyMap.HalfPageUp = key.NewBinding(key.WithDisabled())
	vp.KeyMap.HalfPageDown = key.NewBinding(key.WithDisabled())

	return &Model{
		clients:       clients,
		interval:      interval,
		activeSection: gh.SectionMyPRs,
		loading:       true,
		spinner:       sp,
		list:          l,
		viewport:      vp,
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
	it := m.list.SelectedItem()
	if it == nil {
		return nil
	}
	li, ok := it.(ghListItem)
	if !ok {
		return nil
	}
	return &li.item
}

func itemMatchesSavedSelection(it gh.Item, host, repo string, number int, title string) bool {
	if it.Host != host || it.Repo != repo {
		return false
	}
	if number != 0 {
		return it.Number == number
	}
	return it.Title == title
}

// reselectAfterItemsReload restores list cursor after a fetch reorders m.items.
func (m *Model) reselectAfterItemsReload(host, repo string, number int, title string) {
	for i, lit := range m.list.Items() {
		li, ok := lit.(ghListItem)
		if !ok {
			continue
		}
		if itemMatchesSavedSelection(li.item, host, repo, number, title) {
			m.list.Select(i)
			m.fixListPaginatorForPopulatedLineBudget()
			return
		}
	}
}

// reconcileAwayFromSeparator moves the cursor off host header rows (non-selectable for UX).
func (m *Model) reconcileAwayFromSeparator(preferDown bool) {
	for range 500 {
		it := m.list.SelectedItem()
		if it == nil {
			return
		}
		if _, ok := it.(hostSeparatorItem); !ok {
			return
		}
		prev := m.list.GlobalIndex()
		mm := m.list
		if preferDown {
			mm.CursorDown()
		} else {
			mm.CursorUp()
		}
		m.list = mm
		m.applyLayoutSizes()
		if m.list.GlobalIndex() == prev {
			mm = m.list
			if preferDown {
				mm.CursorUp()
			} else {
				mm.CursorDown()
			}
			m.list = mm
			m.applyLayoutSizes()
			return
		}
	}
}

func (m *Model) selectFirstSelectable() {
	for i, lit := range m.list.Items() {
		if _, ok := lit.(hostSeparatorItem); !ok {
			m.list.Select(i)
			m.fixListPaginatorForPopulatedLineBudget()
			return
		}
	}
}

func (m *Model) contentHeight() int {
	th := lipgloss.Height(m.renderTabBar())
	sh := lipgloss.Height(m.renderStatusBar())
	if th > 1 {
		th = 1
	}
	if sh > 1 {
		sh = 1
	}
	h := m.windowHeight - th - sh
	if h < 1 {
		h = 1
	}
	return h
}

// joinHorizontalMarginCols: reserve space so joined list+detail rows stay within window width.
const joinHorizontalMarginCols = 1

// layoutDimensions matches View(): outer list column width, detail column,
// body height, inner list width (inside border), inner detail width (padding).
func (m *Model) layoutDimensions() (listW, detailW, contentH, listInnerW, detailInnerW int) {
	contentH = m.contentHeight()
	listW = m.listWidth()
	detailW = m.windowWidth - listW - joinHorizontalMarginCols
	if detailW < 1 {
		detailW = 1
	}
	listInnerW = listW - listPanelStyle.GetHorizontalFrameSize()
	if listInnerW < 1 {
		listInnerW = 1
	}
	detailInnerW = detailW - detailPanelStyle.GetHorizontalFrameSize()
	if detailInnerW < 1 {
		detailInnerW = 1
	}
	return listW, detailW, contentH, listInnerW, detailInnerW
}

func (m Model) listWidth() int {
	if m.windowWidth < 1 {
		return 1
	}
	w := m.windowWidth * 30 / 100
	if w < 32 {
		w = 32
	}
	const minDetailCols = 10
	if w+joinHorizontalMarginCols+minDetailCols > m.windowWidth {
		w = m.windowWidth - joinHorizontalMarginCols - minDetailCols
	}
	if w < 1 {
		w = 1
	}
	return w
}

func (m *Model) detailInnerWidth() int {
	_, _, _, _, dw := m.layoutDimensions()
	return dw
}

func (m *Model) syncListFromSection() tea.Cmd {
	sec := m.itemsForSection(m.activeSection)
	li := groupedListItems(sec)
	cmd := m.list.SetItems(li)
	m.fixListPaginatorForPopulatedLineBudget()
	return cmd
}

func (m *Model) syncViewportContent(resetScroll bool) {
	w := m.detailInnerWidth()
	it := m.selectedItem()
	if it == nil {
		m.viewport.SetContent(detailKeyStyle.Render("No item selected"))
		if resetScroll {
			m.viewport.GotoTop()
		}
		return
	}
	m.viewport.SetContent(DetailViewportContent(it, m.hostErrs, w))
	if resetScroll {
		m.viewport.GotoTop()
	}
}

func (m *Model) applyLayoutSizes() {
	if m.windowWidth == 0 {
		return
	}
	_, _, contentH, listInnerW, detailInnerW := m.layoutDimensions()
	m.list.SetSize(listInnerW, contentH)
	m.fixListPaginatorForPopulatedLineBudget()
	m.viewport.Width = detailInnerW
	m.viewport.Height = contentH
}

// fixListPaginatorForPopulatedLineBudget sets PerPage after bubbles' SetSize/SetItems resets it.
// Our list uses one line per item (ShowDescription=false, SetSpacing=0); populatedView then
// emits exactly k rows for k visible items, so PerPage can equal the list's inner height.
// (The old (avail+1)/2 formula matched two-line delegates and halved the usable list area.)
func (m *Model) fixListPaginatorForPopulatedLineBudget() {
	avail := m.list.Height()
	if avail < 1 {
		avail = 1
	}
	pp := avail
	idx := m.list.GlobalIndex()
	m.list.Paginator.PerPage = pp
	n := len(m.list.VisibleItems())
	if n < 1 {
		m.list.Paginator.SetTotalPages(1)
	} else {
		m.list.Paginator.SetTotalPages(n)
	}
	if m.list.Paginator.Page >= m.list.Paginator.TotalPages {
		m.list.Paginator.Page = max(0, m.list.Paginator.TotalPages-1)
	}
	m.list.Select(idx)
	m.reconcileAwayFromSeparator(true)
}

func (m *Model) resizeSubviews() {
	m.applyLayoutSizes()
	m.syncViewportContent(false)
}
