package github

import (
	"testing"
	"time"
)

// --- deriveReviewStatus ---

func TestDeriveReviewStatus_ChangesRequested(t *testing.T) {
	nodes := []struct{ State string }{
		{State: "APPROVED"},
		{State: "CHANGES_REQUESTED"},
	}
	if got := deriveReviewStatus(nodes); got != "changes_requested" {
		t.Errorf("expected changes_requested, got %s", got)
	}
}

func TestDeriveReviewStatus_Approved(t *testing.T) {
	nodes := []struct{ State string }{
		{State: "APPROVED"},
		{State: "COMMENTED"},
	}
	if got := deriveReviewStatus(nodes); got != "approved" {
		t.Errorf("expected approved, got %s", got)
	}
}

func TestDeriveReviewStatus_Pending(t *testing.T) {
	nodes := []struct{ State string }{}
	if got := deriveReviewStatus(nodes); got != "pending" {
		t.Errorf("expected pending, got %s", got)
	}
}

func TestDeriveReviewStatus_ChangesRequestedTakesPrecedenceOverApproved(t *testing.T) {
	nodes := []struct{ State string }{
		{State: "CHANGES_REQUESTED"},
		{State: "APPROVED"},
		{State: "CHANGES_REQUESTED"},
	}
	if got := deriveReviewStatus(nodes); got != "changes_requested" {
		t.Errorf("expected changes_requested, got %s", got)
	}
}

// --- commentsNewestFirst ---

func TestCommentsNewestFirst_Order(t *testing.T) {
	t1 := time.Now().Add(-3 * time.Hour)
	t2 := time.Now().Add(-2 * time.Hour)
	t3 := time.Now().Add(-1 * time.Hour)

	nodes := []gqlComment{
		{Author: struct{ Login string }{"alice"}, Body: "first", CreatedAt: t1},
		{Author: struct{ Login string }{"bob"}, Body: "second", CreatedAt: t2},
		{Author: struct{ Login string }{"carol"}, Body: "third", CreatedAt: t3},
	}

	got := commentsNewestFirst(nodes)

	if len(got) != 3 {
		t.Fatalf("expected 3 comments, got %d", len(got))
	}
	if got[0].Author != "carol" {
		t.Errorf("expected newest first (carol), got %s", got[0].Author)
	}
	if got[1].Author != "bob" {
		t.Errorf("expected bob second, got %s", got[1].Author)
	}
	if got[2].Author != "alice" {
		t.Errorf("expected alice last, got %s", got[2].Author)
	}
}

func TestCommentsNewestFirst_Empty(t *testing.T) {
	got := commentsNewestFirst([]gqlComment{})
	if len(got) != 0 {
		t.Errorf("expected empty slice, got %d", len(got))
	}
}

func TestCommentsNewestFirst_Single(t *testing.T) {
	nodes := []gqlComment{
		{Author: struct{ Login string }{"alice"}, Body: "only", CreatedAt: time.Now()},
	}
	got := commentsNewestFirst(nodes)
	if len(got) != 1 || got[0].Author != "alice" {
		t.Errorf("unexpected result for single comment: %+v", got)
	}
}

// --- labelsFrom ---

func TestLabelsFrom(t *testing.T) {
	nodes := []struct{ Name string }{{"bug"}, {"enhancement"}, {"good first issue"}}
	got := labelsFrom(nodes)
	if len(got) != 3 || got[0] != "bug" || got[1] != "enhancement" || got[2] != "good first issue" {
		t.Errorf("unexpected labels: %v", got)
	}
}

func TestLabelsFrom_Empty(t *testing.T) {
	got := labelsFrom([]struct{ Name string }{})
	if len(got) != 0 {
		t.Errorf("expected empty, got %v", got)
	}
}
