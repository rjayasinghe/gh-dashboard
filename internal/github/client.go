package github

import (
	"fmt"

	"github.com/cli/go-gh/v2/pkg/api"
)

// HostClient pairs a hostname with its authenticated GQL client.
type HostClient struct {
	Host string
	GQL  *api.GraphQLClient
}

// NewHostClients creates one authenticated GQL client per host in the allowlist.
// Only hosts explicitly listed in the config are contacted — no automatic
// discovery of all gh-authenticated hosts.
// Hosts for which gh has no token are returned as errors (not silently skipped),
// since the user deliberately listed them.
func NewHostClients(allowedHosts []string) ([]HostClient, error) {
	if len(allowedHosts) == 0 {
		return nil, fmt.Errorf("no hosts configured")
	}

	clients := make([]HostClient, 0, len(allowedHosts))
	var errs []string

	for _, host := range allowedHosts {
		gql, err := api.NewGraphQLClient(api.ClientOptions{Host: host})
		if err != nil {
			errs = append(errs, fmt.Sprintf("%s: %v", host, err))
			continue
		}
		clients = append(clients, HostClient{Host: host, GQL: gql})
	}

	if len(clients) == 0 {
		msg := "no configured hosts could be authenticated"
		if len(errs) > 0 {
			msg += ":\n"
			for _, e := range errs {
				msg += "  • " + e + "\n"
			}
			msg += "\nRun `gh auth login --hostname <host>` for each host."
		}
		return nil, fmt.Errorf("%s", msg)
	}

	return clients, nil
}
