package ui

import (
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/viewport"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
	gh "github.com/i540498/dev-dashboard/internal/github"
)

// DetailViewportContent builds full detail text (one terminal row per element) for a viewport.
func DetailViewportContent(item *gh.Item, hostErrs map[string]error, width int) string {
	if item == nil {
		return detailKeyStyle.Render("No item selected")
	}
	lines := buildDetailLines(item, hostErrs, width)
	physical := flattenPhysicalLines(lines)
	return strings.Join(physical, "\n")
}

// renderDetail renders a clipped detail view at scrollOffset (used in tests; mirrors viewport behavior).
func renderDetail(item *gh.Item, hostErrs map[string]error, scrollOffset, width, height int) string {
	if height < 1 {
		height = 1
	}
	vp := viewport.New(width, height)
	vp.MouseWheelEnabled = false
	if item == nil {
		vp.SetContent(detailKeyStyle.Render("No item selected"))
	} else {
		vp.SetContent(DetailViewportContent(item, hostErrs, width))
	}
	vp.SetYOffset(scrollOffset)
	return vp.View()
}

// flattenPhysicalLines splits each styled row on '\n' so one element ≈ one terminal row.
func flattenPhysicalLines(rows []string) []string {
	var out []string
	for _, row := range rows {
		out = append(out, strings.Split(row, "\n")...)
	}
	return out
}

func buildDetailLines(item *gh.Item, hostErrs map[string]error, width int) []string {
	age := humanDuration(time.Since(item.CreatedAt))

	// Single-line title: wrapping here multiplied physical rows and broke TUI height.
	title := ansi.Truncate(item.Title, width, "…")
	lines := []string{
		detailTitleStyle.Width(width).Render(title),
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
		urlStyle.Width(width).Render(ansi.Truncate(item.URL, width, "…")),
		"",
		detailKeyStyle.Render("[o] open in browser"),
	)

	for host, err := range hostErrs {
		msg := fmt.Sprintf("Error (%s): %s", host, err.Error())
		lines = append(lines, "", errorStyle.Width(width).Render(ansi.Truncate(msg, width, "…")))
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
			if ansi.StringWidth(header) > width {
				header = ansi.Truncate(header, width, "…")
			}
			lines = append(lines, "", header)

			// Word-wrap by terminal cells (not runes): emoji/CJK can exceed rune budget
			// and soft-wrap the terminal without '\n', breaking lipgloss height counts.
			for _, bodyLine := range wrapText(c.Body, width) {
				lines = append(lines, commentBodyStyle.Width(width).Render(bodyLine))
			}
		}
	}

	return lines
}

func kv(key, value string, width int) string {
	k := detailKeyStyle.Render(key + ": ")
	kw := lipgloss.Width(k)
	if kw >= width {
		return ansi.Truncate(k, width, "…")
	}
	availW := width - kw
	v := detailValueStyle.Width(availW).Render(value)
	line := k + v
	if ansi.StringWidth(line) > width {
		line = ansi.Truncate(line, width, "…")
	}
	return line
}

// wrapText breaks s into lines of at most maxWidth terminal cells (wide-aware).
func wrapText(s string, maxCells int) []string {
	if maxCells < 1 {
		maxCells = 1
	}
	var lines []string
	for _, paragraph := range strings.Split(s, "\n") {
		words := strings.Fields(paragraph)
		if len(words) == 0 {
			lines = append(lines, "")
			continue
		}
		var line string
		flush := func() {
			if line != "" {
				lines = append(lines, line)
				line = ""
			}
		}
		for _, word := range words {
			if ansi.StringWidth(word) > maxCells {
				flush()
				lines = append(lines, ansi.Truncate(word, maxCells, "…"))
				continue
			}
			var next string
			if line == "" {
				next = word
			} else {
				next = line + " " + word
			}
			if ansi.StringWidth(next) <= maxCells {
				line = next
			} else {
				flush()
				line = word
			}
		}
		flush()
	}
	return lines
}
