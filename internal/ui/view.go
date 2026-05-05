package ui

import (
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
	gh "github.com/i540498/dev-dashboard/internal/github"
)

func (m *Model) View() string {
	if m.windowWidth == 0 {
		return ""
	}

	tabBar := m.renderTabBar()
	statusBar := m.renderStatusBar()
	contentH := m.contentHeight()

	listW, detailW, _, _, _ := m.layoutDimensions()

	list := m.renderListBody(contentH)
	detail := m.renderDetailPanel(detailW, contentH)

	listPanel := listPanelStyle.Width(listW).MaxWidth(listW).Height(contentH).MaxHeight(contentH).Render(list)

	body := lipgloss.JoinHorizontal(
		lipgloss.Top,
		listPanel,
		detail,
	)

	body, _, _, _ = ansiTruncatePhysicalLinesPastWidth(body, m.windowWidth)

	out := lipgloss.JoinVertical(lipgloss.Left, tabBar, body, statusBar)
	out = clampViewLinesToDisplayWidth(out, m.windowWidth)

	return out
}

// clampViewLinesToDisplayWidth prevents terminal soft-wrap: any logical row wider
// than the terminal shifts subsequent rows and corrupts the layout (duplicate
// selection / missing tab bar).
func clampViewLinesToDisplayWidth(s string, maxCells int) string {
	if maxCells < 1 {
		maxCells = 1
	}
	lines := strings.Split(s, "\n")
	for i, ln := range lines {
		if w := ansi.StringWidth(ln); w > maxCells {
			lines[i] = ansi.Truncate(ln, maxCells, "…")
		}
	}
	return strings.Join(lines, "\n")
}

// ansiTruncatePhysicalLinesPastWidth clamps each row of lipgloss.JoinHorizontal output:
// Join pads with spaces using ansi.StringWidth; if the emulator paints wider than ansi
// reports, rows can extend past listW+detailW and the terminal wraps (My PRs + detail).
func ansiTruncatePhysicalLinesPastWidth(block string, maxCells int) (out string, clipped bool, worstBefore int, rows int) {
	if maxCells < 1 {
		maxCells = 1
	}
	lines := strings.Split(block, "\n")
	for i, ln := range lines {
		w := ansi.StringWidth(ln)
		if w > maxCells {
			clipped = true
			rows++
			if w > worstBefore {
				worstBefore = w
			}
			lines[i] = ansi.Truncate(ln, maxCells, "…")
		}
	}
	return strings.Join(lines, "\n"), clipped, worstBefore, rows
}

func (m *Model) renderTabBar() string {
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

	dims := terminalDimsStyle.Render(fmt.Sprintf("%d×%d", m.windowWidth, m.windowHeight))
	var status string
	if m.loading {
		status = " " + m.spinner.View() + " " + dims
	} else if !m.lastFetched.IsZero() {
		status = "  " + humanDuration(time.Since(m.lastFetched)) + "  " + dims
	} else {
		status = " " + dims
	}

	left := strings.Join(tabs, "")
	leftW := lipgloss.Width(left)
	rightW := lipgloss.Width(status)

	if leftW+rightW >= m.windowWidth {
		maxLeft := m.windowWidth - rightW - 1
		if maxLeft < 12 {
			maxLeft = max(8, m.windowWidth*3/5)
		}
		if maxLeft < 1 {
			maxLeft = 1
		}
		left = ansi.Truncate(left, maxLeft, "…")
		leftW = lipgloss.Width(left)
	}

	gapW := m.windowWidth - leftW - rightW
	if gapW < 1 {
		gapW = 1
	}

	line := left + strings.Repeat(" ", gapW) + status
	if lipgloss.Width(line) > m.windowWidth {
		line = ansi.Truncate(line, m.windowWidth, "…")
	}

	return tabBarStyle.Width(m.windowWidth).MaxWidth(m.windowWidth).Render(line)
}

func (m *Model) renderStatusBar() string {
	hints := "j/k: navigate   J/K: scroll detail   tab: switch tab   o: open in browser   r: refresh   q: quit"
	hints = truncate(hints, m.windowWidth-2)
	return statusBarStyle.Width(m.windowWidth).Render(hints)
}

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
