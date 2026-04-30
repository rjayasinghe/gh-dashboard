package ui

import (
	"testing"
	"time"

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

// --- list scroll window ---

func makeItem(title, host string, section gh.Section) gh.Item {
	return gh.Item{Title: title, Host: host, Repo: "org/repo", Section: section}
}

func TestRenderList_CursorAlwaysVisible(t *testing.T) {
	items := make([]gh.Item, 20)
	for i := range items {
		items[i] = makeItem("Item", "github.com", gh.SectionMyPRs)
	}

	m := Model{
		activeSection: gh.SectionMyPRs,
		items:         items,
		windowWidth:   120,
		windowHeight:  20,
	}

	// move cursor to last item
	m.cursor = 19
	result := m.renderList(40, 16)
	lines := splitLines(result)

	// find "> " prefix — selected item must appear somewhere
	found := false
	for _, l := range lines {
		if len(l) >= 2 && l[0] == '>' {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("cursor at last item: selected item not visible in rendered list")
	}
}

func TestRenderList_CursorVisibleAtTop(t *testing.T) {
	items := make([]gh.Item, 10)
	for i := range items {
		items[i] = makeItem("Item", "github.com", gh.SectionMyPRs)
	}

	m := Model{
		activeSection: gh.SectionMyPRs,
		cursor:        0,
		items:         items,
		windowWidth:   120,
		windowHeight:  20,
	}

	result := m.renderList(40, 16)
	lines := splitLines(result)

	found := false
	for _, l := range lines {
		if len(l) >= 2 && l[0] == '>' {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("cursor at first item: selected item not visible in rendered list")
	}
}

func TestRenderList_EmptySection(t *testing.T) {
	m := Model{
		activeSection: gh.SectionMyPRs,
		items:         []gh.Item{},
	}
	result := m.renderList(40, 10)
	if result == "" {
		t.Error("expected non-empty result for empty section")
	}
}

// --- handleListClick ---

func TestHandleListClick_SelectsCorrectItem(t *testing.T) {
	items := []gh.Item{
		makeItem("First", "github.com", gh.SectionMyPRs),
		makeItem("Second", "github.com", gh.SectionMyPRs),
		makeItem("Third", "github.com", gh.SectionMyPRs),
	}
	m := &Model{
		activeSection: gh.SectionMyPRs,
		items:         items,
	}

	// tab bar is row 0; item 0 = rows 1-2, item 1 = rows 3-4, item 2 = rows 5-6
	m.handleListClick(3) // click on item 1 title row
	if m.cursor != 1 {
		t.Errorf("expected cursor=1 after clicking row 3, got %d", m.cursor)
	}

	m.handleListClick(5) // click on item 2 title row
	if m.cursor != 2 {
		t.Errorf("expected cursor=2 after clicking row 5, got %d", m.cursor)
	}
}

func TestHandleListClick_IgnoresTabBar(t *testing.T) {
	items := []gh.Item{makeItem("First", "github.com", gh.SectionMyPRs)}
	m := &Model{
		activeSection: gh.SectionMyPRs,
		cursor:        0,
		items:         items,
	}
	m.handleListClick(0) // row 0 = tab bar
	if m.cursor != 0 {
		t.Errorf("click on tab bar row should not change cursor, got %d", m.cursor)
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
		if len([]rune(line)) > 10 {
			t.Errorf("line exceeds max width: %q", line)
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

// --- renderDetail scroll clamping ---

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
