package lyrics

import (
	"math"
	"reflect"
	"strings"
	"testing"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

func TestPostprocessPlainAndEmptyResults(t *testing.T) {
	for _, tc := range []struct {
		name         string
		plain        string
		instrumental bool
		wantPlain    string
		wantFound    bool
	}{
		{"line endings and whitespace", " \r\n  first \t\r\n\u3000\n\tsecond\rthird \r\n", false, "first\nsecond\nthird", true},
		{"only blank rows", "\t\r\n \r\u3000\n", false, "", false},
		{"instrumental", "\r\n", true, "", true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			input := &corelyrics.Result{Found: true, Lyrics: corelyrics.Lyrics{
				Plain: tc.plain, Instrumental: tc.instrumental,
				Synced: []corelyrics.Line{{Start: 1, Text: " \r\n\t"}},
			}}
			got := postprocess(input)
			if got.Plain != tc.wantPlain || got.Found != tc.wantFound || len(got.Synced) != 0 || got.Instrumental != tc.instrumental {
				t.Fatalf("postprocess() = %#v", got)
			}
			if input.Plain != tc.plain || len(input.Synced) != 1 || !input.Found {
				t.Fatal("postprocess mutated the source")
			}
		})
	}
}

func TestPostprocessWordsPreserveTextAndTiming(t *testing.T) {
	input := &corelyrics.Result{Found: true, Lyrics: corelyrics.Lyrics{
		Synced: []corelyrics.Line{{Start: 1, End: 5, Text: " \tHello  world\r\nagain  ", Words: []corelyrics.Word{
			{Start: 1, End: 1.1, Text: " \t"},
			{Start: 1.2, End: 2, Text: "Hello  "},
			{Start: 2, End: 3, Text: "world\r"},
			{Start: 3, End: 4, Text: "\nagain  "},
		}}},
	}}
	wantSourceWords := append([]corelyrics.Word(nil), input.Synced[0].Words...)
	got := postprocess(input).Synced[0]
	wantWords := []corelyrics.Word{
		{Start: 1.2, End: 2, Text: "Hello  "},
		{Start: 2, End: 3, Text: "world\n"},
		{Start: 3, End: 4, Text: "again"},
	}
	if got.Text != "Hello  world\nagain" || !reflect.DeepEqual(got.Words, wantWords) || got.Start != 1 || got.End != 5 {
		t.Fatalf("cleaned line = %#v", got)
	}
	var joined strings.Builder
	for _, word := range got.Words {
		joined.WriteString(word.Text)
	}
	if joined.String() != got.Text {
		t.Fatal("word text no longer matches line text")
	}
	got.Words[0].Text = "changed"
	if input.Synced[0].Text != " \tHello  world\r\nagain  " || !reflect.DeepEqual(input.Synced[0].Words, wantSourceWords) {
		t.Fatal("postprocess mutated cached line or word data")
	}
}

func TestPostprocessKeepsRepeatedLyricsAndVocalMetadata(t *testing.T) {
	voices := map[corelyrics.VoiceID]corelyrics.Voice{"a": {Name: "Alice"}, "b": {Name: "Bob"}}
	lines := []corelyrics.Line{
		{Start: 1, End: 2, Text: " echo ", Voice: "a", Group: 4},
		{Start: 1, End: 2, Text: " echo ", Voice: "b", Group: 4},
		{Start: 1, End: 2, Text: " echo ", Voice: "a", Background: true, Group: 4},
		{Start: 3, End: 4, Text: " echo ", Voice: "a", Group: 5},
	}
	got := postprocess(&corelyrics.Result{Found: true, Lyrics: corelyrics.Lyrics{Synced: lines, Voices: voices}})
	want := append([]corelyrics.Line(nil), lines...)
	for i := range want {
		want[i].Text = "echo"
	}
	if !reflect.DeepEqual(got.Synced, want) || !reflect.DeepEqual(got.Voices, voices) {
		t.Fatalf("repeated or simultaneous vocal lines changed: %#v", got)
	}
}

func TestPostprocessBlankCuesPreserveSilence(t *testing.T) {
	for _, tc := range []struct {
		name  string
		end   corelyrics.Seconds
		words []corelyrics.Word
		want  corelyrics.Seconds
	}{
		{"missing end", 0, nil, 3},
		{"earlier explicit end", 2, nil, 2},
		{"later explicit end", 9, nil, 3},
		{"earlier word endpoint", 0, []corelyrics.Word{{Start: 1, End: 2, Text: "sing"}}, 2},
		{"later word endpoint", 0, []corelyrics.Word{{Start: 1, End: 4, Text: "sing"}}, 3},
		{"unknown word end", 0, []corelyrics.Word{{Start: 1, Text: "sing"}}, 3},
	} {
		t.Run(tc.name, func(t *testing.T) {
			input := &corelyrics.Result{Found: true, Lyrics: corelyrics.Lyrics{Synced: []corelyrics.Line{
				{Start: 0, Text: " "},
				{Start: 1, End: tc.end, Text: "sing", Words: tc.words},
				{Start: 3, Text: "\t"},
				{Start: 4, Text: " "},
				{Start: 10, Text: "again"},
			}}}
			got := postprocess(input)
			if len(got.Synced) != 2 || got.Synced[0].End != tc.want || !reflect.DeepEqual(got.Synced[0].Words, tc.words) {
				t.Fatalf("blank cue lost the vocal boundary: %#v", got.Synced)
			}
			if input.Synced[1].End != tc.end || len(input.Synced) != 5 {
				t.Fatal("source cue boundaries changed")
			}
		})
	}
}

