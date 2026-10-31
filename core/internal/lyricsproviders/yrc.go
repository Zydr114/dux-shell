package lyricsproviders

import (
	"bytes"
	"encoding/json"
	"errors"
	"math"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"unicode/utf8"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

var yrcWordTag = regexp.MustCompile(`\([0-9]+,[0-9]+,[0-9]+\)`)

func parseYRC(data []byte) (*corelyrics.Lyrics, error) {
	if len(data) > corelyrics.MaxSourceBytes {
		return nil, corelyrics.ErrTooLarge
	}
	data = bytes.TrimPrefix(data, []byte{0xef, 0xbb, 0xbf})
	if !utf8.Valid(data) {
		return nil, corelyrics.ErrEncoding
	}
	result := &corelyrics.Lyrics{}
	wordCount := 0
	for _, raw := range strings.Split(string(data), "\n") {
		raw = strings.TrimSuffix(raw, "\r")
		if strings.TrimSpace(raw) == "" {
			continue
		}
		// NetEase includes JSON credit rows alongside the timed vocal lines.
		if strings.HasPrefix(raw, "{") && json.Valid([]byte(raw)) {
			continue
		}
		line, err := parseYRCLine(raw)
		if err != nil {
			return nil, err
		}
		wordCount += len(line.Words)
		if len(result.Synced) >= corelyrics.MaxLines || wordCount > corelyrics.MaxWords {
			return nil, corelyrics.ErrTooLarge
		}
		result.Synced = append(result.Synced, line)
	}
	sort.SliceStable(result.Synced, func(i, j int) bool { return result.Synced[i].Start < result.Synced[j].Start })
	plain := make([]string, 0, len(result.Synced))
	for _, line := range result.Synced {
		plain = append(plain, line.Text)
	}
	result.Plain = strings.Join(plain, "\n")
	if strings.TrimSpace(result.Plain) == "" {
		return &corelyrics.Lyrics{}, nil
	}
	return result, nil
}

func parseYRCLine(raw string) (corelyrics.Line, error) {
	var line corelyrics.Line
	if !strings.HasPrefix(raw, "[") {
		return line, errors.New("invalid YRC line header")
	}
	header, body, ok := strings.Cut(raw[1:], "]")
	if !ok {
		return line, errors.New("invalid YRC line header")
	}
	start, duration, err := yrcInterval(header, 2)
	if err != nil {
		return line, err
	}
	line.Start = corelyrics.Seconds(float64(start) / 1000)
	line.End = corelyrics.Seconds(float64(start+duration) / 1000)
	tags := yrcWordTag.FindAllStringIndex(body, corelyrics.MaxWords+1)
	if len(tags) > corelyrics.MaxWords {
		return line, corelyrics.ErrTooLarge
	}
	if len(tags) == 0 || tags[0][0] != 0 {
		return line, errors.New("YRC line has no valid word timing")
	}
	var text strings.Builder
	previousStart := start
	for i, tag := range tags {
		at, length, err := yrcInterval(body[tag[0]+1:tag[1]-1], 3)
		if err != nil || at < previousStart || at < start || at+length > start+duration {
			return line, errors.New("invalid YRC word interval")
		}
		end := len(body)
		if i+1 < len(tags) {
			end = tags[i+1][0]
		}
		wordText := body[tag[1]:end]
		if suspiciousYRCTag(wordText) {
			return line, errors.New("invalid YRC word timing")
		}
		line.Words = append(line.Words, corelyrics.Word{
			Start: corelyrics.Seconds(float64(at) / 1000),
			End:   corelyrics.Seconds(float64(at+length) / 1000),
			Text:  wordText,
		})
		text.WriteString(wordText)
		previousStart = at
	}
	line.Text = text.String()
	return line, nil
}

func suspiciousYRCTag(text string) bool {
	for _, suffix := range strings.Split(text, "(")[1:] {
		end := strings.IndexByte(suffix, ')')
		if end < 0 {
			end = len(suffix)
		}
		parts := strings.Split(suffix[:end], ",")
		if len(parts) < 2 || parts[0] == "" {
			continue
		}
		if first := parts[0][0]; first >= '0' && first <= '9' || first == '-' || first == '+' {
			return true
		}
		if len(parts) == 3 {
			_, secondErr := strconv.ParseInt(parts[1], 10, 64)
			_, thirdErr := strconv.ParseInt(parts[2], 10, 64)
			if secondErr == nil && thirdErr == nil {
				return true
			}
		}
	}
	return false
}

func yrcInterval(raw string, count int) (int64, int64, error) {
	parts := strings.Split(raw, ",")
	if len(parts) != count {
		return 0, 0, errors.New("invalid YRC timestamp")
	}
	values := make([]int64, count)
	for i, part := range parts {
		value, err := strconv.ParseInt(part, 10, 64)
		if err != nil || value < 0 || strings.HasPrefix(part, "+") {
			return 0, 0, errors.New("invalid YRC timestamp")
		}
		values[i] = value
	}
	if values[0] > math.MaxInt64-values[1] {
		return 0, 0, errors.New("YRC timestamp overflow")
	}
	return values[0], values[1], nil
}
