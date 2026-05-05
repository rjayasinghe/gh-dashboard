package ui

import (
	"fmt"

	gh "github.com/i540498/dev-dashboard/internal/github"
)

// ghListItem adapts gh.Item for bubbles/list DefaultDelegate.
type ghListItem struct {
	item gh.Item
}

func (i ghListItem) FilterValue() string {
	return fmt.Sprintf("%s %s %s", i.item.Title, i.item.Host, i.item.Repo)
}

func (i ghListItem) Title() string {
	return i.item.Title
}

func (i ghListItem) Description() string {
	return i.item.Host + " · " + i.item.Repo
}
