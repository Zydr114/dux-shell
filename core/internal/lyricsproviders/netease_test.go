package lyricsproviders

import (
	"context"
	"crypto/aes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

type netEaseTestTransport func(*http.Request) (*http.Response, error)

func (f netEaseTestTransport) RoundTrip(req *http.Request) (*http.Response, error) { return f(req) }

func netEaseTestResponse(body string) *http.Response {
	return &http.Response{StatusCode: http.StatusOK, Body: io.NopCloser(strings.NewReader(body)), Header: make(http.Header)}
}

const netEaseTestSong = `{"id":1,"name":"Song","dt":120000,"ar":[{"name":"Artist"}],"al":{"name":"Album"}}`

func netEaseTestClient(t *testing.T, search string, lyrics []string) (*Client, *int) {
	t.Helper()
	requests := 0
	return &Client{http: &http.Client{Transport: netEaseTestTransport(func(req *http.Request) (*http.Response, error) {
		if req.Method != http.MethodPost || req.URL.Host != "music.163.com" || req.Header.Get("Referer") != netEaseBase+"/" {
			t.Errorf("unexpected provider request: %s %s %+v", req.Method, req.URL, req.Header)
		}
		if req.URL.Path == "/api/cloudsearch/pc" {
			data, _ := io.ReadAll(req.Body)
			form, _ := url.ParseQuery(string(data))
			if form.Get("s") != "Song Artist" && form.Get("s") != "Song" || form.Get("type") != "1" || form.Get("limit") != "20" {
				t.Errorf("unexpected search form: %v", form)
			}
			return netEaseTestResponse(search), nil
		}
		if req.URL.Path != "/eapi/song/lyric/v1" {
			t.Errorf("unexpected lyric URL: %s", req.URL)
		}
		netEaseCheckLyricRequest(t, req)
		if requests >= len(lyrics) {
			t.Fatal("provider exceeded expected candidate attempts")
		}
		body := lyrics[requests]
		requests++
		return netEaseTestResponse(body), nil
	})}}, &requests
}

func netEaseCheckLyricRequest(t *testing.T, req *http.Request) {
	t.Helper()
	body, _ := io.ReadAll(req.Body)
	form, err := url.ParseQuery(string(body))
	if err != nil {
		t.Fatal(err)
	}
	encrypted, err := hex.DecodeString(form.Get("params"))
	if err != nil || len(encrypted) == 0 || len(encrypted)%aes.BlockSize != 0 {
		t.Fatalf("invalid eapi request: %s, %v", body, err)
	}
	block, _ := aes.NewCipher([]byte("e82ckenh8dichen8"))
	plain := make([]byte, len(encrypted))
	for i := 0; i < len(encrypted); i += aes.BlockSize {
		block.Decrypt(plain[i:i+aes.BlockSize], encrypted[i:i+aes.BlockSize])
	}
	parts := strings.Split(string(plain), "-36cd479b6b5-")
	if len(parts) != 3 || parts[0] != "/api/song/lyric/v1" {
		t.Fatalf("invalid eapi envelope: %q", plain)
	}
	var payload map[string]any
	if err := json.Unmarshal([]byte(parts[1]), &payload); err != nil {
		t.Fatal(err)
	}
	if payload["id"] == "" || payload["cp"] != false || payload["yv"] != float64(0) || payload["lv"] != float64(0) {
		t.Fatalf("word lyrics were not requested: %v", payload)
	}
}

func TestNetEasePrefersWordLyricsAcrossCandidates(t *testing.T) {
	search := `{"code":200,"result":{"songCount":2,"songs":[` + netEaseTestSong + `,` + strings.Replace(netEaseTestSong, `"id":1`, `"id":2`, 1) + `]}}`
	client, requests := netEaseTestClient(t, search, []string{
		`{"code":200,"lrc":{"lyric":"[00:01.00]Line fallback"}}`,
		`{"code":200,"yrc":{"lyric":"[1000,500](1000,200,0)Word (1200,300,0)timing"}}`,
	})
	lyrics, err := client.fetchNetEase(context.Background(), corelyrics.Request{Title: "Song", Artist: "Artist", Duration: 120 * time.Second})
	if err != nil || *requests != 2 || !netEaseHasWords(lyrics) || lyrics.Plain != "Word timing" || lyrics.Title != "Song" || lyrics.Artist != "Artist" || lyrics.Album != "Album" || lyrics.DurationMS != 120000 {
		t.Fatalf("unexpected lyrics: %+v, requests=%d, err=%v", lyrics, *requests, err)
	}
}

func TestNetEaseFallbacksAndMisses(t *testing.T) {
	for _, tc := range []struct {
		name, search, response, want string
	}{
		{"lrc only", "", `{"code":200,"lrc":{"lyric":"{\"t\":0,\"c\":[{\"tx\":\"Credit\"}]}\n[00:01.00]Fallback"}}`, "Fallback"},
		{"broken yrc valid lrc", "", `{"code":200,"yrc":{"lyric":"malformed"},"lrc":{"lyric":"[00:01.00]Fallback"}}`, "Fallback"},
		{"blank yrc valid lrc", "", `{"code":200,"yrc":{"lyric":"[1000,100](1000,100,0)   "},"lrc":{"lyric":"[00:01.00]Fallback"}}`, "Fallback"},
		{"uncollected", "", `{"code":200,"uncollected":true}`, ""},
		{"empty lyric", "", `{"code":200,"lrc":{"lyric":""},"yrc":{"lyric":""}}`, ""},
		{"blank timed lrc", "", `{"code":200,"lrc":{"lyric":"[00:01.00]   "}}`, ""},
		{"no search matches", `{"code":200,"result":{"songCount":0}}`, "", ""},
		{"wrong artist", `{"code":200,"result":{"songs":[` + strings.Replace(netEaseTestSong, "Artist", "Unrelated", 1) + `]}}`, "", ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			search := tc.search
			if search == "" {
				search = `{"code":200,"result":{"songs":[` + netEaseTestSong + `]}}`
			}
			var responses []string
			if tc.response != "" {
				responses = []string{tc.response}
			}
			client, requests := netEaseTestClient(t, search, responses)
			lyrics, err := client.fetchNetEase(context.Background(), corelyrics.Request{Title: "Song", Artist: "Artist"})
			if err != nil || lyrics.Plain != tc.want || *requests != len(responses) {
				t.Fatalf("unexpected fallback/miss: %+v, %v, requests=%d", lyrics, err, *requests)
			}
		})
	}
}

