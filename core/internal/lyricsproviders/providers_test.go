package lyricsproviders

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) { return f(req) }

func jsonResponse(status int, body string) *http.Response {
	return &http.Response{StatusCode: status, Body: io.NopCloser(strings.NewReader(body)), Header: make(http.Header)}
}

func TestRequestJSONRejectsUnusableResponses(t *testing.T) {
	for _, tc := range []struct {
		name   string
		status int
		body   string
		want   error
	}{
		{"rate limit", 429, `{}`, nil},
		{"forbidden is transient", 403, `{}`, nil},
		{"invalid JSON", 200, `<html>try again</html>`, nil},
		{"oversized JSON", 200, strings.Repeat(" ", corelyrics.MaxSourceBytes+1), corelyrics.ErrTooLarge},
	} {
		t.Run(tc.name, func(t *testing.T) {
			c := &Client{http: &http.Client{Transport: roundTripFunc(func(*http.Request) (*http.Response, error) {
				return jsonResponse(tc.status, tc.body), nil
			})}}
			var payload map[string]any
			err := c.requestJSON(context.Background(), http.MethodGet, "https://music.163.com/test", nil, nil, &payload)
			if err == nil || tc.want != nil && !errors.Is(err, tc.want) {
				t.Fatalf("requestJSON error = %v, want %v", err, tc.want)
			}
		})
	}
}

func TestRequestJSONPreservesHeadersAndCancellation(t *testing.T) {
	c := &Client{http: &http.Client{Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
		if req.Header.Get("Referer") != "https://y.qq.com/" {
			t.Error("missing provider referer")
		}
		if _, ok := req.Context().Deadline(); !ok {
			t.Error("request has no deadline")
		}
		return nil, req.Context().Err()
	})}}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	var payload any
	err := c.requestJSON(ctx, http.MethodPost, "https://u.y.qq.com/test", http.Header{"Referer": {"https://y.qq.com/"}}, []byte(`{}`), &payload)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("error = %v, want cancellation", err)
	}
}

func TestHTTPRedirectCannotLeaveProviderOrigin(t *testing.T) {
	c := New()
	original, _ := http.NewRequest(http.MethodGet, "https://music.163.com/api", nil)
	redirect, _ := http.NewRequest(http.MethodGet, "https://unrelated.example/api", nil)
	if err := c.http.CheckRedirect(redirect, []*http.Request{original}); err == nil {
		t.Fatal("cross-origin redirect accepted")
	}
	redirect, _ = http.NewRequest(http.MethodGet, "http://music.163.com/api", nil)
	if err := c.http.CheckRedirect(redirect, []*http.Request{original}); err == nil {
		t.Fatal("HTTP downgrade accepted")
	}
}
