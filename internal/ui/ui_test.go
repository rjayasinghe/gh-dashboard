package ui

import (
	"strings"
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
	gh "github.com/i540498/dev-dashboard/internal/github"
)

// --- truncate ---

func TestTruncate_ShortString(t *testing.T) {
	if got := truncate("hello", 10); got != "hello" {
		t.Errorf("expected hello, got %s", got)
	}
}

func TestTruncate_ExactLength(t *testing.T) {
	if got := truncate("hello", 5); got != "hello" {
		t.Errorf("expected hello, got %s", got)
	}
}

func TestTruncate_TooLong(t *testing.T) {
	got := truncate("hello world", 8)
	runes := []rune(got)
	if len(runes) != 8 {
		t.Errorf("expected length 8, got %d (%s)", len(runes), got)
	}
	if runes[len(runes)-1] != '…' {
		t.Errorf("expected trailing ellipsis, got %s", got)
	}
}

func TestDetailViewportLinesFitWidth_myPRKvFields(t *testing.T) {
	const width = 38
	it := gh.Item{
		Section:      gh.SectionMyPRs,
		Title:        "short",
		Repo:         "org/repo",
		State:        "OPEN",
		IsDraft:      true,
		ReviewStatus: strings.Repeat("status ", 20),
		CreatedAt:    time.Now(),
		Author:       "alice",
		URL:          "http://example.com/pr/1",
	}
	s := DetailViewportContent(&it, nil, width)
	for i, ln := range strings.Split(s, "\n") {
		if w := ansi.StringWidth(ln); w > width {
			t.Fatalf("line %d display width=%d width=%d", i, w, width)
		}
	}
}

func TestAnsiTruncateJoinedBody_overWideLine(t *testing.T) {
	const lim = 20
	raw := lipgloss.JoinHorizontal(lipgloss.Top,
		lipgloss.NewStyle().Width(8).Render("abcdefgh"),
		lipgloss.NewStyle().Width(20).Render(strings.Repeat("X", 30)),
	)
	out, changed, _, _ := ansiTruncatePhysicalLinesPastWidth(raw, lim)
	if !changed {
		t.Fatal("expected truncation")
	}
	for _, ln := range strings.Split(out, "\n") {
		if ansi.StringWidth(ln) > lim {
			t.Fatalf("line still too wide: %d > %d", ansi.StringWidth(ln), lim)
		}
	}
}

func TestLayoutListPlusDetailEqualsWindowWidth(t *testing.T) {
	m := New(nil, time.Minute)
	m.windowWidth = 118
	m.windowHeight = 40
	lw, dw, _, _, _ := m.layoutDimensions()
	if lw+dw+joinHorizontalMarginCols != m.windowWidth {
		t.Fatalf("listW+detailW+margin=%d+%d+%d want windowWidth %d", lw, dw, joinHorizontalMarginCols, m.windowWidth)
	}
}

func TestTruncate_Unicode(t *testing.T) {
	got := truncate("日本語テスト", 4)
	runes := []rune(got)
	if len(runes) != 4 {
		t.Errorf("expected 4 runes, got %d", len(runes))
	}
	if runes[3] != '…' {
		t.Errorf("expected ellipsis at position 3, got %c", runes[3])
	}
}

// --- humanDuration ---

func TestHumanDuration(t *testing.T) {
	cases := []struct {
		d    time.Duration
		want string
	}{
		{30 * time.Second, "just now"},
		{90 * time.Second, "1m ago"},
		{59 * time.Minute, "59m ago"},
		{2 * time.Hour, "2h ago"},
		{23 * time.Hour, "23h ago"},
		{48 * time.Hour, "2d ago"},
	}
	for _, tc := range cases {
		got := humanDuration(tc.d)
		if got != tc.want {
			t.Errorf("humanDuration(%v): expected %q, got %q", tc.d, tc.want, got)
		}
	}
}

// --- test harness ---

func makeItem(title, host string, section gh.Section) gh.Item {
	return gh.Item{Title: title, Host: host, Repo: "org/repo", Section: section}
}

