package ui

import "github.com/charmbracelet/lipgloss"

var (
	// layout
	listPanelStyle = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder(), false, true, false, false).
			BorderForeground(lipgloss.Color("240"))

	detailPanelStyle = lipgloss.NewStyle().Padding(0, 1)

	// header
	headerStyle = lipgloss.NewStyle().
			Background(lipgloss.Color("62")).
			Foreground(lipgloss.Color("230")).
			Padding(0, 1).
			Bold(true)

	badgeStyle = lipgloss.NewStyle().
			Background(lipgloss.Color("238")).
			Foreground(lipgloss.Color("252")).
			Padding(0, 1)

	// list
	sectionHeaderStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("99")).
				Bold(true)

	hostLabelStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("240")).
			Italic(true)

	selectedItemStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("230")).
				Background(lipgloss.Color("62")).
				Bold(true)

	normalItemStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("252"))

	draftStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("214"))

	// detail
	detailTitleStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("230"))

	detailKeyStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("240"))

	detailValueStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("252"))

	urlStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("33")).
			Underline(true)

	errorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("196"))

	// footer
	footerStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("240")).
			Background(lipgloss.Color("235")).
			Padding(0, 1)

	// comments
	commentSepStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("240"))

	commentAuthorStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("99")).
				Bold(true)

	commentAgeStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("240"))

	commentBodyStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("252"))
)
