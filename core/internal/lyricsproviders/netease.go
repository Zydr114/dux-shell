package lyricsproviders

import (
	"bytes"
	"context"
	"crypto/aes"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

const netEaseBase = "https://music.163.com"

type netEaseSearchResponse struct {
	Code   int `json:"code"`
	Result *struct {
		SongCount *int `json:"songCount"`
		Songs     []struct {
			ID       int64  `json:"id"`
			Name     string `json:"name"`
			Duration int64  `json:"dt"`
			Artists  []struct {
				Name string `json:"name"`
			} `json:"ar"`
			Album struct {
				Name string `json:"name"`
			} `json:"al"`
		} `json:"songs"`
	} `json:"result"`
}

type netEaseLyricResponse struct {
	Code        int                `json:"code"`
	NoLyric     bool               `json:"nolyric"`
	Uncollected bool               `json:"uncollected"`
	YRC         *netEaseLyricField `json:"yrc"`
	LRC         *netEaseLyricField `json:"lrc"`
}

type netEaseLyricField struct {
	Lyric *string `json:"lyric"`
}

func (c *Client) searchNetEase(ctx context.Context, query string) ([]candidate, error) {
	form := url.Values{
		"s":    {query},
		"type": {"1"}, "limit": {"20"}, "offset": {"0"},
	}
	var response netEaseSearchResponse
	if err := c.requestJSON(ctx, http.MethodPost, netEaseBase+"/api/cloudsearch/pc", netEaseHeaders(), []byte(form.Encode()), &response); err != nil {
		return nil, fmt.Errorf("NetEase search: %w", err)
	}
	if response.Code != http.StatusOK || response.Result == nil {
		return nil, fmt.Errorf("NetEase search returned code %d or missing result", response.Code)
	}
	if response.Result.SongCount == nil && response.Result.Songs == nil {
		return nil, errors.New("NetEase search omitted songs and count")
	}
	if response.Result.SongCount != nil && (*response.Result.SongCount < 0 || *response.Result.SongCount > 0 && len(response.Result.Songs) == 0) {
		return nil, errors.New("NetEase search returned an inconsistent song count")
	}
	songs := make([]candidate, 0, len(response.Result.Songs))
	for _, song := range response.Result.Songs {
		if song.ID <= 0 || song.Name == "" || len(song.Artists) == 0 || song.Duration < 0 || song.Duration > int64((24*time.Hour)/time.Millisecond) {
			return nil, errors.New("NetEase search returned malformed song")
		}
		artists := make([]string, 0, len(song.Artists))
		for _, artist := range song.Artists {
			if strings.TrimSpace(artist.Name) == "" {
				return nil, errors.New("NetEase search returned malformed artist")
			}
			artists = append(artists, artist.Name)
		}
		var duration time.Duration
		if song.Duration > 0 && song.Duration <= int64((24*time.Hour)/time.Millisecond) {
			duration = time.Duration(song.Duration) * time.Millisecond
		}
		songs = append(songs, candidate{ID: strconv.FormatInt(song.ID, 10), Title: song.Name, Artists: artists, Album: song.Album.Name, Duration: duration})
	}
	return songs, nil
}

func (c *Client) fetchNetEase(ctx context.Context, req corelyrics.Request) (*corelyrics.Lyrics, error) {
	query := strings.TrimSpace(req.Title + " " + req.Artist)
	songs, err := c.searchNetEase(ctx, query)
	if err != nil {
		return nil, err
	}
	ranked := rankCandidates(req, songs)
	if len(ranked) == 0 && query != strings.TrimSpace(req.Title) {
		songs, err = c.searchNetEase(ctx, strings.TrimSpace(req.Title))
		if err != nil {
			return nil, err
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
		lyrics, err := c.netEaseLyrics(ctx, song.ID)
		if err != nil {
			if errors.Is(ctx.Err(), context.Canceled) {
				return nil, ctx.Err()
			}
			failures = append(failures, err)
			continue
		}
		if lyrics.Empty() {
			continue
		}
		lyrics.Title, lyrics.Artist, lyrics.Album = song.Title, strings.Join(song.Artists, ", "), song.Album
		lyrics.DurationMS = song.Duration.Milliseconds()
		if netEaseHasWords(lyrics) {
			return lyrics, nil
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

func (c *Client) netEaseLyrics(ctx context.Context, id string) (*corelyrics.Lyrics, error) {
	payload := map[string]any{"id": id, "cp": false, "tv": 0, "lv": 0, "rv": 0, "kv": 0, "yv": 0, "ytv": 0, "yrv": 0}
	body, err := netEaseEAPI("/api/song/lyric/v1", payload)
	if err != nil {
		return nil, err
	}
	var response netEaseLyricResponse
	if err := c.requestJSON(ctx, http.MethodPost, netEaseBase+"/eapi/song/lyric/v1", netEaseHeaders(), body, &response); err != nil {
		return nil, fmt.Errorf("NetEase lyric: %w", err)
	}
	if response.Code != http.StatusOK {
		return nil, fmt.Errorf("NetEase lyric returned code %d", response.Code)
	}
	var yrcErr error
	if response.YRC != nil {
		if response.YRC.Lyric == nil {
			yrcErr = errors.New("NetEase YRC omitted lyric text")
		} else if strings.TrimSpace(*response.YRC.Lyric) != "" {
			lyrics, err := parseYRC([]byte(*response.YRC.Lyric))
			if err == nil && !lyrics.Empty() {
				return lyrics, nil
			}
			yrcErr = err
		}
	}
	if response.LRC != nil && response.LRC.Lyric == nil {
		return nil, errors.New("NetEase LRC omitted lyric text")
	}
	if response.LRC != nil && strings.TrimSpace(*response.LRC.Lyric) != "" {
		if len(*response.LRC.Lyric) > corelyrics.MaxSourceBytes {
			return nil, corelyrics.ErrTooLarge
		}
		// The LRC field uses the same optional JSON credit rows as YRC.
		var lines []string
		for _, line := range strings.Split(*response.LRC.Lyric, "\n") {
			if strings.HasPrefix(line, "{") && json.Valid([]byte(line)) {
				continue
			}
			lines = append(lines, line)
		}
		lyrics, err := corelyrics.ParseLRC([]byte(strings.Join(lines, "\n")))
		if err != nil {
			return nil, err
		}
		if len(lyrics.Synced) == 0 && strings.TrimSpace(lyrics.Plain) != "" {
			return nil, errors.New("NetEase LRC has no valid line timing")
		}
		if strings.TrimSpace(lyrics.Plain) != "" {
			return lyrics, nil
		}
	}
	if yrcErr != nil {
		return nil, fmt.Errorf("NetEase YRC: %w", yrcErr)
	}
	if response.YRC == nil && response.LRC == nil && !response.NoLyric && !response.Uncollected {
		return nil, errors.New("NetEase lyric response omitted lyric fields")
	}
	return &corelyrics.Lyrics{}, nil
}

func netEaseHasWords(lyrics *corelyrics.Lyrics) bool {
	for _, line := range lyrics.Synced {
		if len(line.Words) > 0 {
			return true
		}
	}
	return false
}

func netEaseHeaders() http.Header {
	return http.Header{
		"Content-Type": {"application/x-www-form-urlencoded"},
		"Referer":      {netEaseBase + "/"},
		"User-Agent":   {"NeteaseMusic/3.1.17.204416"},
		"Cookie":       {"os=pc; appver=3.1.17.204416"},
	}
}

func netEaseEAPI(path string, payload any) ([]byte, error) {
	data, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	// This digest and AES envelope are NetEase's eapi wire format, not authentication.
	digest := md5.Sum([]byte("nobody" + path + "use" + string(data) + "md5forencrypt"))
	plain := []byte(path + "-36cd479b6b5-" + string(data) + "-36cd479b6b5-" + hex.EncodeToString(digest[:]))
	block, err := aes.NewCipher([]byte("e82ckenh8dichen8"))
	if err != nil {
		return nil, err
	}
	padding := block.BlockSize() - len(plain)%block.BlockSize()
	plain = append(plain, bytes.Repeat([]byte{byte(padding)}, padding)...)
	encrypted := make([]byte, len(plain))
	for i := 0; i < len(plain); i += block.BlockSize() {
		block.Encrypt(encrypted[i:i+block.BlockSize()], plain[i:i+block.BlockSize()])
	}
	return []byte(url.Values{"params": {strings.ToUpper(hex.EncodeToString(encrypted))}}.Encode()), nil
}
