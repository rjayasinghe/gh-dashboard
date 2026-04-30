package config

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/BurntSushi/toml"
)

const DefaultPath = "~/.config/dev-dashboard/config.toml"

type Config struct {
	GitHub GitHubConfig `toml:"github"`
}

type GitHubConfig struct {
	Hosts []string `toml:"hosts"`
}

// Load reads the config file at path, expanding ~ to the home directory.
// Returns an error if the file is missing or malformed.
func Load(path string) (*Config, error) {
	expanded, err := expandHome(path)
	if err != nil {
		return nil, err
	}

	data, err := os.ReadFile(expanded)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("config file not found at %s\n\nCreate it with:\n\n%s", expanded, ExampleConfig())
		}
		return nil, fmt.Errorf("reading config: %w", err)
	}

	var cfg Config
	if err := toml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("parsing config at %s: %w", expanded, err)
	}

	if len(cfg.GitHub.Hosts) == 0 {
		return nil, fmt.Errorf("config at %s has no hosts listed under [github]", expanded)
	}

	return &cfg, nil
}

func ExampleConfig() string {
	return `[github]
hosts = [
  "github.com",
  # "github.mycompany.com",
]`
}

func expandHome(path string) (string, error) {
	if len(path) == 0 || path[0] != '~' {
		return path, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolving home directory: %w", err)
	}
	return filepath.Join(home, path[1:]), nil
}
