package lyricsproviders

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

const (
	NetEase corelyrics.Provider = "netease"
	QQMusic corelyrics.Provider = "qqmusic"
)

type Client struct {
	http *http.Client
}

func New() *Client {
	return &Client{http: &http.Client{
		Transport: &http.Transport{
			Proxy:                 http.ProxyFromEnvironment,
			DialContext:           (&net.Dialer{Timeout: 3 * time.Second}).DialContext,
			TLSHandshakeTimeout:   3 * time.Second,
			IdleConnTimeout:       90 * time.Second,
			MaxIdleConns:          4,
			MaxIdleConnsPerHost:   2,
			ResponseHeaderTimeout: 4 * time.Second,
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			origin := via[0].URL
			if len(via) >= 3 || req.URL.Scheme != origin.Scheme || req.URL.Host != origin.Host {
				return fmt.Errorf("refusing lyrics redirect")
			}
			return nil
		},
	}}
}

func (c *Client) Resolve(provider corelyrics.Provider) (corelyrics.Source, bool) {
	var source corelyrics.Source
	switch provider {
	case NetEase:
		source = corelyrics.Source{
			Attribution: corelyrics.Attribution{Name: "NetEase Cloud Music", URL: "https://music.163.com"},
			WordSync:    true,
			Fetch:       c.fetchNetEase,
		}
	case QQMusic:
		source = corelyrics.Source{
			Attribution: corelyrics.Attribution{Name: "QQ Music", URL: "https://y.qq.com"},
			WordSync:    true,
			Fetch:       c.fetchQQMusic,
		}
	default:
		return corelyrics.Source{}, false
	}
	fetch := source.Fetch
	source.Fetch = func(ctx context.Context, req corelyrics.Request) (*corelyrics.Lyrics, error) {
		ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
		defer cancel()
		return fetch(ctx, req)
	}
	return source, true
}

func (c *Client) requestJSON(ctx context.Context, method, endpoint string, headers http.Header, body []byte, payload any) error {
	ctx, cancel := context.WithTimeout(ctx, 4*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, method, endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header = headers.Clone()
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("lyrics provider HTTP %d", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, corelyrics.MaxSourceBytes+1))
	if err != nil {
		return err
	}
	if len(data) > corelyrics.MaxSourceBytes {
		return corelyrics.ErrTooLarge
	}
	if err := json.Unmarshal(data, payload); err != nil {
		return fmt.Errorf("invalid lyrics provider response: %w", err)
	}
	return nil
}
