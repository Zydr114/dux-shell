import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";
import { loadScript } from "./qml-script.mjs";

const compact = loadScript(new URL("../Common/CompactLyrics.js", import.meta.url));

function controller() {
    const source = readFileSync(new URL("../Services/LyricsController.qml", import.meta.url), "utf8");
    const context = vm.createContext({
        enabled: true,
        synced: true,
        playing: false,
        rate: 1,
        track: { length: 20 },
        lines: [],
        cueTimes: [],
        focusedGroups: [],
        wordRevision: 0,
        at: 0,
        currentTime() { return context.at; },
        tick: { stop() {}, start() {} },
    });
    for (const name of ["prepareLines", "wordsFor", "resync", "wordTiming", "indexFor"]) {
        const match = source.match(new RegExp(`^    function ${name}\\([^)]*\\) \\{\\n[\\s\\S]*?^    \\}`, "m"));
        assert.ok(match, `missing ${name}`);
        vm.runInContext(match[0], context);
    }
    return context;
}

test("ended lyrics clear focus and word timing while retaining the transcript position", () => {
    const lyrics = controller();
    lyrics.lines = lyrics.prepareLines([
        { t: 1, e: 3, x: "first", w: [{ t: 1, e: 3, x: "first" }] },
        { t: 10, e: 12, x: "next", w: [{ t: 10, e: 12, x: "next" }] },
    ], {});
    for (const [at, position, focused, text, word] of [
        [0, -1, [], "", -1],
        [1, 0, [0], "first", 1],
        [3, 0, [], "", -1],
        [9, 0, [], "", -1],
        [10, 1, [1], "next", 10],
        [12, 1, [], "", -1],
    ]) {
        lyrics.at = at;
        lyrics.resync();
        assert.equal(lyrics.activeIndex, position, `scroll position at ${at}`);
        assert.deepEqual(Array.from(lyrics.focusedGroups), focused, `focused vocals at ${at}`);
        assert.equal(lyrics.wordTime, word, `word cue at ${at}`);
        assert.equal(compact.lineText(lyrics.lines, lyrics.activeIndex, lyrics.sampleTime, 4, lyrics.focusedGroups), text, `Clavis lyric at ${at}`);
    }
});

test("paused short-gap display does not extend focus, word timing, or source intervals", () => {
    const lyrics = controller();
    const source = [
        { t: 30, e: 31.728, x: "before", w: [{ t: 30, e: 30.9, x: "be" }, { t: 30.9, e: 32, x: "fore" }] },
        { t: 33.526, e: 35, x: "after", w: [{ t: 33.526, e: 35, x: "after" }] },
    ];
    const original = JSON.stringify(source);
    lyrics.lines = lyrics.prepareLines(source, {});
    const prepared = JSON.stringify(lyrics.lines);
    let scheduled = 0;
    lyrics.tick = { stop() {}, start() { scheduled++; } };
    for (const [at, index, focused, text, word, end] of [
        [31.7, 0, [0], "before", 30.9, 31.728],
        [31.728, 0, [], "before", -1, -1],
        [32.8, 0, [], "before", -1, -1],
        [33.526, 1, [1], "after", 33.526, 35],
        [35, 1, [], "", -1, -1],
        [31.728, 0, [], "before", -1, -1],
        [29, -1, [], "", -1, -1],
        [32.8, 0, [], "before", -1, -1],
    ]) {
        lyrics.at = at;
        lyrics.resync();
        assert.equal(lyrics.activeIndex, index, `scroll position at ${at}`);
        assert.deepEqual(Array.from(lyrics.focusedGroups), focused, `focused vocals at ${at}`);
        assert.equal(lyrics.wordTime, word, `word cue at ${at}`);
        assert.equal(lyrics.wordEnd, end, `word end at ${at}`);
        assert.equal(compact.lineText(lyrics.lines, lyrics.activeIndex, lyrics.sampleTime, 4, lyrics.focusedGroups), text, `compact display at ${at}`);
    }
    assert.equal(scheduled, 0, "paused samples do not schedule playback ticks");
    assert.equal(JSON.stringify(source), original);
    assert.equal(JSON.stringify(lyrics.lines), prepared);
});

test("overlapping vocals remain current after a later group ends", () => {
    const lyrics = controller();
    lyrics.lines = lyrics.prepareLines([
        { t: 1, e: 8, x: "lead", voice: "a", w: [{ t: 1, e: 8, x: "lead" }] },
        { t: 2, e: 4, x: "reply", voice: "b", w: [{ t: 2, e: 4, x: "reply" }] },
    ], {});
    lyrics.at = 5;
    lyrics.resync();
    assert.equal(lyrics.activeIndex, 1);
    assert.deepEqual(Array.from(lyrics.focusedGroups), [0]);
    assert.equal(lyrics.wordTime, 1);
    assert.equal(lyrics.wordEnd, 8);
    assert.equal(compact.lineText(lyrics.lines, lyrics.activeIndex, lyrics.sampleTime, 4, lyrics.focusedGroups), "lead");
});

test("word lookup respects the part interval when asked for an ended or future vocal", () => {
    const lyrics = controller();
    const part = { t: 1, e: 3, cues: [{ t: 1, e: 5, x: "sing" }] };
    for (const at of [0, 3, 4]) {
        const timing = lyrics.wordTiming(part, at);
        assert.equal(timing.t, -1);
        assert.equal(timing.e, -1);
    }
    const timing = lyrics.wordTiming(part, 2);
    assert.equal(timing.t, 1);
    assert.equal(timing.e, 3);
});
