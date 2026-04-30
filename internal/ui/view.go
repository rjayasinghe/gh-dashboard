package ui

import (
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"
	gh "github.com/i540498/dev-dashboard/internal/github"
)

func (m Model) View() string {
	if m.windowWidth == 0 {
		return ""
	}

	header := m.renderHeader()
	footer := m.renderFooter()

	headerH := lipgloss.Height(header)
	footerH := lipgloss.Height(footer)
	contentH := m.windowHeight - headerH - footerH
	if contentH < 1 {
		contentH = 1
	}

	listW := m.windowWidth * 30 / 100
	if listW < 30 {
		listW = 30
	}
	// -2 for the border character rendered by listPanelStyle
	detailW := m.windowWidth - listW - 2
	if detailW < 10 {
		detailW = 10
	}

	list := m.renderList(listW, contentH)
	detail := renderDetail(m.selectedItem(), m.hostErrs, detailW, contentH)

	body := lipgloss.JoinHorizontal(
		lipgloss.Top,
		listPanelStyle.Width(listW).Height(contentH).Render(list),
		detailPanelStyle.Width(detailW).Height(contentH).Render(detail),
	)

	return lipgloss.JoinVertical(lipgloss.Left, header, body, footer)
}

func (m Model) renderHeader() string {
	title := headerStyle.Render("dev-dashboard")

	counts := badgeStyle.Render(fmt.Sprintf(
		" My PRs: %d  Review: %d  Issues: %d ",
		len(m.itemsForSection(gh.SectionMyPRs)),
		len(m.itemsForSection(gh.SectionReviewNeeded)),
		len(m.itemsForSection(gh.SectionMyIssues)),
	))

	var status string
	if m.loading {
		status = m.spinner.View() + " loading…"
	} else if !m.lastFetched.IsZero() {
		status = "Last: " + humanDuration(time.Since(m.lastFetched)) + "  r↺"
	}

	used := lipgloss.Width(title) + lipgloss.Width(counts) + lipgloss.Width(status)
	gap := m.windowWidth - used
	if gap < 1 {
		gap = 1
	}

	return title + counts + strings.Repeat(" ", gap) + status
}

func (m Model) renderFooter() string {
	hints := "  j/k/scroll: navigate   click: select   tab: section   o/click-detail: browser   r: refresh   q: quit"
	return footerStyle.Width(m.windowWidth).Render(hints)
}

// --- list ---

type rowKind int

const (
	rowSection rowKind = iota
	rowHost
	rowItem
)

type listRow struct {
	kind    rowKind
	label   string
	item    *gh.Item
	section gh.Section
	itemIdx int // index within that section's item slice
}

func (m Model) buildRows() []listRow {
	sections := []gh.Section{gh.SectionMyPRs, gh.SectionReviewNeeded, gh.SectionMyIssues}

	var rows []listRow
	for _, sec := range sections {
		rows = append(rows, listRow{kind: rowSection, label: sec.Label(), section: sec})

		hostOrder, byHost := groupByHost(m.itemsForSection(sec))
		flatIdx := 0 // flat index across all hosts within this section
		for _, host := range hostOrder {
			rows = append(rows, listRow{kind: rowHost, label: "[" + host + "]", section: sec})
			for i := range byHost[host] {
				rows = append(rows, listRow{
					kind:    rowItem,
					label:   byHost[host][i].Title,
					item:    &byHost[host][i],
					section: sec,
					itemIdx: flatIdx,
				})
				flatIdx++
			}
		}
	}
	return rows
}

func groupByHost(items []gh.Item) ([]string, map[string][]gh.Item) {
	order := []string{}
	seen := map[string]bool{}
	byHost := map[string][]gh.Item{}

	for _, item := range items {
		if !seen[item.Host] {
			seen[item.Host] = true
			order = append(order, item.Host)
		}
		byHost[item.Host] = append(byHost[item.Host], item)
	}
	return order, byHost
}

func (m Model) renderList(width, height int) string {
	rows := m.buildRows()
	maxTitleW := width - 4 // 2 indent + cursor + space

	// find the screen row of the selected item so we can auto-scroll to it
	selectedRowIdx := -1
	for i, row := range rows {
		if row.kind == rowItem && row.section == m.activeSection && row.itemIdx == m.cursor {
			selectedRowIdx = i
			break
		}
	}

	// clamp scroll so the selected item stays visible
	offset := m.listScrollOffset
	if selectedRowIdx >= 0 {
		if selectedRowIdx < offset {
			offset = selectedRowIdx
		} else if selectedRowIdx >= offset+height {
			offset = selectedRowIdx - height + 1
		}
	}
	// clamp offset to valid range
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

	// apply scroll window
	visible := rows
	if offset < len(rows) {
		visible = rows[offset:]
	}
	if len(visible) > height {
		visible = visible[:height]
	}

	var lines []string
	for _, row := range visible {
		switch row.kind {
		case rowSection:
			lines = append(lines, sectionHeaderStyle.Width(width).Render(row.label))

		case rowHost:
			lines = append(lines, "  "+hostLabelStyle.Render(row.label))

		case rowItem:
			isSelected := row.section == m.activeSection && row.itemIdx == m.cursor
			prefix := "  "
			if isSelected {
				prefix = "> "
			}
			title := truncate(row.label, maxTitleW)
			line := prefix + title
			if isSelected {
				lines = append(lines, selectedItemStyle.Width(width).Render(line))
			} else {
				lines = append(lines, normalItemStyle.Render(line))
			}
		}
	}

	// pad to fill height so the border is uniform
	for len(lines) < height {
		lines = append(lines, "")
	}

	return strings.Join(lines, "\n")
}

// --- helpers ---

func truncate(s string, max int) string {
	runes := []rune(s)
	if len(runes) <= max {
		return s
	}
	return string(runes[:max-1]) + "…"
}

func humanDuration(d time.Duration) string {
	switch {
	case d < time.Minute:
		return "just now"
	case d < time.Hour:
		return fmt.Sprintf("%dm ago", int(d.Minutes()))
	case d < 24*time.Hour:
		return fmt.Sprintf("%dh ago", int(d.Hours()))
	default:
		return fmt.Sprintf("%dd ago", int(d.Hours()/24))
	}
}