func TestNetEaseMalformedResponsesAreErrors(t *testing.T) {
	for _, tc := range []struct{ name, search, response string }{
		{"search code", `{"code":500}`, ""},
		{"search missing result", `{"code":200}`, ""},
		{"search malformed result", `{"code":200,"result":{}}`, ""},
		{"search missing songs", `{"code":200,"result":{"songCount":1}}`, ""},
		{"search malformed song", `{"code":200,"result":{"songs":[{"id":1,"name":"Song"}]}}`, ""},
		{"search invalid json", `{`, ""},
		{"lyric code", "", `{"code":400}`},
		{"lyric missing fields", "", `{"code":200}`},
		{"lyric yrc missing text", "", `{"code":200,"yrc":{}}`},
		{"lyric lrc missing text", "", `{"code":200,"lrc":{}}`},
		{"lyric missing code", "", `{"lrc":{"lyric":""}}`},
		{"lyric invalid json", "", `{`},
		{"lyric broken yrc", "", `{"code":200,"yrc":{"lyric":"[1000,100](1000,-1,0)bad"}}`},
		{"lyric broken lrc", "", `{"code":200,"lrc":{"lyric":"upstream error text"}}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			search := tc.search
			if search == "" {
				search = `{"code":200,"result":{"songs":[` + netEaseTestSong + `]}}`
			}
			client, _ := netEaseTestClient(t, search, []string{tc.response})
			if lyrics, err := client.fetchNetEase(context.Background(), corelyrics.Request{Title: "Song", Artist: "Artist"}); err == nil {
				t.Fatalf("malformed response became a cacheable result: %+v", lyrics)
			}
		})
	}
}

func TestNetEaseKeepsLRCWhenLaterCandidateFails(t *testing.T) {
	search := `{"code":200,"result":{"songs":[` + netEaseTestSong + `,` + strings.Replace(netEaseTestSong, `"id":1`, `"id":2`, 1) + `]}}`
	client, _ := netEaseTestClient(t, search, []string{`{"code":200,"lrc":{"lyric":"[00:01.00]Fallback"}}`, `{"code":500}`})
	lyrics, err := client.fetchNetEase(context.Background(), corelyrics.Request{Title: "Song", Artist: "Artist"})
	if err != nil || lyrics.Plain != "Fallback" {
		t.Fatalf("valid fallback lost: %+v, %v", lyrics, err)
	}
}

func TestNetEaseBlankCandidatesDoNotWin(t *testing.T) {
	search := `{"code":200,"result":{"songs":[` + netEaseTestSong + `,` + strings.Replace(netEaseTestSong, `"id":1`, `"id":2`, 1) + `]}}`
	client, requests := netEaseTestClient(t, search, []string{
		`{"code":200,"yrc":{"lyric":"[1000,100](1000,100,0)   "},"lrc":{"lyric":"[00:01.00]   "}}`,
		`{"code":200,"lrc":{"lyric":"[00:01.00]Content"}}`,
	})
	lyrics, err := client.fetchNetEase(context.Background(), corelyrics.Request{Title: "Song", Artist: "Artist"})
	if err != nil || *requests != 2 || lyrics.Plain != "Content" {
		t.Fatalf("blank candidate won: %+v, %v, requests=%d", lyrics, err, *requests)
	}
}

func TestNetEaseTitleSearchFallbackKeepsMetadataMatching(t *testing.T) {
	queries := []string{}
	client := &Client{http: &http.Client{Transport: netEaseTestTransport(func(req *http.Request) (*http.Response, error) {
		if req.URL.Path != "/api/cloudsearch/pc" {
			return netEaseTestResponse(`{"code":200,"lrc":{"lyric":"[00:01.00]Found"}}`), nil
		}
		data, _ := io.ReadAll(req.Body)
		form, _ := url.ParseQuery(string(data))
		queries = append(queries, form.Get("s"))
		if len(queries) == 1 {
			return netEaseTestResponse(`{"code":200,"result":{"songCount":0}}`), nil
		}
		return netEaseTestResponse(`{"code":200,"result":{"songs":[` + strings.Replace(netEaseTestSong, "Artist", "Unrelated", 1) + `,` + netEaseTestSong + `]}}`), nil
	})}}
	lyrics, err := client.fetchNetEase(context.Background(), corelyrics.Request{Title: "Song", Artist: "Artist"})
	if err != nil || lyrics.Plain != "Found" || lyrics.Artist != "Artist" || strings.Join(queries, ";") != "Song Artist;Song" {
		t.Fatalf("title-only fallback failed: %+v, %v, queries=%v", lyrics, err, queries)
	}
}

func TestNetEaseNetworkAndCancellation(t *testing.T) {
	for _, failLyric := range []bool{false, true} {
		for _, failure := range []error{context.Canceled, errors.New("offline")} {
			t.Run(fmt.Sprintf("lyric=%v/%v", failLyric, failure), func(t *testing.T) {
				client := &Client{http: &http.Client{Transport: netEaseTestTransport(func(req *http.Request) (*http.Response, error) {
					if failLyric && req.URL.Path == "/api/cloudsearch/pc" {
						return netEaseTestResponse(`{"code":200,"result":{"songs":[` + netEaseTestSong + `]}}`), nil
					}
					return nil, failure
				})}}
				if _, err := client.fetchNetEase(context.Background(), corelyrics.Request{Title: "Song", Artist: "Artist"}); !errors.Is(err, failure) {
					t.Fatalf("transport error lost: %v", err)
				}
			})
		}
	}
}

func TestNetEaseEAPIWireVector(t *testing.T) {
	body, err := netEaseEAPI("/api/song/lyric/v1", map[string]string{"id": "123"})
	if err != nil {
		t.Fatal(err)
	}
	form, _ := url.ParseQuery(string(body))
	const expected = "04AE33D34A93FE3EC22DA8FA305D290AB337D0FE5F36D211DE0D338CC6AA89D0E132480CA4AAA841CABC849C58C2067F7ECBE33F2693AF387545E1032268EE6CDB7427D62D934CBF1EECE7247E77344B1D4A3034649D3C913D992D368E2BDA84"
	if form.Get("params") != expected {
		t.Fatalf("eapi wire format changed: %q", form.Get("params"))
	}
}
