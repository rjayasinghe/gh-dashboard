package github

import "time"

type Section int

const (
	SectionMyPRs        Section = iota
	SectionReviewNeeded
	SectionMyIssues
)

func (s Section) Label() string {
	switch s {
	case SectionMyPRs:
		return "▼ My PRs"
	case SectionReviewNeeded:
		return "▼ Review Needed"
	case SectionMyIssues:
		return "▼ My Issues"
	}
	return ""
}

type Comment struct {
	Author    string
	Body      string
	CreatedAt time.Time
}

type Item struct {
	ID      int
	Number  int
	Title   string
	URL     string
	Host    string
	Repo    string // "owner/name"
	State   string
	IsDraft bool

	CreatedAt time.Time
	UpdatedAt time.Time
	Author    string
	Labels    []string
	Section   Section
	Comments  []Comment // newest first

	// PR-specific
	ReviewStatus string // "approved" | "changes_requested" | "pending" | ""
}

type FetchResult struct {
	Host  string
	Items []Item
	Err   error
}
