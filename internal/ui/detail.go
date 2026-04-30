package ui

import (
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"
	gh "github.com/i540498/dev-dashboard/internal/github"
)

func renderDetail(item *gh.Item, hostErrs map[string]error, width, height int) string {
	if item == nil {
		return detailKeyStyle.Render("No item selected")
	}

	age := humanDuration(time.Since(item.CreatedAt))

	lines := []string{
		detailTitleStyle.Width(width).Render(item.Title),
		"",
		kv("repo", item.Repo, width),
		kv("status", strings.ToLower(item.State), width),
	}

	if item.Section != gh.SectionMyIssues {
		draft := "no"
		if item.IsDraft {
			draft = draftStyle.Render("yes (draft)")
		}
		lines = append(lines,
			kv("draft", draft, width),
			kv("reviews", item.ReviewStatus, width),
		)
	}

	lines = append(lines,
		kv("opened", age, width),
		kv("author", item.Author, width),
	)

	if len(item.Labels) > 0 {
		lines = append(lines, kv("labels", strings.Join(item.Labels, ", "), width))
	}

	lines = append(lines,
		"",
		urlStyle.Render(item.URL),
		"",
		detailKeyStyle.Render("[o] open in browser"),
	)

	for host, err := range hostErrs {
		lines = append(lines, "", errorStyle.Render(fmt.Sprintf("Error (%s): %s", host, err.Error())))
	}

	// pad
	for len(lines) < height {
		lines = append(lines, "")
	}

	return strings.Join(lines, "\n")
}

func kv(key, value string, width int) string {
	k := detailKeyStyle.Render(key + ": ")
	availW := width - lipgloss.Width(k)
	if availW < 1 {
		availW = 1
	}
	v := detailValueStyle.Width(availW).Render(value)
	return k + v
}