// newTestModel builds a fully wired *Model for the given window and data (no network).
func newTestModel(items []gh.Item, sec gh.Section, winW, winH int, listGlobalIdx int, loading bool) *Model {
	m := New(nil, time.Minute)
	m.items = items
	m.activeSection = sec
	m.loading = loading
	m.windowWidth = winW
	m.windowHeight = winH
	m.applyLayoutSizes()
	_ = m.syncListFromSection()
	n := len(m.itemsForSection(sec))
	if n > 0 && listGlobalIdx >= 0 && listGlobalIdx < n {
		secItems := m.itemsForSection(sec)
		if idx := listIndexForNthPRInSection(secItems, listGlobalIdx); idx >= 0 {
			m.list.Select(idx)
			m.fixListPaginatorForPopulatedLineBudget()
		}
	}
	m.syncViewportContent(true)
	return m
}

func (m *Model) listPanelRendered() string {
	contentH := m.contentHeight()
	listW, _, _, _, _ := m.layoutDimensions()
	raw := m.renderListBody(contentH)
	return listPanelStyle.Width(listW).Height(contentH).MaxHeight(contentH).Render(raw)
}

func TestListPerPageUsesPopulatedLineBudget(t *testing.T) {
	const winW, winH = 120, 40
	items := make([]gh.Item, 50)
	for i := range items {
		items[i] = makeItem("Title", "github.com", gh.SectionMyPRs)
	}
	m := newTestModel(items, gh.SectionMyPRs, winW, winH, 0, false)
	ch := m.contentHeight()
	want := max(1, ch) // one row per item when ShowDescription=false, SetSpacing(0)
	if m.list.Paginator.PerPage != want {
		t.Fatalf("PerPage=%d want %d (contentH=%d)", m.list.Paginator.PerPage, want, ch)
	}
}

// Regression: bubbles/list PerPage uses item height+spacing but rendering inserts
// an extra newline between items (spacing+1), so raw list lines can exceed contentH.
func TestListRawViewHeightNeverExceedsContentArea(t *testing.T) {
	const winW, winH = 120, 40
	items := make([]gh.Item, 50)
	for i := range items {
		items[i] = makeItem("Title", "github.com", gh.SectionMyPRs)
	}
	m := newTestModel(items, gh.SectionMyPRs, winW, winH, 0, false)
	for step := 0; step < 45; step++ {
		ch := m.contentHeight()
		rawH := lipgloss.Height(m.list.View())
		if rawH > ch {
			t.Fatalf("step %d: list.View lines=%d contentH=%d globalIdx=%d perPage=%d page=%d cursor=%d",
				step, rawH, ch, m.list.GlobalIndex(), m.list.Paginator.PerPage, m.list.Paginator.Page, m.list.Cursor())
		}
		next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'j'}})
		m = next.(*Model)
	}
}

func TestListRawViewHeightWithWideEmojiTitles(t *testing.T) {
	const winW, winH = 120, 40
	items := make([]gh.Item, 30)
	for i := range items {
		items[i] = makeItem(strings.Repeat("🚀", 15)+" title", "github.com", gh.SectionMyPRs)
	}
	m := newTestModel(items, gh.SectionMyPRs, winW, winH, 0, false)
	for step := 0; step < 28; step++ {
		ch := m.contentHeight()
		raw := m.list.View()
		rawH := lipgloss.Height(raw)
		if rawH != ch {
			t.Fatalf("step %d: list.View lines=%d want contentH=%d globalIdx=%d perPage=%d",
				step, rawH, ch, m.list.GlobalIndex(), m.list.Paginator.PerPage)
		}
		next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'j'}})
		m = next.(*Model)
	}
}

func TestFullViewHeightStableWhileScrollingEmojiTitles(t *testing.T) {
	const winW, winH = 127, 63
	items := make([]gh.Item, 45)
	for i := range items {
		items[i] = makeItem(strings.Repeat("🚀", 12)+" PR title", "github.com", gh.SectionMyPRs)
	}
	m := newTestModel(items, gh.SectionMyPRs, winW, winH, 0, false)
	m.lastFetched = time.Now()
	for step := 0; step < 50; step++ {
		out := m.View()
		if h := lipgloss.Height(out); h != winH {
			t.Fatalf("step %d: full View height=%d want %d globalIdx=%d perPage=%d page=%d",
				step, h, winH, m.list.GlobalIndex(), m.list.Paginator.PerPage, m.list.Paginator.Page)
		}
		next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'j'}})
		m = next.(*Model)
	}
}

