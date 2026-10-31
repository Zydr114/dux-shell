package lyricsproviders

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

const qqEndpoint = "https://u.y.qq.com/cgi-bin/musicu.fcg"

type qqEnvelope struct {
	Code    *int `json:"code"`
	Request *struct {
		Code *int            `json:"code"`
		Data json.RawMessage `json:"data"`
	} `json:"req_0"`
}

func (c *Client) qqCall(ctx context.Context, method, module string, params map[string]any, out any) error {
	body, err := json.Marshal(map[string]any{"comm": map[string]any{"ct": 19, "cv": 1859}, "req_0": map[string]any{"module": module, "method": method, "param": params}})
	if err != nil {
		return err
	}
	var res qqEnvelope
	if err = c.requestJSON(ctx, http.MethodPost, qqEndpoint, http.Header{"Content-Type": {"application/json"}, "User-Agent": {"okhttp/3.14.9"}, "Referer": {"https://y.qq.com/"}}, body, &res); err != nil {
		return err
	}
	if res.Code == nil {
		return errors.New("QQ Music response omitted top-level code")
	}
	if *res.Code != 0 {
		return fmt.Errorf("QQ Music top-level code %d", *res.Code)
	}
	if res.Request == nil || res.Request.Code == nil {
		return errors.New("QQ Music response omitted request code")
	}
	if *res.Request.Code != 0 {
		return fmt.Errorf("QQ Music request code %d", *res.Request.Code)
	}
	if len(res.Request.Data) == 0 || string(res.Request.Data) == "null" {
		return errors.New("QQ Music response omitted request data")
	}
	if err = json.Unmarshal(res.Request.Data, out); err != nil {
		return fmt.Errorf("QQ Music response: %w", err)
	}
	return nil
}

func (c *Client) qqSearch(ctx context.Context, query string) ([]candidate, error) {
	var data struct {
		Body *struct {
			Song *struct {
				List *[]struct {
					ID       int64  `json:"id"`
					MID      string `json:"mid"`
					Title    string `json:"title"`
					Name     string `json:"name"`
					Subtitle string `json:"subtitle"`
					Interval int64  `json:"interval"`
					Singer   []struct {
						Name string `json:"name"`
					} `json:"singer"`
					Album struct {
						Name string `json:"name"`
					} `json:"album"`
				} `json:"list"`
			} `json:"song"`
		} `json:"body"`
		Code *int `json:"code"`
	}
	err := c.qqCall(ctx, "DoSearchForQQMusicDesktop", "music.search.SearchCgiService", map[string]any{"query": query, "search_type": 0, "num_per_page": 20, "page_num": 1}, &data)
	if err != nil {
		return nil, err
	}
	if data.Code != nil && *data.Code != 0 {
		return nil, fmt.Errorf("QQ Music search code %d", *data.Code)
	}
	if data.Body == nil || data.Body.Song == nil || data.Body.Song.List == nil {
		return nil, errors.New("QQ Music search omitted song list")
	}
	songs := make([]candidate, 0, len(*data.Body.Song.List))
	for _, s := range *data.Body.Song.List {
		title := s.Title
		if title == "" {
			title = s.Name
		}
		if s.ID <= 0 || title == "" {
			return nil, errors.New("QQ Music search returned malformed song")
		}
		artists := make([]string, 0, len(s.Singer))
		for _, a := range s.Singer {
			if a.Name != "" {
				artists = append(artists, a.Name)
			}
		}
		var duration time.Duration
		if s.Interval > 0 && s.Interval <= 86400 {
			duration = time.Duration(s.Interval) * time.Second
		}
		songs = append(songs, candidate{ID: strconv.FormatInt(s.ID, 10), MID: s.MID, Title: title, Subtitle: s.Subtitle, Artists: artists, Album: s.Album.Name, Duration: duration})
	}
	return songs, nil
}

func (c *Client) fetchQQMusic(ctx context.Context, req corelyrics.Request) (*corelyrics.Lyrics, error) {
	songs, err := c.qqSearch(ctx, strings.TrimSpace(req.Title+" "+req.Artist))
	if err != nil {
		return nil, fmt.Errorf("QQ Music search: %w", err)
	}
	ranked := rankCandidates(req, songs)
	if len(ranked) == 0 && strings.TrimSpace(req.Artist) != "" {
		songs, err = c.qqSearch(ctx, strings.TrimSpace(req.Title))
		if err != nil {
			return nil, fmt.Errorf("QQ Music search: %w", err)
		}
		ranked = rankCandidates(req, songs)
	}
	var fallback *corelyrics.Lyrics
	var failures []error
	for _, song := range ranked {
		if err := ctx.Err(); err != nil {
			if fallback != nil && errors.Is(err, context.DeadlineExceeded) {
				return fallback, nil
			}
			return nil, err
		}
		lyrics, err := c.qqLyrics(ctx, song)
		if errors.Is(ctx.Err(), context.Canceled) {
			return nil, ctx.Err()
		}
		if err != nil {
			failures = append(failures, err)
			continue
		}
		if lyrics.Empty() {
			continue
		}
		lyrics.Title, lyrics.Artist, lyrics.Album = song.Title, strings.Join(song.Artists, ", "), song.Album
		lyrics.DurationMS = song.Duration.Milliseconds()
		for _, line := range lyrics.Synced {
			for _, word := range line.Words {
				if strings.TrimSpace(word.Text) != "" {
					return lyrics, nil
				}
			}
		}
		if fallback == nil {
			fallback = lyrics
		}
	}
	if fallback != nil {
		return fallback, nil
	}
	if len(failures) > 0 {
		return nil, errors.Join(failures...)
	}
	return &corelyrics.Lyrics{}, nil
}

