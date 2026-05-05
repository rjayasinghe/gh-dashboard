package cmd

import (
	"fmt"
	"os"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/spf13/cobra"
	"github.com/i540498/dev-dashboard/internal/config"
	gh "github.com/i540498/dev-dashboard/internal/github"
	"github.com/i540498/dev-dashboard/internal/ui"
)


var rootCmd = &cobra.Command{
	Use:   "dev-dashboard",
	Short: "Terminal dashboard for GitHub PRs and issues",
	RunE:  run,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.Flags().Duration("interval", 5*time.Minute, "Auto-refresh interval")
	rootCmd.Flags().Bool("mouse", false, "Enable mouse (wheel, clicks); off by default to avoid terminal reflow glitches")
	rootCmd.Flags().String("config", config.DefaultPath, "Path to config file")
}

func run(cmd *cobra.Command, args []string) error {
	interval, _ := cmd.Flags().GetDuration("interval")
	enableMouse, _ := cmd.Flags().GetBool("mouse")
	cfgPath, _ := cmd.Flags().GetString("config")

	cfg, err := config.Load(cfgPath)
	if err != nil {
		return err
	}

	clients, err := gh.NewHostClients(cfg.GitHub.Hosts)
	if err != nil {
		return err
	}

	m := ui.New(clients, interval)

	opts := []tea.ProgramOption{tea.WithAltScreen()}
	if enableMouse {
		opts = append(opts, tea.WithMouseCellMotion())
	}

	p := tea.NewProgram(m, opts...)
	_, err = p.Run()
	return err
}
