package lyricsproviders

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

type qqRoundTrip func(*http.Request) (*http.Response, error)

func (f qqRoundTrip) RoundTrip(req *http.Request) (*http.Response, error) { return f(req) }
func qqReply(s string) *http.Response {
	return &http.Response{StatusCode: 200, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(s))}
}

func TestQQBusinessErrorsExposeCodesWithoutReturningLyrics(t *testing.T) {
	for _, tc := range []struct{ body, message string }{
		{`{}`, "omitted top-level code"},
		{`{"code":-1002}`, "top-level code -1002"},
		{`{"code":0,"req_0":{}}`, "omitted request code"},
		{`{"code":0,"req_0":{"code":2001,"data":{"lyric":"private text"}}}`, "request code 2001"},
		{`{"code":0,"req_0":{"code":0,"data":null}}`, "omitted request data"},
	} {
		c := &Client{http: &http.Client{Transport: qqRoundTrip(func(*http.Request) (*http.Response, error) {
			return qqReply(tc.body), nil
		})}}
		var data any
		err := c.qqCall(context.Background(), "test", "test", nil, &data)
		if err == nil || !strings.Contains(err.Error(), tc.message) || strings.Contains(err.Error(), "private text") || data != nil {
			t.Fatalf("response %s: data %v, error %v", tc.body, data, err)
		}
	}
}

func TestQQSearchFallbackAndQRC(t *testing.T) {
	calls := 0
	c := &Client{http: &http.Client{Transport: qqRoundTrip(func(r *http.Request) (*http.Response, error) {
		calls++
		var payload struct {
			Request struct {
				Method string         `json:"method"`
				Param  map[string]any `json:"param"`
			} `json:"req_0"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Fatal(err)
		}
		if payload.Request.Method == "DoSearchForQQMusicDesktop" {
			if calls == 1 {
				return qqReply(`{"code":0,"req_0":{"code":0,"data":{"body":{"song":{"list":[]}}}}}`), nil
			}
			if payload.Request.Param["query"] != "Song" {
				t.Fatalf("fallback query: %v", payload.Request.Param)
			}
			return qqReply(`{"code":0,"req_0":{"code":0,"data":{"body":{"song":{"list":[{"id":123,"title":"Song","singer":[{"name":"Artist"}],"album":{"name":"Album"},"interval":180}]}}}}}`), nil
		}
		if payload.Request.Param["songID"] != float64(123) || payload.Request.Param["qrc"] != float64(1) {
			t.Fatalf("parameters: %v", payload.Request.Param)
		}
		return qqReply(`{"code":0,"req_0":{"code":0,"data":{"qrc":1,"crypt":1,"qrc_t":1,"lyric":"` + qrcFixture + `"}}}`), nil
	})}}
	lyrics, err := c.fetchQQMusic(context.Background(), corelyrics.Request{Title: "Song", Artist: "Artist"})
	if err != nil {
		t.Fatal(err)
	}
	if calls != 3 || lyrics.Title != "Song" || len(lyrics.Synced) != 1 || lyrics.Synced[0].Words[1].End != 1.8 {
		t.Fatalf("calls %d lyrics %#v", calls, lyrics)
	}
}

func TestQQLRCFallbackAndErrors(t *testing.T) {
	for _, tc := range []struct {
		name   string
		first  string
		second string
		fail   bool
	}{
		{"missing qrc", `{"qrc":1,"crypt":1,"lyric":""}`, `{"qrc":0,"crypt":0,"lyric":"` + base64.StdEncoding.EncodeToString([]byte("[00:01.00]hello")) + `"}`, false},
		{"bad qrc", `{"qrc":1,"crypt":1,"qrc_t":1,"lyric":"broken"}`, `{"qrc":0,"crypt":0,"lyric":""}`, true},
		{"missing fields", `{}`, `{}`, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			calls := 0
			c := &Client{http: &http.Client{Transport: qqRoundTrip(func(r *http.Request) (*http.Response, error) {
				calls++
				s := tc.first
				if calls > 1 {
					s = tc.second
				}
				return qqReply(`{"code":0,"req_0":{"code":0,"data":` + s + `}}`), nil
			})}}
			result, err := c.qqLyrics(context.Background(), candidate{ID: "123"})
			if (err != nil) != tc.fail {
				t.Fatalf("result %#v error %v", result, err)
			}
			if !tc.fail && (len(result.Synced) != 1 || result.Synced[0].Text != "hello") {
				t.Fatalf("result %#v", result)
			}
		})
	}
}

func TestQQBlankLRCAndCancellation(t *testing.T) {
	text := base64.StdEncoding.EncodeToString([]byte("[00:01.00]   \n[00:02.00]"))
	qrc, crypt := 0, 0
	lyrics, err := qqDecodeLyric(qqLyricData{Lyric: &text, QRC: &qrc, Crypt: &crypt})
	if err != nil || !lyrics.Empty() {
		t.Fatalf("blank LRC: %#v, %v", lyrics, err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	calls := 0
	c := &Client{http: &http.Client{Transport: qqRoundTrip(func(r *http.Request) (*http.Response, error) {
		calls++
		if r.Header.Get("Referer") != "https://y.qq.com/" {
			t.Fatal("missing referer")
		}
		switch calls {
		case 1:
			return qqReply(`{"code":0,"req_0":{"code":0,"data":{"body":{"song":{"list":[{"id":1,"title":"Song","singer":[{"name":"Artist"}]},{"id":2,"title":"Song","singer":[{"name":"Artist"}]}]}}}}}`), nil
		case 2:
			return qqReply(`{"code":0,"req_0":{"code":0,"data":{"qrc":0,"crypt":0,"lyric":"` + base64.StdEncoding.EncodeToString([]byte("[00:01.00]hello")) + `"}}}`), nil
		default:
			cancel()
			return nil, context.Canceled
		}
	})}}
	_, err = c.fetchQQMusic(ctx, corelyrics.Request{Title: "Song", Artist: "Artist"})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected cancellation, got %v", err)
	}
}
