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

	// Shown on the right of the tab bar; compare with: tmux display-message -p '#{pane_width}x#{pane_height}'
	terminalDimsStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("244")).
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

	dimItemStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("239"))

	itemSubtitleStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("240"))

	listPRNumberStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("243"))

	listPRRepoStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("240"))

	listRowAltStyle = lipgloss.NewStyle().
				Background(lipgloss.Color("235"))

	hostGroupHeaderStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("245")).
				Background(lipgloss.Color("237")).
				Padding(0, 1)

	// Second row under a selected title: clear selection background so the
	// terminal does not paint two full-width highlight bands (bg bleed).
	selectedItemSubtitleStyle = itemSubtitleStyle.Background(lipgloss.NoColor{})

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
