import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const expiry = loadScript(new URL("../Common/TransientExpiry.js", import.meta.url));

test("notification progress follows the actual deadline and clamps clock movement", () => {
    assert.equal(expiry.remainingRatio(1000, 6000, 1000), 1);
    assert.equal(expiry.remainingRatio(1000, 6000, 3000), 0.6);
    assert.equal(expiry.remainingRatio(1000, 6000, 6000), 0);
    assert.equal(expiry.remainingRatio(1000, 6000, 7000), 0);
    assert.equal(expiry.remainingRatio(1000, 6000, 0), 1);
});

test("persistent or cleared deadlines never manufacture a countdown", () => {
    for (const [start, end, now] of [[0, 0, 0], [1000, 0, 3000], [1000, 1000, 1000], [0, Infinity, 1000], [0, 5000, NaN]])
        assert.equal(expiry.remainingRatio(start, end, now), 0);
});

test("resuming or deduplicating renews the complete timeout interval", () => {
    assert.equal(expiry.remainingRatio(1000, 6000, 4000), 0.4);
    assert.equal(expiry.remainingRatio(4000, 9000, 4000), 1);
    assert.equal(expiry.remainingRatio(4000, 9000, 6500), 0.5);
});