func TestTabBarSingleLineOnNarrowWindow(t *testing.T) {
	items := make([]gh.Item, 200)
	for i := range items {
		items[i] = makeItem("T", "github.com", gh.SectionMyPRs)
	}
	m := newTestModel(items, gh.SectionMyPRs, 38, 28, 0, false)
	tb := m.renderTabBar()
	if lipgloss.Height(tb) != 1 {
		t.Fatalf("tab bar height=%d want 1 (narrow terminal wraps tabs)", lipgloss.Height(tb))
	}
	full := m.View()
	if lipgloss.Height(full) != m.windowHeight {
		t.Fatalf("full View height=%d window=%d", lipgloss.Height(full), m.windowHeight)
	}
}

// Regression: any physical row wider than the terminal causes soft-wrap and breaks layout.
func TestFullViewNoLineExceedsWindowWidthWhileScrolling(t *testing.T) {
	const winW, winH = 127, 63
	items := make([]gh.Item, 45)
	for i := range items {
		items[i] = makeItem(strings.Repeat("🚀", 12)+" PR title", "github.com", gh.SectionMyPRs)
	}
	m := newTestModel(items, gh.SectionMyPRs, winW, winH, 0, false)
	m.lastFetched = time.Now()
	for step := 0; step < 50; step++ {
		out := m.View()
		lw, dw, _, _, _ := m.layoutDimensions()
		for li, line := range strings.Split(out, "\n") {
			if w := ansi.StringWidth(line); w > winW {
				t.Fatalf("step %d line %d: display width %d > winW %d globalIdx=%d listW=%d detailW=%d",
					step, li, w, winW, m.list.GlobalIndex(), lw, dw)
			}
		}
		next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'j'}})
		m = next.(*Model)
	}
}

// --- list + selection ---

func TestList_LastItemSelectedIsVisibleInPanel(t *testing.T) {
	items := make([]gh.Item, 20)
	for i := range items {
		items[i] = makeItem("Item", "github.com", gh.SectionMyPRs)
	}
	m := newTestModel(items, gh.SectionMyPRs, 120, 20, 19, false)
	out := m.listPanelRendered()
	if !strings.Contains(ansi.Strip(out), "Item") {
		t.Fatalf("expected list panel to contain item title, got %q", ansi.Strip(out))
	}
	if m.list.GlobalIndex() != 20 {
		t.Fatalf("GlobalIndex: got %d want 20", m.list.GlobalIndex())
	}
}

func TestList_FirstItemSelected(t *testing.T) {
	items := make([]gh.Item, 10)
	for i := range items {
		items[i] = makeItem("Item", "github.com", gh.SectionMyPRs)
	}
	m := newTestModel(items, gh.SectionMyPRs, 120, 20, 0, false)
	if m.list.GlobalIndex() != 1 {
		t.Fatalf("GlobalIndex: got %d want 1", m.list.GlobalIndex())
	}
	out := m.listPanelRendered()
	if lipgloss.Height(out) != m.contentHeight() {
		t.Fatalf("list panel height %d want %d", lipgloss.Height(out), m.contentHeight())
	}
}

func TestList_EmptySectionShowsNoItems(t *testing.T) {
	m := newTestModel(nil, gh.SectionMyPRs, 120, 20, 0, false)
	out := m.listPanelRendered()
	plain := strings.ToLower(ansi.Strip(out))
	if !strings.Contains(plain, "no") || !strings.Contains(plain, "item") {
		t.Fatalf("expected empty-state text, got %q", plain)
	}
}

func TestList_WideTitlePanelHeight(t *testing.T) {
	item := makeItem(strings.Repeat("🚀", 40), "github.company.com", gh.SectionMyPRs)
	item.Repo = "org/very-long-repo-name"
	m := newTestModel([]gh.Item{item}, gh.SectionMyPRs, 127, 40, 0, false)
	const w = 38
	contentH := m.contentHeight()
	m.list.SetSize(w-listPanelStyle.GetHorizontalFrameSize(), contentH)
	_ = m.syncListFromSection()
	raw := m.renderListBody(contentH)
	out := listPanelStyle.Width(w).Height(contentH).MaxHeight(contentH).Render(raw)
	if got := lipgloss.Height(out); got != contentH {
		t.Fatalf("styled list panel height: got %d want %d (raw lines=%d)", got, contentH, lipgloss.Height(raw))
	}
}

// --- handleListClick ---

