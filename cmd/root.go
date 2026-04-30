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
	rootCmd.Flags().Bool("debug", false, "Write debug log to debug.log")
	rootCmd.Flags().String("config", config.DefaultPath, "Path to config file")
}

func run(cmd *cobra.Command, args []string) error {
	interval, _ := cmd.Flags().GetDuration("interval")
	debug, _ := cmd.Flags().GetBool("debug")
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

	opts := []tea.ProgramOption{tea.WithAltScreen(), tea.WithMouseCellMotion()}
	if debug {
		if f, err := tea.LogToFile("debug.log", "debug"); err == nil {
			defer f.Close()
		}
	}

	p := tea.NewProgram(m, opts...)
	_, err = p.Run()
	return err
}
