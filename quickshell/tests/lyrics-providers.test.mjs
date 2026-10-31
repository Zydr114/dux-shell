import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const providers = loadScript(new URL("../Common/LyricsProviders.js", import.meta.url));
const plain = value => JSON.parse(JSON.stringify(value));

test("editing with an older backend preserves unavailable providers and their slots", () => {
    const saved = [
        { id: "netease", enabled: true },
        { id: "lrclib", enabled: true },
        { id: "qqmusic", enabled: false },
        { id: "kugou", enabled: false },
        { id: "plugin_example", enabled: true }
    ];
    const visible = [{ id: "kugou", enabled: true }, { id: "lrclib", enabled: true }];
    const result = plain(providers.mergeSettings(saved, visible));
    assert.deepEqual(result, [saved[0], visible[0], saved[2], visible[1], saved[4]]);
    assert.deepEqual(plain(providers.mergeSettings(result, result)), result);
    assert.equal(saved[1].id, "lrclib");
    assert.equal(saved[3].enabled, false);
});

test("new providers append once while visible enable changes replace saved values", () => {
    const saved = [{ id: "netease", enabled: false }, { id: "lrclib", enabled: true }];
    const visible = [{ id: "netease", enabled: true }, { id: "lrclib", enabled: false }, { id: "qqmusic", enabled: true }];
    assert.deepEqual(plain(providers.mergeSettings(saved, visible)), visible);
    assert.deepEqual(plain(providers.mergeSettings(undefined, visible)), visible);
    assert.deepEqual(plain(providers.mergeSettings(saved, [])), saved);
});
