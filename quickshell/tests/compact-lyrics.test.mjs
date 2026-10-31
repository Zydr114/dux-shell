import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const lyrics = loadScript(new URL("../Common/CompactLyrics.js", import.meta.url));

test("short gap settings disable holding and bound custom durations", () => {
    for (const value of [1, 4, 10, NaN, Infinity, null])
        assert.equal(lyrics.shortGapSeconds(false, value), 0);
    for (const [value, expected] of [[1, 1], [7, 7], [10, 10], [-2, 1], [20, 10], [NaN, 4], [Infinity, 4], [null, 4], ["7", 4]])
        assert.equal(lyrics.shortGapSeconds(true, value), expected);

    const lines = [
        { parts: [{ x: "previous", t: 1, e: 2 }] },
        { parts: [{ x: "next", t: 8, e: 9 }] }
    ];
    assert.equal(lyrics.lineText(lines, 0, 5, lyrics.shortGapSeconds(false, 10)), "");
    assert.equal(lyrics.lineText(lines, 0, 5, lyrics.shortGapSeconds(true, 4)), "");
    assert.equal(lyrics.lineText(lines, 0, 5, lyrics.shortGapSeconds(true, 6)), "previous");
});

test("custom interlude text preserves an empty choice and literal Unicode content", () => {
    for (const value of ["", "   ", "\n\t"])
        assert.equal(lyrics.interludeText(value), "");
    assert.equal(lyrics.interludeText("  间奏 🎵  <3  "), "间奏 🎵 <3");
    assert.equal(lyrics.interludeText("first\nsecond\tpart"), "first second part");
    assert.equal(lyrics.interludeText("🎵".repeat(129)), "🎵".repeat(64));
    assert.equal(lyrics.interludeText("a".repeat(127) + "🎵"), "a".repeat(127));
    for (const value of [null, undefined, false, 42, {}])
        assert.equal(lyrics.interludeText(value), "♪");
});
const part = (x, t, e, background = false) => ({ x, t, e, background });
const group = (...parts) => ({ t: Math.min(...parts.map(part => part.t)), e: Math.max(...parts.map(part => part.e)), parts });

test("compact lyrics show the active lead voices and flatten multiline text", () => {
    const lines = [{ parts: [part(" 第一行\n第二行 ", 1, 5), part("echo", 1, 5, true), part("next", 4, 6)] }];
    assert.equal(lyrics.lineText(lines, 0, 1), "第一行 第二行");
    assert.equal(lyrics.lineText(lines, 0, 4), "第一行 第二行 · next");
    assert.equal(lyrics.lineText(lines, 0, 5), "next");
});

test("interludes and seek-before-first-line clear the previous lyric without inventing timestamps", () => {
    const lines = [{ parts: [part("lead", 2, 4), part("echo", 4, 5, true)] }];
    assert.equal(lyrics.lineText(lines, -1, 0), "");
    assert.equal(lyrics.lineText(lines, 0, 1), "");
    assert.equal(lyrics.lineText(lines, 0, 4), "echo");
    assert.equal(lyrics.lineText(lines, 0, 5), "");
    assert.equal(lyrics.lineText([], 0, 10), "");
});

test("short gaps retain text after removed blank cues and explicit word-timed ends", () => {
    const cases = [
        [46.57, 52.08, 52.66],
        [37, 39.73, 39.74],
        [30, 31.728, 33.526],
        [10, 12, 15], // Consecutive blank cues have already been removed by the provider cleanup.
    ];
    for (const [start, end, next] of cases) {
        const lines = [group(part("previous", start, end)), group(part("next", next, next + 2))];
        const source = JSON.stringify(lines);
        assert.equal(lyrics.lineText(lines, 0, end), "", `opt-in at ${end}`);
        for (const at of [end, (end + next) / 2, next - 0.0001])
            assert.equal(lyrics.lineText(lines, 0, at, 4), "previous", `gap ${end}–${next}, sampled ${at}`);
        assert.equal(lyrics.lineText(lines, 1, next, 4), "next");
        assert.equal(JSON.stringify(lines), source);
    }
});

