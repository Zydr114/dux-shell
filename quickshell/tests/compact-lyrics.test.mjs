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
