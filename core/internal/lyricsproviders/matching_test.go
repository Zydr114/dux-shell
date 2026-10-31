package lyricsproviders

import (
	"slices"
	"testing"
	"time"

	corelyrics "github.com/duxlabs-dev/dux-go/lyrics"
)

func TestCandidatesRejectWrongRecordingsAndRankKnownMetadata(t *testing.T) {
	req := corelyrics.Request{Title: "晴天", Artist: "周杰伦", Album: "叶惠美", Duration: 269 * time.Second}
	songs := []candidate{
		{ID: "other", Title: "晴天", Artists: []string{"其他歌手"}, Duration: req.Duration},
		{ID: "live", Title: "晴天", Subtitle: "Live", Artists: []string{req.Artist}, Duration: req.Duration},
		{ID: "remix", Title: "晴天 remix", Artists: []string{req.Artist}, Duration: req.Duration},
		{ID: "long", Title: "晴天", Artists: []string{req.Artist}, Duration: 300 * time.Second},
		{ID: "unknown-duration", Title: "晴天", Artists: []string{req.Artist}},
		{ID: "reissue", Title: "晴天", Artists: []string{req.Artist}, Album: "精选", Duration: req.Duration},
		{ID: "original", Title: "晴天", Artists: []string{req.Artist}, Album: req.Album, Duration: req.Duration + time.Second},
		{ID: "original", Title: "晴天", Artists: []string{req.Artist}, Album: req.Album, Duration: req.Duration},
	}
	got := rankCandidates(req, songs)
	ids := make([]string, len(got))
	for i, song := range got {
		ids[i] = song.ID
	}
	if !slices.Equal(ids, []string{"original", "reissue", "unknown-duration"}) {
		t.Fatalf("ranked candidates = %v", ids)
	}
}

func TestCandidatesKeepVersionsAndHandleCatalogueArtistAliases(t *testing.T) {
	tests := []struct {
		name   string
		title  string
		artist string
		song   candidate
		want   bool
	}{
		{"artist alias", "起风了", "买辣椒也用券", candidate{ID: "1", Title: "起风了", Artists: []string{"冯沁苑(买辣椒也用券)"}}, true},
		{"full width", "ＡＢＣ", "歌手", candidate{ID: "1", Title: "ABC", Artists: []string{"歌手"}}, true},
		{"multiple artists", "合作", "甲 / 乙", candidate{ID: "1", Title: "合作", Artists: []string{"甲", "乙"}}, true},
		{"live version", "歌曲 (Live)", "歌手", candidate{ID: "1", Title: "歌曲（现场）", Artists: []string{"歌手"}}, true},
		{"version in subtitle", "歌曲 (Live)", "歌手", candidate{ID: "1", Title: "歌曲", Subtitle: "Live", Artists: []string{"歌手"}}, true},
		{"no artists", "歌曲", "歌手", candidate{ID: "1", Title: "歌曲"}, false},
		{"different song", "歌曲", "歌手", candidate{ID: "1", Title: "晴天", Artists: []string{"歌手"}}, false},
		{"title prefix is a different song", "晴", "歌手", candidate{ID: "1", Title: "晴天", Artists: []string{"歌手"}}, false},
		{"artist prefix is different artist", "Song", "A", candidate{ID: "1", Title: "Song", Artists: []string{"AB"}}, false},
		{"different language version", "Song (English Version)", "Artist", candidate{ID: "1", Title: "Song (Japanese Version)", Artists: []string{"Artist"}}, false},
		{"feature artist", "Song", "Artist feat. Guest", candidate{ID: "1", Title: "Song", Artists: []string{"Artist", "Guest"}}, true},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := rankCandidates(corelyrics.Request{Title: tc.title, Artist: tc.artist}, []candidate{tc.song})
			if (len(got) > 0) != tc.want {
				t.Fatalf("candidates = %v, want match %v", got, tc.want)
			}
		})
	}
}