test("only known interior gaps no longer than the complete threshold retain text", () => {
    for (const [end, next, expected] of [
        [4, 8, "previous"],
        [5.06, 9.06, "previous"],
        [14.04, 18.04, "previous"],
        [4, 8.001, ""],
        [5.06, 9.061, ""],
        [14.04, 18.041, ""],
        [4, 16, ""],
    ]) {
        const lines = [group(part("previous", end - 2, end)), group(part("next", next, next + 2))];
        assert.equal(lyrics.lineText(lines, -1, end - 3, 4), "", "intro");
        assert.equal(lyrics.lineText(lines, 0, end, 4), expected, `gap ${end}–${next} start`);
        assert.equal(lyrics.lineText(lines, 0, next - 0.001, 4), expected, `gap ${end}–${next} end`);
        assert.equal(lyrics.lineText(lines, 1, next, 4), "next");
        assert.equal(lyrics.lineText(lines, 1, next + 2, 4), "", "outro");
    }
    const lines = [group(part("previous", 1, 2)), group(part(" \n ", 3, 4)), group(part("next", 8, 9))];
    assert.equal(lyrics.lineText(lines, 0, 2.5, 4), "", "blank cue does not turn a long gap into a short one");
    assert.equal(lyrics.lineText(lines.slice(0, 2), 0, 2.5, 4), "", "blank cue does not create an interior gap");
});

test("current vocals take precedence over held text across overlapping groups", () => {
    const lines = [
        group(part("lead", 1, 8)),
        group(part("reply", 2, 4)),
        group(part("next", 9, 12)),
    ];
    assert.equal(lyrics.lineText(lines, 1, 2.5, 4, [0, 1]), "reply");
    assert.equal(lyrics.lineText(lines, 1, 5, 4, [0]), "lead");
    assert.equal(lyrics.lineText(lines, 1, 8.5, 4), "lead", "hold the voice that actually ended last");
    assert.equal(lyrics.lineText(lines, 2, 9, 4, [2]), "next");

    const background = [
        group(part("lead", 1, 3)),
        group(part(" \n ", 2, 4), part("harmony", 2, 4, true)),
        group(part("next", 6, 8)),
    ];
    assert.equal(lyrics.lineText(background, 1, 2.5, 4, [0, 1]), "lead", "active lead outranks background");
    assert.equal(lyrics.lineText(background, 1, 3.5, 4, [1]), "harmony", "active background outranks an ended lead");
    assert.equal(lyrics.lineText(background, 1, 4.5, 4), "harmony");
});

test("held chorus text preserves repeated lead voices and filters background voices", () => {
    const lines = [
        group(part(" refrain ", 1, 3), part("refrain", 1, 3), part("echo", 1, 3, true)),
        group(part("next", 5, 7)),
    ];
    assert.equal(lyrics.lineText(lines, 0, 3.5, 4), "refrain · refrain");
});

test("a later part in an earlier group can end the held interval", () => {
    const lines = [
        group(part("first", 1, 2), part("return", 5, 6)),
        group(part("reply", 3, 4)),
    ];
    assert.equal(lyrics.lineText(lines, 1, 4.5, 4), "reply");
    assert.equal(lyrics.lineText(lines, 1, 5, 4, [0]), "return");
    assert.equal(lyrics.lineText(lines, 1, 6, 4), "");
});

test("holding text is independent of seek order and replaced track arrays", () => {
    const first = [group(part("first", 2, 4)), group(part("second", 5, 6))];
    const second = [group(part("other", 10, 11)), group(part("later", 13, 14))];
    for (const [index, at, expected] of [
        [0, 4.5, "first"],
        [1, 5.5, "second"],
        [-1, 1.5, ""],
        [0, 3, "first"],
        [0, 4.5, "first"],
        [1, 7, ""],
        [0, 4.5, "first"],
    ])
        assert.equal(lyrics.lineText(first, index, at, 4), expected, `seek to ${at}`);
    assert.equal(lyrics.lineText(second, -1, 4.5, 4), "");
    assert.equal(lyrics.lineText(second, 0, 11.5, 4), "other");
    assert.equal(lyrics.lineText([], 0, 11.5, 4), "");
    assert.equal(lyrics.lineText(first, 0, 4.5, 4), "first");
});

