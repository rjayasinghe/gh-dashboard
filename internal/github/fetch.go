package github

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

const searchQuery = `
query($query: String!, $first: Int!, $after: String) {
  search(query: $query, type: ISSUE, first: $first, after: $after) {
    nodes {
      __typename
      ... on PullRequest {
        number
        title
        url
        state
        isDraft
        createdAt
        updatedAt
        author { login }
        labels(first: 10) { nodes { name } }
        repository { nameWithOwner }
        reviews(last: 10) { nodes { state } }
        comments(last: 50) { nodes { author { login } body createdAt } }
      }
      ... on Issue {
        number
        title
        url
        state
        createdAt
        updatedAt
        author { login }
        labels(first: 10) { nodes { name } }
        repository { nameWithOwner }
        comments(last: 50) { nodes { author { login } body createdAt } }
      }
    }
    pageInfo { hasNextPage endCursor }
  }
}`

// --- raw GQL response types ---

type gqlSearchResponse struct {
	Search struct {
		Nodes    []json.RawMessage
		PageInfo struct {
			HasNextPage bool
			EndCursor   string
		}
	}
}

type gqlPR struct {
	Typename  string `json:"__typename"`
	Number    int
	Title     string
	URL       string
	State     string
	IsDraft   bool
	CreatedAt time.Time
	UpdatedAt time.Time
	Author    struct{ Login string }
	Labels    struct{ Nodes []struct{ Name string } }
	Repository struct{ NameWithOwner string }
	Reviews   struct{ Nodes []struct{ State string } }
	Comments  struct{ Nodes []gqlComment }
}

type gqlIssue struct {
	Typename  string `json:"__typename"`
	Number    int
	Title     string
	URL       string
	State     string
	CreatedAt time.Time
	UpdatedAt time.Time
	Author    struct{ Login string }
	Labels    struct{ Nodes []struct{ Name string } }
	Repository struct{ NameWithOwner string }
	Comments  struct{ Nodes []gqlComment }
}

type gqlComment struct {
	Author    struct{ Login string }
	Body      string
	CreatedAt time.Time
}

type gqlTypename struct {
	Typename string `json:"__typename"`
}

// --- helpers ---

func deriveReviewStatus(nodes []struct{ State string }) string {
	for _, r := range nodes {
		if r.State == "CHANGES_REQUESTED" {
			return "changes_requested"
		}
	}
	for _, r := range nodes {
		if r.State == "APPROVED" {
			return "approved"
		}
	}
	return "pending"
}

func labelsFrom(nodes []struct{ Name string }) []string {
	labels := make([]string, 0, len(nodes))
	for _, n := range nodes {
		labels = append(labels, n.Name)
	}
	return labels
}

// commentsNewestFirst converts GQL comment nodes (oldest-first from the API)
// into a []Comment slice reversed so index 0 is the newest comment.
func commentsNewestFirst(nodes []gqlComment) []Comment {
	out := make([]Comment, len(nodes))
	for i, n := range nodes {
		out[len(nodes)-1-i] = Comment{
			Author:    n.Author.Login,
			Body:      n.Body,
			CreatedAt: n.CreatedAt,
		}
	}
	return out
}

// --- per-section fetch with pagination ---

func fetchSection(ctx context.Context, client HostClient, gqlSearchStr string, section Section) ([]Item, error) {
	var items []Item
	var cursor *string

	for {
		vars := map[string]interface{}{
			"query": gqlSearchStr,
			"first": 50,
		}
		if cursor != nil {
			vars["after"] = *cursor
		}

		var resp gqlSearchResponse
		if err := client.GQL.DoWithContext(ctx, searchQuery, vars, &resp); err != nil {
			return items, fmt.Errorf("host %s: %w", client.Host, err)
		}

		for _, raw := range resp.Search.Nodes {
			var t gqlTypename
			if err := json.Unmarshal(raw, &t); err != nil {
				continue
			}
			switch t.Typename {
			case "PullRequest":
				var pr gqlPR
				if err := json.Unmarshal(raw, &pr); err == nil {
					items = append(items, Item{
						Number:       pr.Number,
						Title:        pr.Title,
						URL:          pr.URL,
						Host:         client.Host,
						Repo:         pr.Repository.NameWithOwner,
						State:        pr.State,
						IsDraft:      pr.IsDraft,
						CreatedAt:    pr.CreatedAt,
						UpdatedAt:    pr.UpdatedAt,
						Author:       pr.Author.Login,
						Labels:       labelsFrom(pr.Labels.Nodes),
						Section:      section,
						ReviewStatus: deriveReviewStatus(pr.Reviews.Nodes),
						Comments:     commentsNewestFirst(pr.Comments.Nodes),
					})
				}
			case "Issue":
				var issue gqlIssue
				if err := json.Unmarshal(raw, &issue); err == nil {
					items = append(items, Item{
						Number:    issue.Number,
						Title:     issue.Title,
						URL:       issue.URL,
						Host:      client.Host,
						Repo:      issue.Repository.NameWithOwner,
						State:     issue.State,
						CreatedAt: issue.CreatedAt,
						UpdatedAt: issue.UpdatedAt,
						Author:    issue.Author.Login,
						Labels:    labelsFrom(issue.Labels.Nodes),
						Section:   section,
						Comments:  commentsNewestFirst(issue.Comments.Nodes),
					})
				}
			}
		}

		if !resp.Search.PageInfo.HasNextPage {
			break
		}
		c := resp.Search.PageInfo.EndCursor
		cursor = &c
	}

	return items, nil
}

// --- per-host fetch ---

var sectionQueries = []struct {
	query   string
	section Section
}{
	{`is:pr is:open author:@me archived:false`, SectionMyPRs},
	{`is:pr is:open review-requested:@me archived:false`, SectionReviewNeeded},
	{`is:issue is:open assignee:@me archived:false`, SectionMyIssues},
}

func fetchHost(ctx context.Context, client HostClient) FetchResult {
	var items []Item
	for _, sq := range sectionQueries {
		fetched, err := fetchSection(ctx, client, sq.query, sq.section)
		if err != nil {
			return FetchResult{Host: client.Host, Err: err}
		}
		items = append(items, fetched...)
	}
	return FetchResult{Host: client.Host, Items: items}
}

// FetchAll fetches all three sections across all hosts concurrently.
// Per-host errors are captured inside each FetchResult.Err — the function
// itself never returns an error, enabling graceful degradation.
func FetchAll(ctx context.Context, clients []HostClient) []FetchResult {
	results := make([]FetchResult, len(clients))
	var wg sync.WaitGroup

	for i, hc := range clients {
		wg.Add(1)
		go func(idx int, client HostClient) {
			defer wg.Done()
			results[idx] = fetchHost(ctx, client)
		}(i, hc)
	}

	wg.Wait()
	return results
}
