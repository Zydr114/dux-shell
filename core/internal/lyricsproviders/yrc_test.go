package lyricsproviders

import (
	"errors"
	"strings"
	"testing"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

func TestParseYRCAbsoluteTimingAndText(t *testing.T) {
	input := "\ufeff{\"t\":0,\"c\":[{\"tx\":\"Credit\"}]}\r\n[5000,2000](5000,600,0) hello (5600,400,0)(2026) (6200,500,0)世界! (you, me) \r\n[1000,500](1000,500,0)First\n"
	lyrics, err := parseYRC([]byte(input))
	if err != nil {
		t.Fatal(err)
	}
	if len(lyrics.Synced) != 2 || lyrics.Plain != "First\n hello (2026) 世界! (you, me) " {
		t.Fatalf("unexpected parsed content: %+v", lyrics)
	}
	line := lyrics.Synced[1]
	if line.Start != 5 || line.End != 7 || len(line.Words) != 3 || line.Words[0].Start != 5 || line.Words[0].End != 5.6 || line.Words[2].Start != 6.2 || line.Words[2].End != 6.7 {
		t.Fatalf("absolute word and end timings lost: %+v", line)
	}
	var text strings.Builder
	for _, word := range line.Words {
		text.WriteString(word.Text)
	}
	if text.String() != line.Text {
		t.Fatalf("word text does not concatenate to line: %q != %q", text.String(), line.Text)
	}
}

func TestParseYRCRejectsMalformed(t *testing.T) {
	for _, input := range []string{
		"not YRC", "[1000,500]text", "[1000,500](1000,500)text", "[1000,500](1000,-1,0)text",
		"[1000,500](1000,600,0)text", "[1000,500](900,500,0)text", "[1000,500](1200,10,0)a(1100,10,0)b",
		"[1000,500](1000,100,0)a(1100,x,0)b", "[1000,500](1000,100,0)a(1100,100",
		"[9223372036854775807,1](0,1,0)x", "[1000,500](9223372036854775807,1,0)x",
		"[1000,500](1000,100,0)a\n{bad json}", "[1000,500](1000,100,0)\xff",
	} {
		t.Run(input, func(t *testing.T) {
			if _, err := parseYRC([]byte(input)); err == nil {
				t.Fatalf("accepted malformed YRC: %q", input)
			}
		})
	}
}

func TestParseYRCLimits(t *testing.T) {
	cases := map[string]string{
		"bytes": strings.Repeat("x", corelyrics.MaxSourceBytes+1),
		"lines": strings.Repeat("[0,1](0,1,0)a\n", corelyrics.MaxLines+1),
		"words": "[0,1]" + strings.Repeat("(0,1,0)a", corelyrics.MaxWords+1),
	}
	for name, input := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := parseYRC([]byte(input)); !errors.Is(err, corelyrics.ErrTooLarge) {
				t.Fatalf("expected size error, got %v", err)
			}
		})
	}
}

func TestParseYRCEmptyAndZeroDuration(t *testing.T) {
	empty, err := parseYRC(nil)
	if err != nil || !empty.Empty() {
		t.Fatalf("empty YRC: %+v, %v", empty, err)
	}
	lyrics, err := parseYRC([]byte("[0,0](0,0,0)Text"))
	if err != nil || lyrics.Empty() || len(lyrics.Synced[0].Words) != 1 {
		t.Fatalf("zero-duration word: %+v, %v", lyrics, err)
	}
}

func TestParseYRCBlankCuesRequireContent(t *testing.T) {
	blank := "[1000,100](1000,100,0)   \n"
	lyrics, err := parseYRC([]byte(blank))
	if err != nil || !lyrics.Empty() {
		t.Fatalf("blank word cues became lyrics: %+v, %v", lyrics, err)
	}
	lyrics, err = parseYRC([]byte(blank + "[2000,100](2000,100,0)Content"))
	if err != nil || lyrics.Empty() || len(lyrics.Synced) != 2 || lyrics.Synced[0].Text != "   " {
		t.Fatalf("blank cue beside visible content was lost: %+v, %v", lyrics, err)
	}
}