func TestHandleListClick_SelectsCorrectItem(t *testing.T) {
	items := []gh.Item{
		makeItem("First", "github.com", gh.SectionMyPRs),
		makeItem("Second", "github.com", gh.SectionMyPRs),
		makeItem("Third", "github.com", gh.SectionMyPRs),
	}
	m := newTestModel(items, gh.SectionMyPRs, 120, 24, 0, false)

	// Tab bar at Y=0; list rows: host header, First, Second, Third.
	m.handleListClick(3)
	if m.list.GlobalIndex() != 2 {
		t.Errorf("expected GlobalIndex=2 (Second PR) after clicking row 3, got %d", m.list.GlobalIndex())
	}

	m.handleListClick(4)
	if m.list.GlobalIndex() != 3 {
		t.Errorf("expected GlobalIndex=3 (Third PR) after clicking row 4, got %d", m.list.GlobalIndex())
	}
}

func TestHandleListClick_IgnoresTabBar(t *testing.T) {
	items := []gh.Item{makeItem("First", "github.com", gh.SectionMyPRs)}
	m := newTestModel(items, gh.SectionMyPRs, 120, 20, 0, false)
	before := m.list.GlobalIndex()
	m.handleListClick(0)
	if m.list.GlobalIndex() != before {
		t.Errorf("click on tab bar row should not change selection, got %d", m.list.GlobalIndex())
	}
}

// --- Update / keys ---

func TestUpdate_TabCyclesSectionAndResetsList(t *testing.T) {
	items := []gh.Item{
		makeItem("PR-A", "h", gh.SectionMyPRs),
		makeItem("PR-B", "h", gh.SectionMyPRs),
		makeItem("Rev-1", "h", gh.SectionReviewNeeded),
	}
	m := newTestModel(items, gh.SectionMyPRs, 100, 24, 1, false)
	if got := m.list.GlobalIndex(); got != 2 {
		t.Fatalf("setup: index %d (want cursor on second PR in section)", got)
	}

	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyTab})
	m = next.(*Model)
	if m.activeSection != gh.SectionReviewNeeded {
		t.Fatalf("activeSection: got %v want ReviewNeeded", m.activeSection)
	}
	if m.list.GlobalIndex() != 1 {
		t.Fatalf("after tab cursor should reset to first PR row: got index %d", m.list.GlobalIndex())
	}
	secItems := m.itemsForSection(m.activeSection)
	if len(secItems) != 1 || secItems[0].Title != "Rev-1" {
		t.Fatalf("list items: %+v", secItems)
	}
}

func TestUpdate_JKMovesSelection(t *testing.T) {
	items := []gh.Item{
		makeItem("a", "h", gh.SectionMyPRs),
		makeItem("b", "h", gh.SectionMyPRs),
	}
	m := newTestModel(items, gh.SectionMyPRs, 100, 24, 0, false)
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'j'}})
	m = next.(*Model)
	if m.list.GlobalIndex() != 2 {
		t.Fatalf("after j: index %d", m.list.GlobalIndex())
	}
	next, _ = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'k'}})
	m = next.(*Model)
	if m.list.GlobalIndex() != 1 {
		t.Fatalf("after k: index %d", m.list.GlobalIndex())
	}
}

func TestUpdate_JScrollsDetailWithoutMovingList(t *testing.T) {
	now := time.Now()
	item := gh.Item{
		Title: "t", Host: "h", Repo: "o/r", Section: gh.SectionMyPRs,
		CreatedAt: now, Author: "a", State: "open",
		Comments: []gh.Comment{{Author: "c", Body: strings.Repeat("word ", 80), CreatedAt: now}},
	}
	// Short window so detail text is taller than the viewport (scrollable).
	m := newTestModel([]gh.Item{item}, gh.SectionMyPRs, 120, 18, 0, false)
	tl := m.viewport.TotalLineCount()
	vh := m.viewport.Height
	if tl <= vh {
		t.Fatalf("fixture needs scrollable detail: totalLines=%d viewportHeight=%d", tl, vh)
	}
	before := m.list.GlobalIndex()
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'J'}})
	m = next.(*Model)
	if m.list.GlobalIndex() != before {
		t.Fatalf("J should not move list selection")
	}
	if m.viewport.YOffset == 0 {
		t.Fatalf("expected detail viewport to scroll down on J (totalLines=%d height=%d y0=%d)", m.viewport.TotalLineCount(), m.viewport.Height, m.viewport.YOffset)
	}
}