func TestPostprocessBlankBoundariesStayInTheirLane(t *testing.T) {
	input := &corelyrics.Result{Found: true, Lyrics: corelyrics.Lyrics{Synced: []corelyrics.Line{
		{Start: 1, Text: "lead", Voice: "a", Group: 7},
		{Start: 1, Text: "duet", Voice: "b", Group: 7},
		{Start: 1, Text: "backing", Voice: "a", Background: true, Group: 7},
		{Start: 1, Text: " ", Voice: "a"},
		{Start: 3, Text: " ", Voice: "b"},
		{Start: 4, Text: " ", Voice: "a", Background: true},
		{Start: 5, Text: " ", Voice: "a"},
	}}}
	got := postprocess(input)
	want := []corelyrics.Line{
		{Start: 1, End: 5, Text: "lead", Voice: "a", Group: 7},
		{Start: 1, End: 3, Text: "duet", Voice: "b", Group: 7},
		{Start: 1, End: 4, Text: "backing", Voice: "a", Background: true, Group: 7},
	}
	if !reflect.DeepEqual(got.Synced, want) {
		t.Fatalf("vocal boundaries = %#v, want %#v", got.Synced, want)
	}
}

func TestPostprocessWordsCannotReopenAnEndedLine(t *testing.T) {
	for _, tc := range []struct {
		name      string
		end       corelyrics.Seconds
		wordStart corelyrics.Seconds
		blank     bool
		wantEnd   corelyrics.Seconds
	}{
		{"at blank cue", 0, 3, true, 3},
		{"after blank cue", 0, 4, true, 3},
		{"at explicit end", 2, 2, false, 2},
		{"after explicit end", 2, 3, false, 2},
	} {
		t.Run(tc.name, func(t *testing.T) {
			words := []corelyrics.Word{{Start: tc.wordStart, End: 5, Text: "sing"}}
			lines := []corelyrics.Line{{Start: 1, End: tc.end, Text: "sing", Words: words}}
			if tc.blank {
				lines = append(lines, corelyrics.Line{Start: 3, Text: " "})
			}
			got := postprocess(&corelyrics.Result{Found: true, Lyrics: corelyrics.Lyrics{Synced: lines}})
			if len(got.Synced) != 1 || got.Synced[0].End != tc.wantEnd || len(got.Synced[0].Words) != 0 {
				t.Fatalf("invalid word timing reopened an ended line: %#v", got.Synced)
			}
			if lines[0].End != tc.end || len(lines[0].Words) != 1 || lines[0].Words[0].Start != tc.wordStart {
				t.Fatal("fallback mutated source timing")
			}
		})
	}
}

func TestPostprocessInvalidWordsFallBackToLineSync(t *testing.T) {
	for _, tc := range []struct {
		name  string
		words []corelyrics.Word
	}{
		{"mismatched text", []corelyrics.Word{{Start: 1, End: 2, Text: "different"}}},
		{"start before line", []corelyrics.Word{{Start: 0, End: 2, Text: "sing"}}},
		{"nonfinite start", []corelyrics.Word{{Start: corelyrics.Seconds(math.NaN()), End: 2, Text: "sing"}}},
		{"invalid endpoint", []corelyrics.Word{{Start: 2, End: 1, Text: "sing"}}},
		{"nonfinite endpoint", []corelyrics.Word{{Start: 1, End: corelyrics.Seconds(math.Inf(1)), Text: "sing"}}},
		{"out of order", []corelyrics.Word{{Start: 2, End: 3, Text: "si"}, {Start: 1, End: 2, Text: "ng"}}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			got := postprocess(&corelyrics.Result{Found: true, Lyrics: corelyrics.Lyrics{Synced: []corelyrics.Line{
				{Start: 1, End: 4, Text: "sing", Words: tc.words},
			}}}).Synced[0]
			if got.Text != "sing" || len(got.Words) != 0 || got.Start != 1 || got.End != 4 {
				t.Fatalf("invalid word data did not fall back safely: %#v", got)
			}
		})
	}
}