type qqLyricData struct {
	Lyric *string     `json:"lyric"`
	QRC   *int        `json:"qrc"`
	Crypt *int        `json:"crypt"`
	QRCT  json.Number `json:"qrc_t"`
	LRCT  json.Number `json:"lrc_t"`
}

func (c *Client) qqLyrics(ctx context.Context, song candidate) (*corelyrics.Lyrics, error) {
	id, err := strconv.ParseInt(song.ID, 10, 64)
	if err != nil {
		return nil, err
	}
	b64 := func(s string) string { return base64.StdEncoding.EncodeToString([]byte(s)) }
	params := map[string]any{"songID": id, "songName": b64(song.Title), "singerName": b64(strings.Join(song.Artists, "/")), "albumName": b64(song.Album), "interval": int64(song.Duration / time.Second), "ct": 19, "cv": 2111, "qrc": 1, "crypt": 1, "qrc_t": 0, "lrc_t": 0, "type": 0}
	var data qqLyricData
	if err = c.qqCall(ctx, "GetPlayLyricInfo", "music.musichallSong.PlayLyricInfo", params, &data); err != nil {
		return nil, err
	}
	lyrics, qerr := qqDecodeLyric(data)
	if qerr == nil && !lyrics.Empty() {
		return lyrics, nil
	}
	if data.Lyric == nil {
		return nil, errors.New("QQ Music lyric response omitted lyric")
	}
	// Ask explicitly for ordinary LRC when a QRC version is unavailable.
	params["qrc"], params["crypt"] = 0, 0
	var plain qqLyricData
	if err = c.qqCall(ctx, "GetPlayLyricInfo", "music.musichallSong.PlayLyricInfo", params, &plain); err != nil {
		return nil, errors.Join(qerr, err)
	}
	result, err := qqDecodeLyric(plain)
	if err != nil {
		return nil, errors.Join(qerr, err)
	}
	if result.Empty() && qerr != nil {
		return nil, qerr
	}
	return result, nil
}

func qqDecodeLyric(data qqLyricData) (*corelyrics.Lyrics, error) {
	if data.Lyric == nil || data.QRC == nil || data.Crypt == nil {
		return nil, errors.New("QQ Music lyric response omitted fields")
	}
	if *data.Lyric == "" {
		return &corelyrics.Lyrics{}, nil
	}
	if *data.QRC == 1 && *data.Crypt == 1 {
		if data.QRCT == "" {
			return nil, errors.New("QQ Music QRC response omitted timestamp")
		}
		timestamp, err := data.QRCT.Int64()
		if err != nil || timestamp < 0 {
			return nil, errors.New("QQ Music QRC response has invalid timestamp")
		}
		if timestamp == 0 {
			return &corelyrics.Lyrics{}, nil
		}
		raw, err := decryptQRC(*data.Lyric)
		if err != nil {
			return nil, err
		}
		return parseQRC(raw)
	}
	if *data.QRC != 0 || *data.Crypt != 0 {
		return nil, errors.New("unsupported QQ Music lyric encoding")
	}
	raw, err := base64.StdEncoding.DecodeString(*data.Lyric)
	if err != nil {
		return nil, err
	}
	if len(raw) > qrcMaxBytes {
		return nil, corelyrics.ErrTooLarge
	}
	lyrics, err := corelyrics.ParseLRC(raw)
	if err != nil {
		return nil, err
	}
	if len(lyrics.Synced) == 0 && strings.TrimSpace(lyrics.Plain) != "" {
		return nil, errors.New("QQ Music LRC has no valid timing")
	}
	if !qqHasVisibleText(lyrics) {
		return &corelyrics.Lyrics{}, nil
	}
	return lyrics, nil
}

func qqHasVisibleText(lyrics *corelyrics.Lyrics) bool {
	if strings.TrimSpace(lyrics.Plain) != "" {
		return true
	}
	for _, line := range lyrics.Synced {
		if strings.TrimSpace(line.Text) != "" {
			return true
		}
	}
	return false
}
