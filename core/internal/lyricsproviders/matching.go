package lyricsproviders

import (
	"math"
	"regexp"
	"slices"
	"strings"
	"time"
	"unicode"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
	"golang.org/x/text/unicode/norm"
)

type candidate struct {
	ID       string
	MID      string
	Title    string
	Subtitle string
	Artists  []string
	Album    string
	Duration time.Duration
}

var (
	versionWords = regexp.MustCompile(`\b(live|remix|instrumental|karaoke|cover|acoustic)\b`)
	titleNotes   = regexp.MustCompile(`[(\[【][^)\]】]*[)\]】]`)
	artistSplit  = regexp.MustCompile(`(?i)\s+(?:feat\.?|ft\.?)\s+|[/;&、,，]`)
)

func normalized(value string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsLetter(r) || unicode.IsNumber(r) {
			return unicode.ToLower(r)
		}
		return -1
	}, norm.NFKC.String(value))
}

func titleKey(value string) string {
	key := normalized(titleNotes.ReplaceAllStringFunc(norm.NFKC.String(value), func(note string) string {
		chars := []rune(note)
		switch normalized(string(chars[1 : len(chars)-1])) {
		case "live", "现场", "现场版", "remix", "instrumental", "karaoke", "伴奏", "伴奏版", "cover", "翻唱", "acoustic", "旧版":
			return " "
		}
		return note
	}))
	if key == "" {
		return normalized(value)
	}
	return key
}

func versionFlags(value string) string {
	value = strings.ToLower(norm.NFKC.String(value))
	flags := make(map[string]bool)
	for _, word := range versionWords.FindAllString(value, -1) {
		if word == "karaoke" {
			word = "instrumental"
		}
		flags[word] = true
	}
	for text, kind := range map[string]string{"现场": "live", "伴奏": "instrumental", "翻唱": "cover", "旧版": "old"} {
		if strings.Contains(value, text) {
			flags[kind] = true
		}
	}
	keys := make([]string, 0, len(flags))
	for key := range flags {
		keys = append(keys, key)
	}
	slices.Sort(keys)
	return strings.Join(keys, ",")
}

func matchesArtist(wanted string, artists []string) (bool, bool) {
	name := normalized(wanted)
	if name == "" {
		return false, false
	}
	names := artistNames(wanted)
	for _, artist := range artists {
		other := normalized(artist)
		if other == "" {
			continue
		}
		if name == other {
			return true, true
		}
		for _, part := range names {
			for _, alias := range artistNames(artist) {
				if part == alias {
					return true, false
				}
			}
		}
	}
	return false, false
}

func artistNames(value string) []string {
	var names []string
	for _, part := range artistSplit.Split(norm.NFKC.String(value), -1) {
		base := titleNotes.ReplaceAllString(part, " ")
		if name := normalized(base); name != "" {
			names = append(names, name)
		}
		// Catalogues can carry a former artist name in parentheses beside a new one.
		for _, note := range titleNotes.FindAllString(part, -1) {
			chars := []rune(note)
			if alias := normalized(string(chars[1 : len(chars)-1])); alias != "" {
				names = append(names, alias)
			}
		}
	}
	return names
}

func rankCandidates(req corelyrics.Request, songs []candidate) []candidate {
	title := titleKey(req.Title)
	if title == "" {
		return nil
	}
	type scored struct {
		song        candidate
		exactTitle  bool
		exactArtist bool
		exactAlbum  bool
		gap         time.Duration
	}
	var ranked []scored
	seen := make(map[string]bool)
	wantedVersion := versionFlags(req.Title)
	for _, song := range songs {
		identity := song.ID
		if identity == "" {
			identity = song.MID
		}
		otherTitle := titleKey(song.Title)
		if identity == "" || seen[identity] || otherTitle == "" {
			continue
		}
		if otherTitle != title {
			continue
		}
		if versionFlags(song.Title+" "+song.Subtitle) != wantedVersion {
			continue
		}
		matches, exactArtist := matchesArtist(req.Artist, song.Artists)
		if !matches {
			continue
		}
		gap := time.Duration(math.MaxInt64)
		if req.Duration > 0 && song.Duration > 0 {
			gap = req.Duration - song.Duration
			if gap < 0 {
				gap = -gap
			}
			if gap > 8*time.Second {
				continue
			}
		}
		seen[identity] = true
		ranked = append(ranked, scored{
			song: song, exactTitle: normalized(song.Title) == normalized(req.Title), exactArtist: exactArtist,
			exactAlbum: req.Album != "" && normalized(req.Album) == normalized(song.Album), gap: gap,
		})
	}
	slices.SortStableFunc(ranked, func(a, b scored) int {
		for _, pair := range [][2]bool{{a.exactTitle, b.exactTitle}, {a.exactArtist, b.exactArtist}, {a.exactAlbum, b.exactAlbum}} {
			if pair[0] != pair[1] {
				if pair[0] {
					return -1
				}
				return 1
			}
		}
		if a.gap < b.gap {
			return -1
		}
		if a.gap > b.gap {
			return 1
		}
		return 0
	})
	result := make([]candidate, 0, min(3, len(ranked)))
	for _, scored := range ranked[:min(3, len(ranked))] {
		result = append(result, scored.song)
	}
	return result
}
