import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const lyrics = loadScript(new URL("../Common/CompactLyrics.js", import.meta.url));
const part = (x, t, e, background = false) => ({ x, t, e, background });

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
