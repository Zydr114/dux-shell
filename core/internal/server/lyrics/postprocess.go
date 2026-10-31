package lyrics

import (
	"math"
	"sort"
	"strings"
	"unicode"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

func postprocess(result *corelyrics.Result) *corelyrics.Result {
	if result == nil {
		return nil
	}
	cleaned := *result
	cleaned.Plain = cleanPlain(result.Plain)
	cleaned.Synced = make([]corelyrics.Line, 0, len(result.Synced))
	type lane struct {
		voice      corelyrics.VoiceID
		background bool
	}
	blanks := make(map[lane][]corelyrics.Seconds)
	for _, source := range result.Synced {
		line := source
		line.Text = strings.TrimSpace(normalizeNewlines(source.Text))
		if line.Text == "" {
			if finiteTime(line.Start) {
				key := lane{line.Voice, line.Background}
				blanks[key] = append(blanks[key], line.Start)
			}
			continue
		}
		line.Words = cleanWords(source, line.Text)
		cleaned.Synced = append(cleaned.Synced, line)
	}
	for _, times := range blanks {
		sort.Slice(times, func(i, j int) bool { return times[i] < times[j] })
	}
	for i := range cleaned.Synced {
		line := &cleaned.Synced[i]
		times := blanks[lane{line.Voice, line.Background}]
		next := sort.Search(len(times), func(j int) bool { return times[j] > line.Start })
		if next == len(times) {
			continue
		}
		end := line.End
		if !finiteTime(end) || end <= line.Start {
			end = times[next]
			if words := line.Words; len(words) > 0 && words[len(words)-1].End > words[len(words)-1].Start {
				var wordEnd corelyrics.Seconds
				for _, word := range words {
					wordEnd = max(wordEnd, word.End)
				}
				end = min(end, wordEnd)
			}
		}
		// Blank cues close a vocal lane even though the display has no row for them.
		line.End = min(end, times[next])
		if words := line.Words; len(words) > 0 && words[len(words)-1].Start >= line.End {
			line.Words = nil
		}
	}
	if len(cleaned.Synced) == 0 && cleaned.Plain == "" && !cleaned.Instrumental {
		cleaned.Found = false
	}
	return &cleaned
}

func cleanPlain(text string) string {
	rows := strings.Split(normalizeNewlines(text), "\n")
	kept := rows[:0]
	for _, row := range rows {
		if row = strings.TrimSpace(row); row != "" {
			kept = append(kept, row)
		}
	}
	return strings.Join(kept, "\n")
}

func normalizeNewlines(text string) string {
	return strings.ReplaceAll(strings.ReplaceAll(text, "\r\n", "\n"), "\r", "\n")
}

func cleanWords(source corelyrics.Line, text string) []corelyrics.Word {
	if len(source.Words) == 0 {
		return nil
	}
	words := append([]corelyrics.Word(nil), source.Words...)
	var joined strings.Builder
	var precedingCR bool
	for i := range words {
		word := &words[i]
		if !finiteTime(word.Start) || word.Start < source.Start || i > 0 && word.Start < words[i-1].Start {
			return nil
		}
		if !finiteTime(word.End) || word.End != 0 && word.End < word.Start {
			return nil
		}
		if finiteTime(source.End) && source.End > source.Start && word.Start >= source.End {
			return nil
		}
		original := word.Text
		word.Text = normalizeNewlines(original)
		if precedingCR && strings.HasPrefix(original, "\n") {
			word.Text = strings.TrimPrefix(word.Text, "\n")
		}
		if original != "" {
			precedingCR = strings.HasSuffix(original, "\r")
		}
		joined.WriteString(word.Text)
	}
	if joined.String() != normalizeNewlines(source.Text) {
		return nil
	}
	for len(words) > 0 {
		words[0].Text = strings.TrimLeftFunc(words[0].Text, unicode.IsSpace)
		if words[0].Text != "" {
			break
		}
		words = words[1:]
	}
	for len(words) > 0 {
		last := len(words) - 1
		words[last].Text = strings.TrimRightFunc(words[last].Text, unicode.IsSpace)
		if words[last].Text != "" {
			break
		}
		words = words[:last]
	}
	joined.Reset()
	for _, word := range words {
		joined.WriteString(word.Text)
	}
	if joined.String() != text {
		return nil
	}
	return words
}

func finiteTime(value corelyrics.Seconds) bool {
	return !math.IsNaN(float64(value)) && !math.IsInf(float64(value), 0)
}
