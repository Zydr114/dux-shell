package lyricsproviders

import (
	"errors"
	"strings"
	"testing"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

const qrcFixture = "bb3700674bb01afe36a25f80e70cabbde83995ce92bf93c84eaedd4fc9b91c7c3bd76464e4ff7d29cbf0802caeb399a20bc78b4670e4f20dc6f1ccd71f3fa6cfa9afb2e294811709649c0a63c5634d42d9320c859d97bff88693bf7c9784467e4444684379ef979a"

func TestQRCEncryptedAndEntities(t *testing.T) {
	raw, err := decryptQRC(qrcFixture)
	if err != nil {
		t.Fatal(err)
	}
	lyrics, err := parseQRC(raw)
	if err != nil {
		t.Fatal(err)
	}
	if len(lyrics.Synced) != 1 {
		t.Fatalf("lines: %#v", lyrics.Synced)
	}
	line := lyrics.Synced[0]
	if line.Text != "A & B" || line.Start != 1 || line.End != 1.8 || len(line.Words) != 2 || line.Words[0].End != 1.3 || line.Words[1].Start != 1.3 || line.Words[1].End != 1.8 {
		t.Fatalf("line: %#v", line)
	}
}

func TestQRCBlankCuesAndTiming(t *testing.T) {
	xml := func(content string) []byte {
		return []byte(`<QrcInfos><Lyric_1 LyricContent="` + content + `"/></QrcInfos>`)
	}
	lyrics, err := parseQRC(xml("[0,500] \n[500,500](500,500)\n[1000,500]A(1000,500)B(1000,500)"))
	if err != nil {
		t.Fatal(err)
	}
	if len(lyrics.Synced) != 3 || lyrics.Synced[0].Text != " " || len(lyrics.Synced[1].Words) != 1 || lyrics.Synced[1].Text != "" || len(lyrics.Synced[2].Words) != 2 {
		t.Fatalf("cues: %#v", lyrics.Synced)
	}
	blank, err := parseQRC(xml("[0,500] \n[500,500](500,500)"))
	if err != nil || !blank.Empty() {
		t.Fatalf("blank QRC: %#v, %v", blank, err)
	}
	for _, content := range []string{"[1000,500]A(999,1)", "[1000,500]A(1200,301)", "[1000,500]A(1200,1)B(1100,1)", "[1000,500]A(-1,3)", "[1000,500]A(1,bad)", "[1,bad]a\n[0,1]a", "[ti:only metadata]"} {
		if _, err := parseQRC(xml(content)); err == nil {
			t.Fatalf("accepted %q", content)
		}
	}
	untimed, err := parseQRC(xml("[0,500](0,500)hello"))
	if err != nil || len(untimed.Synced) != 1 || len(untimed.Synced[0].Words) != 0 {
		t.Fatalf("untimed trailing text: %#v, %v", untimed, err)
	}
}

func TestQRCSizeLimits(t *testing.T) {
	if _, err := decryptQRC(strings.Repeat("00", corelyrics.MaxSourceBytes+1)); !errors.Is(err, corelyrics.ErrTooLarge) {
		t.Fatalf("encrypted size: %v", err)
	}
	if _, err := parseQRC([]byte(strings.Repeat("x", corelyrics.MaxSourceBytes+1))); !errors.Is(err, corelyrics.ErrTooLarge) {
		t.Fatalf("source size: %v", err)
	}
	for _, content := range []string{strings.Repeat("[0,1]x\n", corelyrics.MaxLines+1), "[0,1]" + strings.Repeat("x(0,1)", corelyrics.MaxWords+1)} {
		_, err := parseQRC([]byte(`<QrcInfos><Lyric_1 LyricContent="` + content + `"/></QrcInfos>`))
		if !errors.Is(err, corelyrics.ErrTooLarge) {
			t.Fatalf("expanded size: %v", err)
		}
	}
}
func TestQRCInvalidAndBounds(t *testing.T) {
	for _, raw := range []string{"xyz", strings.Repeat("00", qrcMaxBytes+1), strings.Repeat("00", 8)} {
		if _, err := decryptQRC(raw); err == nil {
			t.Fatal("invalid encrypted QRC accepted")
		}
	}
	for _, raw := range []string{`<QrcInfos>`, `<QrcInfos><Lyric_1 LyricContent="[99999999999999999999,1]A(0,1)"/></QrcInfos>`, `<QrcInfos><Lyric_1 LyricContent="[0,1]A &bad;"/></QrcInfos>`} {
		if _, err := parseQRC([]byte(raw)); err == nil {
			t.Fatalf("accepted %q", raw)
		}
	}
}
