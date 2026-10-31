# Compact lyric width acceptance — 2026-11-01

Final live run: 27 cases passed. See `states.json` for the case names and measured state, `animation-samples.json` for 20 sampled animation states, and `result.json` for restoration. Screenshots contain only cropped test surfaces and synthetic media.

Environment: existing Niri / Quickshell session, HDMI-A-1, logical 2048×1152, DPR 1.25, Noto Serif CJK SC. The acceptance run temporarily used a 440px maximum and a 24px threshold, then exercised 360px and zero threshold. The user's persisted maximum remains 560px.

`_widthProbe` is temporary diagnostic output, removed after acceptance. It records the visible lyric's `Text.truncated`, natural and retained widths, the rendered surface width, the raw spring width, the compact cap, and the expanded-transition latch. `violations` counts rendered-width changes above an active finite compact cap; `overshoots` counts raw spring-width changes above that cap. Across this run their maximum cumulative values were 0 and 173 respectively. These counters run on property changes and are separate from the 20 IPC snapshots. Expanded and collapsing player geometry intentionally has no compact cap until the transition settles.

The fixture used local LRC and temporary MPRIS players; existing players were excluded temporarily and received no playback controls. No extra shell, compositor, or display server was started. Configuration and cache bytes were restored exactly, output volume restored, and the fixture exited. Temporary diagnostics were removed; DIsland.qml had no final change, and DIslandSurface.qml was restored to the exact accepted final implementation.

Final source validation: `make lint-qml`, `make test-qml` (Qt 31, lock 38 and complete logic suite), parsing every changed QML with qmlformat, `git diff --check`, and idempotent regeneration of the settings search index all passed. The compact-lyrics Common JS file has 7 tests, including 5 width-policy tests. `source-sha256.json` identifies the accepted source and generated search index.

`deployment.json` records the final reload of the existing user service and readiness of its new Quickshell process, including source path, IPC state, 560px maximum, 24px effective threshold, and matching source hashes. Settings bytes stayed unchanged during this final verification. The Go binary was unchanged because this patch modifies QML and JS only. The regenerated settings search index also refreshes previously stale entries from the existing source.

The live log had no references to the changed components and no binding loops. Existing plugin deprecations, missing icons and initialization warnings remain; global warning-free startup is not claimed. This is finite single-screen acceptance, not a long-term CPU/memory benchmark or validation of other compositors, screens, vertical or dot layouts.

Raw temporary harness, logs and private configuration snapshots remain outside the repository at `/tmp/dms-lyrics-width-20261101-r3-e_pd899w/`. The pre-development backup is under `~/.local/state/dms/backups/lyrics-width-20261101-000519/`.