func TestDataLoadedPreservesSelectionWhenItemsReordered(t *testing.T) {
	items := []gh.Item{
		{Title: "A", Host: "h", Repo: "o/r", Number: 10, Section: gh.SectionMyPRs},
		{Title: "B", Host: "h", Repo: "o/r", Number: 20, Section: gh.SectionMyPRs},
	}
	m := newTestModel(items, gh.SectionMyPRs, 100, 28, 1, false)
	shuffled := []gh.Item{
		{Title: "B", Host: "h", Repo: "o/r", Number: 20, Section: gh.SectionMyPRs},
		{Title: "A", Host: "h", Repo: "o/r", Number: 10, Section: gh.SectionMyPRs},
	}
	next, _ := m.Update(dataLoadedMsg{items: shuffled, hostErrs: nil, fetchedAt: time.Now()})
	m = next.(*Model)
	// Grouped list: [host header, #10, #20] — cursor stays on #20 at index 2.
	if want := 2; m.list.GlobalIndex() != want {
		t.Fatalf("GlobalIndex=%d want %d after reorder (cursor should follow PR #20)", m.list.GlobalIndex(), want)
	}
	it := m.selectedItem()
	if it == nil || it.Number != 20 {
		t.Fatalf("selected item: %+v", it)
	}
}

func TestUpdate_DataLoadedReplacesItems(t *testing.T) {
	m := newTestModel(nil, gh.SectionMyPRs, 100, 24, 0, true)
	next0, _ := m.Update(tea.WindowSizeMsg{Width: 100, Height: 24})
	m = next0.(*Model)
	loaded := []gh.Item{
		makeItem("Fresh", "github.com", gh.SectionMyPRs),
	}
	next, _ := m.Update(dataLoadedMsg{items: loaded, hostErrs: nil, fetchedAt: time.Now()})
	m = next.(*Model)
	if m.loading {
		t.Fatal("expected loading=false after dataLoaded")
	}
	if got := m.list.GlobalIndex(); got != 1 {
		t.Fatalf("list index: got %d (first PR sits after host header)", got)
	}
	if m.selectedItem() == nil || m.selectedItem().Title != "Fresh" {
		t.Fatalf("selected item: %+v", m.selectedItem())
	}
}

func TestUpdate_WindowSizeChangesDetailWidth(t *testing.T) {
	item := makeItem(strings.Repeat("ab", 80), "h", gh.SectionMyPRs)
	m := newTestModel([]gh.Item{item}, gh.SectionMyPRs, 80, 24, 0, false)
	wNarrow := m.detailInnerWidth()
	next, _ := m.Update(tea.WindowSizeMsg{Width: 200, Height: 24})
	m = next.(*Model)
	if wWide := m.detailInnerWidth(); wWide <= wNarrow {
		t.Fatalf("expected wider detail after resize: narrow=%d wide=%d", wNarrow, wWide)
	}
}

func TestUpdate_QAndCtrlCEmitQuitCmd(t *testing.T) {
	m := newTestModel(nil, gh.SectionMyPRs, 80, 20, 0, false)
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'q'}})
	if cmd == nil {
		t.Fatal("expected non-nil cmd for q (quit)")
	}
	_, cmd2 := m.Update(tea.KeyMsg{Type: tea.KeyCtrlC})
	if cmd2 == nil {
		t.Fatal("expected non-nil cmd for ctrl+c (quit)")
	}
}

// --- wrapText ---

func TestWrapText_ShortLine(t *testing.T) {
	got := wrapText("hello world", 80)
	if len(got) != 1 || got[0] != "hello world" {
		t.Errorf("expected single line, got %v", got)
	}
}

func TestWrapText_WrapsAtWidth(t *testing.T) {
	got := wrapText("one two three four five", 10)
	for _, line := range got {
		if ansi.StringWidth(line) > 10 {
			t.Errorf("line exceeds max width: %q (cells=%d)", line, ansi.StringWidth(line))
		}
	}
}

func TestWrapText_EmojiCellsNotRunes(t *testing.T) {
	got := wrapText(strings.Repeat("🚀", 20)+" words", 10)
	for _, line := range got {
		if w := ansi.StringWidth(line); w > 10 {
			t.Fatalf("line cells=%d want ≤10: %q", w, line)
		}
	}
}

func TestWrapText_PreservesNewlines(t *testing.T) {
	got := wrapText("line one\nline two", 80)
	if len(got) != 2 {
		t.Errorf("expected 2 lines from newline, got %d: %v", len(got), got)
	}
}

