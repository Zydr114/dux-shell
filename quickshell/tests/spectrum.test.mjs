import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const spectrum = loadScript(new URL("../Common/Spectrum.js", import.meta.url));
const array = values => Array.from(values);

test("raw frames require the expected number of numeric bins and normalize to the configured range", () => {
    assert.deepEqual(array(spectrum.parse("0;25;100;150;", 4, 100)), [0, 0.25, 1, 1]);
    for (const frame of ["1;2;", "1;2;3;bad;", "1;2;3x;4;", "1;2;;4;"])
        assert.deepEqual(array(spectrum.parse(frame, 4, 100)), []);
    assert.equal(spectrum.parse(Array.from({ length: 45 }, (_, i) => i).join(";") + ";", 45, 100).length, 45);
});

test("aggregation preserves every input bin including fractional boundaries", () => {
    const input = Array(45).fill(0);
    input[7] = 1;
    const six = array(spectrum.aggregate(input, 6));
    assert.ok(Math.abs(six[0] - 1 / 15) < 1e-12);
    assert.ok(Math.abs(six[1] - 1 / 15) < 1e-12);
    assert.ok(six.slice(2).every(value => value === 0));
    const thirtySix = array(spectrum.aggregate(Array(45).fill(0.5), 36));
    assert.equal(thirtySix.length, 36);
    assert.ok(thirtySix.every(value => value === 0.5));
});

test("spectrum subscriptions are idempotent and retain independent consumers", () => {
    const first = {};
    const second = {};
    let tokens = [];
    tokens = spectrum.addSubscriber(tokens, first);
    tokens = spectrum.addSubscriber(tokens, first);
    tokens = spectrum.addSubscriber(tokens, second);
    tokens = spectrum.addSubscriber(tokens, null);
    assert.deepEqual(array(tokens), [first, second]);
    tokens = spectrum.removeSubscriber(tokens, first);
    tokens = spectrum.removeSubscriber(tokens, first);
    assert.deepEqual(array(tokens), [second]);
    assert.equal(spectrum.removeSubscriber(tokens, second).length, 0);
});
