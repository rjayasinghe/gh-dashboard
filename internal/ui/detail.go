package ui

import (
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"
	gh "github.com/i540498/dev-dashboard/internal/github"
)

func renderDetail(item *gh.Item, hostErrs map[string]error, scrollOffset, width, height int) string {
	if item == nil {
		return detailKeyStyle.Render("No item selected")
	}

	// build the full content as a slice of lines, then apply scroll + clip
	lines := buildDetailLines(item, hostErrs, width)

	// clamp scroll offset
	maxOffset := len(lines) - height
	if maxOffset < 0 {
		maxOffset = 0
	}
	if scrollOffset > maxOffset {
		scrollOffset = maxOffset
	}
	if scrollOffset < 0 {
		scrollOffset = 0
	}

	visible := lines[scrollOffset:]
	if len(visible) > height {
		visible = visible[:height]
	}

	// pad to fill height
	for len(visible) < height {
		visible = append(visible, "")
	}

	return strings.Join(visible, "\n")
}

func buildDetailLines(item *gh.Item, hostErrs map[string]error, width int) []string {
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

	// comments section
	if len(item.Comments) > 0 {
		sep := commentSepStyle.Render(strings.Repeat("─", width))
		lines = append(lines, "", sep,
			commentSepStyle.Render(fmt.Sprintf(" %d comment(s) — newest first", len(item.Comments))),
			sep,
		)

		for _, c := range item.Comments {
			header := commentAuthorStyle.Render(c.Author) + "  " +
				commentAgeStyle.Render(humanDuration(time.Since(c.CreatedAt))+" ago")
			lines = append(lines, "", header)

			// word-wrap body to panel width
			for _, bodyLine := range wrapText(c.Body, width) {
				lines = append(lines, commentBodyStyle.Render(bodyLine))
			}
		}
	}

	return lines
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

// wrapText breaks s into lines of at most maxWidth runes.
func wrapText(s string, maxWidth int) []string {
	if maxWidth < 1 {
		maxWidth = 1
	}
	var lines []string
	for _, paragraph := range strings.Split(s, "\n") {
		words := strings.Fields(paragraph)
		if len(words) == 0 {
			lines = append(lines, "")
			continue
		}
		current := ""
		for _, word := range words {
			if current == "" {
				current = word
			} else if len([]rune(current))+1+len([]rune(word)) <= maxWidth {
				current += " " + word
			} else {
				lines = append(lines, current)
				current = word
			}
		}
		if current != "" {
			lines = append(lines, current)
		}
	}
	return lines
}
