import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const geometry = loadScript(new URL("../Common/MediaGeometry.js", import.meta.url));

test("media bodies stay at their natural height outside the dashboard row grid", () => {
    for (const [width, height] of [[540, 210], [640, 240]]) {
        const size = geometry.fitBody(width, height, 1920, 1080, 36);
        assert.equal(size.width, width);
        assert.equal(size.bodyHeight, height);
        assert.equal(size.height, height + 36);
    }
});

test("screen limits include the handle and narrow bodies keep a usable control height", () => {
    const narrow = geometry.fitBody(640, 240, 320, 500, 36);
    assert.equal(narrow.width, 320);
    assert.equal(narrow.bodyHeight, 240);
    assert.equal(narrow.height, 276);
    const short = geometry.fitBody(640, 240, 1920, 200, 36);
    assert.equal(short.bodyHeight, 164);
    assert.equal(short.height, 200);
    for (const limit of [0, NaN, undefined]) {
        const size = geometry.fitBody(540, 210, limit, limit, 0);
        assert.equal(size.width, 540);
        assert.equal(size.height, 210);
    }
});
