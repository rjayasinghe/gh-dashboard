package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/i540498/dev-dashboard/internal/config"
)

var rootCmd = &cobra.Command{
	Use:   "dev-dashboard",
	Short: "Terminal helper for the Dev Dashboard macOS app",
}

var validateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validate the config file and print the configured hosts",
	RunE:  runValidate,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.AddCommand(validateCmd)
	validateCmd.Flags().String("config", config.DefaultPath, "Path to config file")
}

func runValidate(cmd *cobra.Command, args []string) error {
	cfgPath, _ := cmd.Flags().GetString("config")

	cfg, err := config.Load(cfgPath)
	if err != nil {
		return err
	}

	fmt.Println("Config OK")
	fmt.Printf("Hosts (%d):\n", len(cfg.GitHub.Hosts))
	for _, h := range cfg.GitHub.Hosts {
		fmt.Printf("  • %s\n", h)
	}
	return nil
}