func TestWrapText_EmptyParagraph(t *testing.T) {
	got := wrapText("a\n\nb", 80)
	if len(got) != 3 {
		t.Errorf("expected 3 lines (blank middle), got %d: %v", len(got), got)
	}
	if got[1] != "" {
		t.Errorf("expected empty middle line, got %q", got[1])
	}
}

// --- renderDetail / viewport ---

func TestRenderDetail_ScrollClamp(t *testing.T) {
	item := &gh.Item{
		Title:     "Test PR",
		URL:       "https://github.com/org/repo/pull/1",
		Repo:      "org/repo",
		State:     "OPEN",
		Author:    "alice",
		Section:   gh.SectionMyPRs,
		CreatedAt: time.Now().Add(-24 * time.Hour),
	}

	height := 10
	result := renderDetail(item, nil, 9999, 60, height)
	lines := splitLines(result)
	if len(lines) != height {
		t.Errorf("expected %d lines, got %d", height, len(lines))
	}
}

func TestRenderDetail_NilItem(t *testing.T) {
	result := renderDetail(nil, nil, 0, 60, 10)
	if result == "" {
		t.Error("expected non-empty result for nil item")
	}
}

func TestFlattenPhysicalLines(t *testing.T) {
	got := flattenPhysicalLines([]string{"a\nb", "c", ""})
	want := []string{"a", "b", "c", ""}
	if len(got) != len(want) {
		t.Fatalf("got %v (%d elts), want %v", got, len(got), want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("i=%d got %q want %q", i, got[i], want[i])
		}
	}
}

func TestRenderDetail_ExactPhysicalHeight(t *testing.T) {
	item := &gh.Item{
		Title:     "t",
		URL:       "https://example.com",
		Repo:      strings.Repeat("x", 200) + "/y",
		State:     "OPEN",
		Author:    "a",
		Section:   gh.SectionMyPRs,
		CreatedAt: time.Now(),
	}
	const h, w = 14, 30
	out := renderDetail(item, nil, 0, w, h)
	if n := lipgloss.Height(out); n != h {
		t.Fatalf("renderDetail output height: got %d want %d", n, h)
	}
}

func TestDetailViewportContent_MatchesJoinedPhysicalLines(t *testing.T) {
	item := &gh.Item{
		Title: "x", URL: "https://u", Repo: "o/r", State: "OPEN",
		Section: gh.SectionMyPRs, CreatedAt: time.Now(), Author: "a",
	}
	got := DetailViewportContent(item, nil, 40)
	lines := flattenPhysicalLines(buildDetailLines(item, nil, 40))
	want := strings.Join(lines, "\n")
	if got != want {
		t.Fatalf("DetailViewportContent mismatch")
	}
}

func TestView_FrameHeightEqualsWindow(t *testing.T) {
	const winW, winH = 127, 63
	now := time.Now()
	longRepo := strings.Repeat("x", 200) + "/repo"
	item := gh.Item{
		Title:        strings.Repeat("🚀", 40) + " Long PR title",
		URL:          "https://github.com/org/repo/pull/1",
		Repo:         longRepo,
		State:        "OPEN",
		Section:      gh.SectionMyPRs,
		CreatedAt:    now,
		Author:       "octocat",
		Labels:       []string{"area/ui", "priority/high"},
		ReviewStatus: "changes_requested",
		IsDraft:      true,
		Comments: []gh.Comment{{
			Author:    "reviewer",
			Body:      strings.Repeat("comment words ", 120),
			CreatedAt: now,
		}},
	}
	m := newTestModel([]gh.Item{item}, gh.SectionMyPRs, winW, winH, 0, false)
	m.lastFetched = now
	out := m.View()
	if out == "" {
		t.Fatal("empty View")
	}
	if got := lipgloss.Height(out); got != winH {
		t.Fatalf("full View height %d want %d", got, winH)
	}
}

func TestView_LoadingEmptySectionBlankList(t *testing.T) {
	m := newTestModel(nil, gh.SectionMyPRs, 100, 20, 0, true)
	raw := m.renderListBody(m.contentHeight())
	if strings.TrimSpace(ansi.Strip(raw)) != "" {
		t.Fatalf("expected blank list body while loading empty section, got %q", raw)
	}
}

func splitLines(s string) []string {
	var lines []string
	start := 0
	for i, r := range s {
		if r == '\n' {
			lines = append(lines, s[start:i])
			start = i + 1
		}
	}
	lines = append(lines, s[start:])
	return lines
}
