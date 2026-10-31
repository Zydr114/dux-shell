import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const lyrics = loadScript(new URL("../Common/LyricsText.js", import.meta.url));

test("plain lyrics remove blank rows and normalize all newline forms", () => {
    assert.deepEqual(Array.from(lyrics.plainLines("\ufeff  第一行  \r\n\t\r\n\r第二行\n\u3000\n")), ["第一行", "第二行"]);
    assert.deepEqual(Array.from(lyrics.plainLines(" \t\r\n\u3000\r")), []);
});

test("plain lyrics preserve repeated lines, inner spacing and punctuation", () => {
    assert.deepEqual(Array.from(lyrics.plainLines("  sing  along!\n\nsing  along!\n (间奏) ")), ["sing  along!", "sing  along!", "(间奏)"]);
});
