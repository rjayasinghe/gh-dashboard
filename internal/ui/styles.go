package ui

import "github.com/charmbracelet/lipgloss"

var (
	// tabs
	activeTabStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("230")).
			Background(lipgloss.Color("62")).
			Padding(0, 2)

	inactiveTabStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("244")).
				Background(lipgloss.Color("236")).
				Padding(0, 2)

	tabBarStyle = lipgloss.NewStyle().
			Background(lipgloss.Color("236"))

	// list panel
	listPanelStyle = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder(), false, true, false, false).
			BorderForeground(lipgloss.Color("240"))

	selectedItemStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("230")).
				Background(lipgloss.Color("62"))

	normalItemStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("252"))

	itemSubtitleStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("240"))

	draftStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("214"))

	// detail panel
	detailPanelStyle = lipgloss.NewStyle().Padding(0, 1)

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

	// status bar
	statusBarStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("240")).
			Background(lipgloss.Color("235")).
			Padding(0, 1)
)
