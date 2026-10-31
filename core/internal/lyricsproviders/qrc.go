package lyricsproviders

import (
	"bytes"
	"compress/zlib"
	"encoding/hex"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"regexp"
	"sort"
	"strconv"
	"strings"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

const qrcMaxBytes = corelyrics.MaxSourceBytes

var qrcLinePattern = regexp.MustCompile(`^\[(\d+),(\d+)\](.*)$`)
var qrcMalformedLine = regexp.MustCompile(`^\[[+-]?\d[^\]]*,`)
var qrcWordPattern = regexp.MustCompile(`\((\d+),(\d+)\)`)
var qrcMalformedWord = regexp.MustCompile(`\([+-]?\d[^()]*,[^()]*\)|\([^()]*,[+-]?\d[^()]*\)|\([+-]?\d+,`)

func decryptQRC(text string) ([]byte, error) {
	if len(text) > qrcMaxBytes*2 {
		return nil, corelyrics.ErrTooLarge
	}
	if len(text) == 0 || len(text)%16 != 0 {
		return nil, errors.New("invalid qrc length")
	}
	data, err := hex.DecodeString(text)
	if err != nil {
		return nil, fmt.Errorf("invalid qrc hex: %w", err)
	}
	qrcCrypt(data, true)
	reader, err := zlib.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("invalid qrc compression: %w", err)
	}
	defer reader.Close()
	plain, err := io.ReadAll(io.LimitReader(reader, qrcMaxBytes+1))
	if err != nil {
		return nil, err
	}
	if len(plain) > qrcMaxBytes {
		return nil, corelyrics.ErrTooLarge
	}
	return plain, nil
}

func parseQRC(data []byte) (*corelyrics.Lyrics, error) {
	if len(data) > qrcMaxBytes {
		return nil, corelyrics.ErrTooLarge
	}
	dec := xml.NewDecoder(bytes.NewReader(data))
	var content string
	for {
		tok, err := dec.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("invalid qrc xml: %w", err)
		}
		if el, ok := tok.(xml.StartElement); ok && el.Name.Local == "Lyric_1" {
			for _, a := range el.Attr {
				if a.Name.Local == "LyricContent" {
					content = a.Value
				}
			}
		}
	}
	if content == "" {
		return nil, errors.New("qrc missing lyric content")
	}
	result := &corelyrics.Lyrics{}
	totalWords := 0
	for _, raw := range strings.Split(content, "\n") {
		m := qrcLinePattern.FindStringSubmatch(strings.TrimSuffix(raw, "\r"))
		if m == nil {
			if qrcMalformedLine.MatchString(raw) {
				return nil, errors.New("invalid qrc line timing")
			}
			continue
		}
		if len(result.Synced) >= corelyrics.MaxLines {
			return nil, corelyrics.ErrTooLarge
		}
		start, e1 := strconv.ParseInt(m[1], 10, 64)
		dur, e2 := strconv.ParseInt(m[2], 10, 64)
		if e1 != nil || e2 != nil || start > 86400000 || dur > 86400000 {
			return nil, errors.New("invalid qrc line timing")
		}
		line := corelyrics.Line{Start: corelyrics.Seconds(float64(start) / 1000), End: corelyrics.Seconds(float64(start+dur) / 1000)}
		text := m[3]
		matches := qrcWordPattern.FindAllStringSubmatchIndex(text, -1)
		prev := 0
		var lastStart int64 = -1
		for _, w := range matches {
			if qrcMalformedWord.MatchString(text[prev:w[0]]) {
				return nil, errors.New("invalid qrc word timing")
			}
			totalWords++
			if totalWords > corelyrics.MaxWords {
				return nil, corelyrics.ErrTooLarge
			}
			ws, e1 := strconv.ParseInt(text[w[2]:w[3]], 10, 64)
			wd, e2 := strconv.ParseInt(text[w[4]:w[5]], 10, 64)
			if e1 != nil || e2 != nil || ws > 86400000 || wd > 86400000 || ws < start || ws+wd > start+dur || ws < lastStart {
				return nil, errors.New("invalid qrc word timing")
			}
			lastStart = ws
			piece := text[prev:w[0]]
			line.Words = append(line.Words, corelyrics.Word{Start: corelyrics.Seconds(float64(ws) / 1000), End: corelyrics.Seconds(float64(ws+wd) / 1000), Text: piece})
			prev = w[1]
		}
		if qrcMalformedWord.MatchString(text[prev:]) {
			return nil, errors.New("invalid qrc word timing")
		}
		if prev < len(text) {
			if len(line.Words) > 0 {
				if len(line.Words) == 1 && line.Words[0].Text == "" {
					line.Words = nil
					line.Text = text[prev:]
				} else {
					line.Words[len(line.Words)-1].Text += text[prev:]
				}
			} else {
				line.Text = text
			}
		}
		if len(line.Words) > 0 {
			var s strings.Builder
			for _, w := range line.Words {
				s.WriteString(w.Text)
			}
			line.Text = s.String()
		}
		result.Synced = append(result.Synced, line)
	}
	if len(result.Synced) == 0 {
		return nil, errors.New("qrc has no timed lyrics")
	}
	if !qqHasVisibleText(result) {
		return &corelyrics.Lyrics{}, nil
	}
	sort.SliceStable(result.Synced, func(i, j int) bool { return result.Synced[i].Start < result.Synced[j].Start })
	return result, nil
}
