package lyrics

import (
	"bytes"
	"context"
	"encoding/json"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/duxlabs-dev/dux-go/ipc"
	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
	"github.com/duxlabs-dev/dux-shell/core/internal/lyricsproviders"
)

type lyricResponseConn struct {
	net.Conn
	written bytes.Buffer
}

func (c *lyricResponseConn) Write(data []byte) (int, error)   { return c.written.Write(data) }
func (c *lyricResponseConn) SetWriteDeadline(time.Time) error { return nil }

func getLyricsResponse(t *testing.T, params map[string]any) corelyrics.Result {
	t.Helper()
	conn := &lyricResponseConn{}
	data, err := json.Marshal(ipc.Request{ID: 1, Method: "lyrics.get", Params: params})
	if err != nil {
		t.Fatal(err)
	}
	var request ipc.Request
	if err := json.Unmarshal(data, &request); err != nil {
		t.Fatal(err)
	}
	HandleRequest(ipc.NewConnWriter(conn), request)
	var response struct {
		Error  string            `json:"error"`
		Result corelyrics.Result `json:"result"`
	}
	if err := json.Unmarshal(conn.written.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if response.Error != "" {
		t.Fatal(response.Error)
	}
	return response.Result
}

func TestGetPreservesProviderSelectionAndNetworkConsent(t *testing.T) {
	previous := client
	t.Cleanup(func() { client = previous })
	calls := 0
	client = corelyrics.New(corelyrics.Options{
		CacheDir: t.TempDir(),
		Resolve: func(provider corelyrics.Provider) (corelyrics.Source, bool) {
			if provider != lyricsproviders.NetEase && provider != lyricsproviders.QQMusic {
				return corelyrics.Source{}, false
			}
			return corelyrics.Source{WordSync: true, Fetch: func(_ context.Context, request corelyrics.Request) (*corelyrics.Lyrics, error) {
				calls++
				if request.Duration != 180*time.Second || request.Title != "Song" || request.Artist != "Singer" {
					t.Errorf("provider metadata changed: %+v", request)
				}
				return &corelyrics.Lyrics{Synced: []corelyrics.Line{{Start: 1, Text: "sing", Words: []corelyrics.Word{{Start: 1, End: 2, Text: "sing"}}}}}, nil
			}}, true
		},
	})
	params := map[string]any{"title": "Song", "artist": "Singer", "duration": 180, "providers": []string{"netease"}}
	if result := getLyricsResponse(t, params); result.Found || calls != 0 {
		t.Fatalf("cache-only request fetched lyrics: %+v, calls %d", result, calls)
	}
	params["allowNetwork"] = true
	if result := getLyricsResponse(t, params); !result.Found || result.Source != lyricsproviders.NetEase || len(result.Synced[0].Words) != 1 || calls != 1 {
		t.Fatalf("explicit provider lost: %+v, calls %d", result, calls)
	}
	params["allowNetwork"] = false
	if result := getLyricsResponse(t, params); !result.Cached || !result.Found || calls != 1 {
		t.Fatalf("lyrics were not reused from cache: %+v, calls %d", result, calls)
	}
	params["providers"] = []string{"qqmusic"}
	if result := getLyricsResponse(t, params); result.Found || calls != 1 {
		t.Fatalf("disabled provider cache leaked: %+v, calls %d", result, calls)
	}
	params["providers"] = []string{}
	params["allowNetwork"] = true
	if result := getLyricsResponse(t, params); result.Found || calls != 1 {
		t.Fatalf("empty provider list fetched lyrics: %+v, calls %d", result, calls)
	}
}

func TestGetCleansFreshAndCachedLyricsBeforeResponding(t *testing.T) {
	previous := client
	t.Cleanup(func() { client = previous })
	client = corelyrics.New(corelyrics.Options{
		CacheDir: t.TempDir(),
		Resolve: func(provider corelyrics.Provider) (corelyrics.Source, bool) {
			return corelyrics.Source{Fetch: func(context.Context, corelyrics.Request) (*corelyrics.Lyrics, error) {
				return &corelyrics.Lyrics{Plain: "\r\n sing \n\n", Synced: []corelyrics.Line{
					{Start: 1, Text: " sing ", Words: []corelyrics.Word{{Start: 1, End: 2, Text: " sing "}}},
					{Start: 3, Text: " "},
				}}, nil
			}}, true
		},
	})
	params := map[string]any{"title": "Song", "artist": "Singer", "providers": []string{"netease"}, "allowNetwork": true}
	for range 2 {
		result := getLyricsResponse(t, params)
		if result.Plain != "sing" || len(result.Synced) != 1 || result.Synced[0].Text != "sing" || result.Synced[0].Words[0].Text != "sing" || result.Synced[0].End != 2 {
			t.Fatalf("unclean IPC result: %+v", result)
		}
		params["allowNetwork"] = false
	}
}

func TestGetCleansSidecarLyricsWithoutNetwork(t *testing.T) {
	previous := client
	t.Cleanup(func() { client = previous })
	client = corelyrics.New(corelyrics.Options{CacheDir: t.TempDir()})
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "track.lrc"), []byte("[00:01.00] sing \r\n[00:03.00] \r\n[00:05.00] again\r\n"), 0600); err != nil {
		t.Fatal(err)
	}
	fileURL := (&url.URL{Scheme: "file", Path: filepath.Join(dir, "track.flac")}).String()
	result := getLyricsResponse(t, map[string]any{"fileUrl": fileURL, "providers": []string{}})
	if !result.Found || len(result.Synced) != 2 || result.Synced[0].Text != "sing" || result.Synced[0].End != 3 || result.Synced[1].Start != 5 {
		t.Fatalf("sidecar cleanup lost text or silence: %+v", result)
	}
}
