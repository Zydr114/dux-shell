# Short lyric gap acceptance — 2026-11-01

Implementation commit: `70d5f2c8161645f2b686fd0035808faa3790f12f`.

Clavis holds the previous displayed text when the complete interval to the next valid vocal is at most 4 seconds. Longer gaps, the intro and the outro retain the music symbol. Actual active voices take precedence; real lyric end times, controller focus and word timing remain unchanged. The shared metric is `DashMetrics.mediaLyricsShortGapSeconds`.

## Logic and real provider samples

The focused Common/Services suite passed 17 tests. The same assertions against the previous helper produced 9 passes and 8 expected failures; see `current-result.txt` and `baseline-result.txt`. Tests cover anonymized real timing structures, exact and fractional 4-second boundaries, a 1-millisecond excess, overlapping and delayed vocals, background voices, repeated chorus text, paused sampling, seeks and replacing tracks. They load only Common JS and Services functions, without UI component mocks or a new shell/display server.

The earlier live HTTP retrieval used the actual provider search, matching and parsers: 10 Netease requests and 2 QQ Music requests, all successful. Their outputs were passed through the current backend postprocessor and replayed with the current Services/Common functions. A production-cache Kugou sample was also replayed. `real-sample-replay.json` records the result without song lyric text:

| Samples | Previous interior gaps | Gaps bridged | Remaining longer gaps |
| --- | ---: | ---: | ---: |
| Netease, 10 songs | 93 | 71 | 22 |
| QQ Music, 2 songs | 27 | 26 | 1 |
| Kugou, Staple Stable cache | 64 | 62 | 2 |

Every held sample had no active vocal focus or word highlight. Provider data and prepared time intervals remained unchanged. These counts are pure-function replays of real provider data, separate from desktop acceptance and live listening.

`make test-qml` passed Qt 31, lock 38 and the complete logic suite. `make lint-qml`, parsing both changed QML files with qmlformat, and `git diff --check` passed. See the saved logs and `source-sha256.json`.

## Existing desktop acceptance

Environment: existing Niri session, HDMI-A-1, logical 2048×1152, DPR 1.25. A temporary synthetic MPRIS player and local LRC reproduced the real gap structures; real players were excluded temporarily and received no playback controls. No extra shell, compositor or display server was started for these checks.

The harness completed 13 recorded states and 12 cropped screenshots. Visual inspection confirmed the expected text or music symbol in every screenshot: intro, active line, 0.58-second hold, next line, exactly 4-second hold, 4.001-second gap, longer gap, final line, outro, seeking back into a gap, paused gap, and return from the expanded player. The expanded player also opened successfully. See `live-states.json`, `live-result.json` and `visual-review.json`.

![A short pause keeps the previous lyric](short-gap-held.png)

![Exactly four seconds keeps the previous lyric](exact-four-second-gap-held.png)

![A longer gap keeps the music symbol](gap-over-four-seconds.png)

Settings and shared cache bytes matched their backups when the fixture exited. The fixture was removed. During subsequent read-only health checks the real player independently changed track and began playing; that playback and later cache activity were preserved. `deployment.json` distinguishes fixture cleanup from this later activity. Full desktop captures were deleted after cropping. Private settings, raw provider lyrics and the temporary fixture remain outside the repository at `/tmp/dms-lyrics-gaps-20261101-rk97go16/`; pre-deployment backups are under `~/.local/state/dms/backups/lyrics-gaps-20261101-005204/`.

## Build, startup and resource boundary

`make build` embedded the accepted QML and produced a clean build at the implementation commit. The user binary was replaced atomically and `dms.service` restarted. The installed and built binary hashes match; the service is active, its sole Quickshell process loads this checkout, and IPC reports Clavis lyrics presentation. See `build.log` and `deployment.json`.

The helper uses current/focused groups while vocals are active. A song-wide fallback runs only when an empty display interval needs its latest ended and next valid vocal; it is driven by existing cue events. There are no added timers, processes, persistent indexes or frame-driven scans. DBar, the expanded transcript and lyric OSD retain their original timing paths. This run does not claim a long-term CPU/memory benchmark, frame-by-frame animation measurement, other compositor/layout acceptance or a listening test of every provider sample. No warnings mentioning the changed components or binding loops were found in the startup/acceptance log; global warning-free startup is not claimed.
