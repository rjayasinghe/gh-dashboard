package ui

import (
	"fmt"
	"io"
	"sort"
	"strings"

	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
	gh "github.com/i540498/dev-dashboard/internal/github"
)

// hostSeparatorItem is a non-selectable list row marking a GitHub host group.
type hostSeparatorItem struct {
	host string
}

func (h hostSeparatorItem) FilterValue() string { return " " + h.host + " " }

// displayHost strips a common URL prefix for compact headers.
func displayHost(raw string) string {
	s := strings.TrimSpace(raw)
	s = strings.TrimPrefix(strings.TrimPrefix(s, "https://"), "http://")
	return s
}

// groupedListItems returns list rows: one header row per Host, PRs sorted by
// Host then UpdatedAt (newest first) within each host; order is stable for ties.
func groupedListItems(sec []gh.Item) []list.Item {
	if len(sec) == 0 {
		return nil
	}
	sorted := append([]gh.Item(nil), sec...)
	sort.SliceStable(sorted, func(i, j int) bool {
		ha, hb := sorted[i].Host, sorted[j].Host
		if ha != hb {
			return ha < hb
		}
		if !sorted[i].UpdatedAt.Equal(sorted[j].UpdatedAt) {
			return sorted[i].UpdatedAt.After(sorted[j].UpdatedAt)
		}
		return sorted[i].Number < sorted[j].Number
	})
	var out []list.Item
	var prevHost string
	for _, it := range sorted {
		if it.Host != prevHost {
			out = append(out, hostSeparatorItem{host: it.Host})
			prevHost = it.Host
		}
		out = append(out, ghListItem{item: it})
	}
	return out
}

// listIndexForNthPRInSection maps the n-th displayed PR row (0-based among PRs
// only) to the bubbles list GlobalIndex including host headers.
func listIndexForNthPRInSection(sec []gh.Item, n int) int {
	if n < 0 {
		return -1
	}
	li := groupedListItems(sec)
	k := 0
	for i, it := range li {
		if _, ok := it.(hostSeparatorItem); ok {
			continue
		}
		if k == n {
			return i
		}
		k++
	}
	return -1
}

// hostGroupedDelegate renders host headers and one-line PR rows (Height always 1).
type hostGroupedDelegate struct{}

func (hostGroupedDelegate) Height() int   { return 1 }
func (hostGroupedDelegate) Spacing() int  { return 0 }
func (hostGroupedDelegate) Update(tea.Msg, *list.Model) tea.Cmd {
	return nil
}

func lineInnerWidth(listModel list.Model) int {
	w := listModel.Width()
	if w < 3 {
		return 1
	}
	const sidePad = 2
	return max(1, w-sidePad)
}

func (hostGroupedDelegate) Render(w io.Writer, listModel list.Model, index int, item list.Item) {
	inner := lineInnerWidth(listModel)
	if inner < 1 {
		return
	}

	if hs, ok := item.(hostSeparatorItem); ok {
		label := displayHost(hs.host)
		label = ansi.Truncate(label, inner, "…")
		line := hostGroupHeaderStyle.Width(inner).MaxWidth(inner).Render(" " + label + " ")
		fmt.Fprint(w, line) //nolint: errcheck
		return
	}

	gi, ok := item.(ghListItem)
	if !ok {
		return
	}

	isSelected := index == listModel.Index()
	filterEmpty := listModel.FilterState() == list.Filtering && listModel.FilterValue() == ""

	pr := gi.item

	var numStr string
	if pr.Number != 0 {
		numStr = fmt.Sprintf("#%d", pr.Number)
	} else {
		numStr = "—"
	}
	numCol := listPRNumberStyle.Render("  "+numStr+" ") // outer padding aligns with legacy list rows

	repoBare := ansi.Truncate(pr.Repo, min(34, inner/3), "…")

	draftPiece := ""
	if pr.IsDraft {
		draftPiece = draftStyle.Render("draft ")
	}

	prefixCells := ansi.StringWidth(ansi.Strip(numCol)) + ansi.StringWidth(draftPiece)
	repoTrail := ansi.StringWidth(" · " + ansi.Strip(repoBare))
	titleBudget := inner - prefixCells - repoTrail
	if titleBudget < 8 {
		titleBudget = inner / 2
		if titleBudget < 4 {
			titleBudget = 4
		}
	}
	titleCut := ansi.Truncate(pr.Title, titleBudget, "…")
	titleCol := lipgloss.NewStyle().Foreground(lipgloss.Color("252")).Render(titleCut)
	repoCol := listPRRepoStyle.Render(" · " + repoBare)

	row := zebraBackgroundForPRIndex(prStripeIndex(listModel, index)).Render(numCol + draftPiece + titleCol + repoCol)
	if filterEmpty {
		row = dimItemStyle.Render(row)
	} else if isSelected {
		row = selectedItemStyle.Render(row)
	} else {
		row = normalItemStyle.Render(row)
	}

	row = ansi.Truncate(row, inner+8, "") // ANSI-safe cap; avoids rare overflow
	fmt.Fprint(w, row) //nolint: errcheck
}

// prStripeIndex is the count of PR rows (excluding host headers) strictly before globalIndex.
func prStripeIndex(listModel list.Model, globalIndex int) int {
	items := listModel.VisibleItems()
	if globalIndex <= 0 {
		return 0
	}
	n := len(items)
	if globalIndex > n {
		globalIndex = n
	}
	cnt := 0
	for gi := 0; gi < globalIndex && gi < n; gi++ {
		if _, ok := items[gi].(hostSeparatorItem); !ok {
			cnt++
		}
	}
	return cnt
}

func zebraBackgroundForPRIndex(prIndex int) lipgloss.Style {
	if prIndex%2 == 1 {
		return listRowAltStyle
	}
	return lipgloss.NewStyle()
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
