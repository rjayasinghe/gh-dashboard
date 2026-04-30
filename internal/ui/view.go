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

	tabBar := m.renderTabBar()
	statusBar := m.renderStatusBar()

	tabBarH := lipgloss.Height(tabBar)
	statusBarH := lipgloss.Height(statusBar)
	contentH := m.windowHeight - tabBarH - statusBarH
	if contentH < 1 {
		contentH = 1
	}

	listW := m.listWidth()
	detailW := m.windowWidth - listW - 2 // -2 for border
	if detailW < 10 {
		detailW = 10
	}

	list := m.renderList(listW, contentH)
	detail := renderDetail(m.selectedItem(), m.hostErrs, m.detailScrollOffset, detailW, contentH)

	body := lipgloss.JoinHorizontal(
		lipgloss.Top,
		listPanelStyle.Width(listW).Height(contentH).Render(list),
		detailPanelStyle.Width(detailW).Height(contentH).Render(detail),
	)

	return lipgloss.JoinVertical(lipgloss.Left, tabBar, body, statusBar)
}

// --- tab bar ---

func (m Model) renderTabBar() string {
	sections := []gh.Section{gh.SectionMyPRs, gh.SectionReviewNeeded, gh.SectionMyIssues}
	labels := []string{"My PRs", "Review Needed", "Issues"}

	var tabs []string
	for i, sec := range sections {
		count := len(m.itemsForSection(sec))
		label := fmt.Sprintf("%s (%d)", labels[i], count)
		if m.loading && count == 0 {
			label = fmt.Sprintf("%s (?)", labels[i])
		}
		if sec == m.activeSection {
			tabs = append(tabs, activeTabStyle.Render(label))
		} else {
			tabs = append(tabs, inactiveTabStyle.Render(label))
		}
	}

	var status string
	if m.loading {
		status = " " + m.spinner.View()
	} else if !m.lastFetched.IsZero() {
		status = "  " + humanDuration(time.Since(m.lastFetched))
	}

	tabsStr := strings.Join(tabs, "")
	gap := m.windowWidth - lipgloss.Width(tabsStr) - lipgloss.Width(status)
	if gap < 0 {
		gap = 0
	}

	return tabBarStyle.Width(m.windowWidth).Render(
		tabsStr + strings.Repeat(" ", gap) + status,
	)
}

// --- status bar ---

func (m Model) renderStatusBar() string {
	hints := "j/k: navigate   J/K: scroll detail   tab: switch tab   o: open in browser   r: refresh   q: quit"
	return statusBarStyle.Width(m.windowWidth).Render(hints)
}

// --- list panel ---

// Each item renders as two lines:
//   line 1: "> Title"  (or "  Title")
//   line 2: "  host · repo"

func (m Model) renderList(width, height int) string {
	items := m.itemsForSection(m.activeSection)

	if len(items) == 0 {
		if m.loading {
			return ""
		}
		return normalItemStyle.Render("  No items")
	}

	// each item = 2 lines; figure out which window of items fits
	visibleCount := height / 2
	if visibleCount < 1 {
		visibleCount = 1
	}

	// keep cursor in the visible window
	start := m.cursor - visibleCount + 1
	if start < 0 {
		start = 0
	}
	if m.cursor < start {
		start = m.cursor
	}
	end := start + visibleCount
	if end > len(items) {
		end = len(items)
		start = end - visibleCount
		if start < 0 {
			start = 0
		}
	}

	maxTitleW := width - 3 // prefix "  " or "> " + 1 spare

	var lines []string
	for i := start; i < end; i++ {
		item := items[i]
		selected := i == m.cursor

		prefix := "  "
		if selected {
			prefix = "> "
		}

		title := truncate(item.Title, maxTitleW)
		titleLine := prefix + title

		subtitle := "  " + truncate(item.Host+" · "+item.Repo, width-3)

		if selected {
			lines = append(lines,
				selectedItemStyle.Width(width).Render(titleLine),
				itemSubtitleStyle.Width(width).Render(subtitle),
			)
		} else {
			lines = append(lines,
				normalItemStyle.Render(titleLine),
				itemSubtitleStyle.Render(subtitle),
			)
		}
	}

	// pad
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
