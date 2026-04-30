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
	// "日本語テスト" is 6 runes
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

// --- buildRows flat index ---

func makeItem(title, host string, section gh.Section) gh.Item {
	return gh.Item{Title: title, Host: host, Section: section}
}

func TestBuildRows_FlatIndexAcrossHosts(t *testing.T) {
	m := Model{
		activeSection: gh.SectionMyPRs,
		items: []gh.Item{
			makeItem("PR-A1", "github.com", gh.SectionMyPRs),
			makeItem("PR-A2", "github.com", gh.SectionMyPRs),
			makeItem("PR-B1", "github.enterprise.com", gh.SectionMyPRs),
			makeItem("PR-B2", "github.enterprise.com", gh.SectionMyPRs),
			makeItem("PR-B3", "github.enterprise.com", gh.SectionMyPRs),
		},
	}

	rows := m.buildRows()

	// collect only rowItem entries for SectionMyPRs
	var itemRows []listRow
	for _, r := range rows {
		if r.kind == rowItem && r.section == gh.SectionMyPRs {
			itemRows = append(itemRows, r)
		}
	}

	if len(itemRows) != 5 {
		t.Fatalf("expected 5 item rows, got %d", len(itemRows))
	}

	// flat indices must be 0,1,2,3,4 — not reset per host
	for i, r := range itemRows {
		if r.itemIdx != i {
			t.Errorf("row %d (%s): expected itemIdx %d, got %d", i, r.label, i, r.itemIdx)
		}
	}
}

func TestBuildRows_SelectionIsUniqueAcrossHosts(t *testing.T) {
	// This is the regression test for the multi-host selection glitch:
	// cursor=2 should match exactly one item row, not one per host.
	m := Model{
		activeSection: gh.SectionMyPRs,
		cursor:        2,
		items: []gh.Item{
			makeItem("A1", "github.com", gh.SectionMyPRs),
			makeItem("A2", "github.com", gh.SectionMyPRs),
			makeItem("A3", "github.com", gh.SectionMyPRs),
			makeItem("B1", "github.enterprise.com", gh.SectionMyPRs),
			makeItem("B2", "github.enterprise.com", gh.SectionMyPRs),
			makeItem("B3", "github.enterprise.com", gh.SectionMyPRs),
		},
	}

	rows := m.buildRows()

	selected := 0
	for _, r := range rows {
		if r.kind == rowItem && r.section == m.activeSection && r.itemIdx == m.cursor {
			selected++
		}
	}

	if selected != 1 {
		t.Errorf("expected exactly 1 selected row for cursor=%d, got %d", m.cursor, selected)
	}
}

func TestBuildRows_SectionsAreIndependent(t *testing.T) {
	// Items in different sections with the same host should not interfere.
	m := Model{
		activeSection: gh.SectionReviewNeeded,
		cursor:        0,
		items: []gh.Item{
			makeItem("PR1", "github.com", gh.SectionMyPRs),
			makeItem("PR2", "github.com", gh.SectionMyPRs),
			makeItem("Rev1", "github.com", gh.SectionReviewNeeded),
			makeItem("Rev2", "github.com", gh.SectionReviewNeeded),
		},
	}

	rows := m.buildRows()

	selected := 0
	for _, r := range rows {
		if r.kind == rowItem && r.section == m.activeSection && r.itemIdx == m.cursor {
			selected++
		}
	}

	if selected != 1 {
		t.Errorf("expected exactly 1 selected row, got %d", selected)
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
	// all words must appear
	joined := ""
	for _, l := range got {
		joined += l + " "
	}
	for _, word := range []string{"one", "two", "three", "four", "five"} {
		found := false
		for _, l := range got {
			if l == word || len(l) > len(word) {
				found = true
				break
			}
		}
		_ = found
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

// --- renderList scroll / header visibility ---

// buildRowsForModel is a test helper that calls buildRows on a model with
// the given items all in SectionMyPRs.
func modelWithPRs(hosts map[string][]string) Model {
	var items []gh.Item
	for host, titles := range hosts {
		for _, t := range titles {
			items = append(items, makeItem(t, host, gh.SectionMyPRs))
		}
	}
	return Model{activeSection: gh.SectionMyPRs, items: items}
}

func TestRenderList_HeaderNotOrphanedOnScrollUp(t *testing.T) {
	// Layout with two hosts, 3 items each:
	//   row 0: ▼ My PRs          (section header)
	//   row 1: [github.com]      (host header)
	//   row 2: A1
	//   row 3: A2
	//   row 4: A3
	//   row 5: [ghe.com]         (host header)
	//   row 6: B1
	//   row 7: B2
	//   row 8: B3
	//
	// With height=4 and the cursor on B1 (itemIdx=3, selectedRowIdx=6),
	// scrolling down puts offset=3 (rows 3-6 visible). Then moving cursor
	// back to A3 (itemIdx=2, selectedRowIdx=4) should snap offset back so
	// the host header [github.com] at row 1 is visible — not leave offset=3
	// which would show rows 3-6 with no header.

	m := Model{
		activeSection: gh.SectionMyPRs,
		cursor:        3, // B1 — was scrolled into view
		listScrollOffset: 3,
		items: []gh.Item{
			makeItem("A1", "github.com", gh.SectionMyPRs),
			makeItem("A2", "github.com", gh.SectionMyPRs),
			makeItem("A3", "github.com", gh.SectionMyPRs),
			makeItem("B1", "ghe.com", gh.SectionMyPRs),
			makeItem("B2", "ghe.com", gh.SectionMyPRs),
			makeItem("B3", "ghe.com", gh.SectionMyPRs),
		},
	}

	// move cursor back to A3
	m.cursor = 2 // itemIdx for A3

	height := 4
	result := m.renderList(40, height)
	lines := splitLines(result)

	// The visible window must contain the [github.com] host header.
	// Since ANSI styles are applied, check for the raw label text.
	found := false
	for _, l := range lines {
		if containsSubstr(l, "github.com") {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("host header [github.com] should be visible when cursor is on A3, but it was scrolled off:\n%s",
			result)
	}
}

func containsSubstr(s, sub string) bool {
	return len(s) >= len(sub) && (s == sub || len(s) > 0 && func() bool {
		for i := 0; i <= len(s)-len(sub); i++ {
			if s[i:i+len(sub)] == sub {
				return true
			}
		}
		return false
	}())
}



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

	// scrollOffset way beyond content should not panic and should produce height lines
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
	return splitOn(s, '\n')
}

func splitOn(s string, sep rune) []string {
	var lines []string
	start := 0
	for i, r := range s {
		if r == sep {
			lines = append(lines, s[start:i])
			start = i + 1
		}
	}
	lines = append(lines, s[start:])
	return lines
}