test("compact lyric width grows with headroom and retains the last adopted width", () => {
    let width = lyrics.resolveWidth(0, 100, 60, 400, 20);
    assert.equal(width, 120);
    for (const required of [101, 110, 119, 120]) {
        width = lyrics.resolveWidth(width, required, 60, 400, 20);
        assert.equal(width, 120);
    }
    width = lyrics.resolveWidth(width, 121, 60, 400, 20);
    assert.equal(width, 141);
    assert.equal(lyrics.resolveWidth(width, 102, 60, 400, 20), 141);
    assert.equal(lyrics.resolveWidth(width, 101, 60, 400, 20), 121);
});

test("compact lyric width respects changed caps and never holds a width that truncates fitting text", () => {
    assert.equal(lyrics.resolveWidth(120, 121, 60, 400, 20), 141);
    assert.equal(lyrics.resolveWidth(120, 500, 60, 200, 20), 200);
    assert.equal(lyrics.resolveWidth(200, 500, 60, 150, 20), 150);
    assert.equal(lyrics.resolveWidth(150, 500, 60, 300, 20), 300);
    assert.equal(lyrics.resolveWidth(120, 80, 60, 100, 20), 100);
    assert.equal(lyrics.resolveWidth(120, 80, 150, 300, 20), 150);
});

test("zero threshold tracks exact pixel width without fractional churn", () => {
    assert.equal(lyrics.resolveWidth(120, 100, 60, 400, 0), 100);
    assert.equal(lyrics.resolveWidth(100, 121, 60, 400, 0), 121);
    assert.equal(lyrics.resolveWidth(100.1, 100.2, 60, 400, 0), 101);
    assert.equal(lyrics.resolveWidth(101, 100.9, 60, 400, 0), 101);
    assert.equal(lyrics.resolveWidth(0, 100.1, 60.1, 400.1, 10.1), 112);
});

test("interlude width retention can be disabled and still accommodates custom text", () => {
    assert.equal(lyrics.resolveWidth(240, 100, 60, 400, 24, true), 240);
    assert.equal(lyrics.resolveWidth(240, 100, 60, 400, 24, false), 124);
    assert.equal(lyrics.resolveWidth(240, 300, 60, 400, 24, true), 324);
    assert.equal(lyrics.resolveWidth(324, 100, 60, 400, 24, true), 324);
    assert.equal(lyrics.resolveWidth(324, 100, 60, 180, 24, true), 180);
    assert.equal(lyrics.resolveWidth(240, 100, 60, 400, 0, true), 240);
    assert.equal(lyrics.resolveWidth(240, 100, 60, 400, 0, false), 100);
    assert.equal(lyrics.resolveWidth(0, 100, 60, 400, 24, true), 124);
});

test("fractional screen budgets remain hard caps when rounding required pixels", () => {
    assert.equal(lyrics.resolveWidth(0, 500, 60, 359.2, 20), 359);
    assert.equal(lyrics.resolveWidth(360, 340, 60, 359.2, 20), 359);
    assert.equal(lyrics.resolveWidth(0, 500, 360.1, 359.2, 20), 359);
    assert.equal(lyrics.resolveWidth(100, 99.5, 60, 99.9, 0), 99);
    assert.equal(lyrics.resolveWidth(100, 100, 60, 0.9, 20), 0);
});

test("compact lyric width normalizes invalid sizes and conflicting bounds", () => {
    const cases = [
        [NaN, 100, 60, 400, 20, 120],
        [Infinity, 100, 60, 400, 20, 120],
        [-10, 100, 60, 400, 20, 120],
        [120, NaN, 60, 400, 20, 80],
        [120, Infinity, 60, 400, 20, 80],
        [120, -10, 60, 400, 20, 80],
        [0, 100, 200, 80, 20, 80],
        [120, 100, 60, 0, 20, 0],
        [120, 100, 60, -10, 20, 0],
        [0, 100, 60, NaN, 20, 60],
        [0, 100, 60, Infinity, 20, 60],
        [0, 100, NaN, 400, 20, 120],
        [0, 100, 60, 400, NaN, 100],
        [0, 100, 60, 400, Infinity, 100],
        [0, 100, 60, 400, -20, 100],
        [undefined, undefined, undefined, undefined, undefined, 0]
    ];
    for (const [current, required, minimum, maximum, threshold, expected] of cases)
        assert.equal(lyrics.resolveWidth(current, required, minimum, maximum, threshold), expected);
});
