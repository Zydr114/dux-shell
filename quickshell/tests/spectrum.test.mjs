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

test("compact spectrum keeps comparable levels when the shared sampler changes scale", () => {
    for (const [values, maximum] of [[Array(6).fill(500), 1000], [Array(6).fill(22.5), 45]]) {
        const five = array(spectrum.normalizedBins(values, maximum, 5));
        assert.equal(five.length, 5);
        assert.ok(five.every(value => Math.abs(value - 0.5) < 1e-12));
    }
    assert.deepEqual(array(spectrum.normalizedBins([-5, NaN, 2000, 250], 1000, 4)), [0, 0, 1, 0.25]);
    assert.deepEqual(array(spectrum.normalizedBins([100], 0, 5)), []);
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

test("Caelestia peak bins retain isolated frequencies without altering ordinary averaging", () => {
    const input = Array(45).fill(0);
    input[7] = 0.9;
    input[44] = 1;
    const ring = array(spectrum.peakBins(input, 36));
    assert.equal(ring.length, 36);
    assert.equal(ring[6], 0.9);
    assert.equal(ring[35], 1);
    assert.equal(ring.filter(value => value > 0).length, 2);
    assert.ok(spectrum.aggregate(input, 6)[0] < 0.9);
    assert.deepEqual(array(spectrum.peakBins([-1, NaN, 3, 0.25], 2)), [0, 1]);
});

test("Caelestia subscriptions request shared sampling independently of ordinary visualizers", () => {
    const cases = [
        [0, 0, false, false, 0],
        [1, 0, false, false, 0],
        [1, 0, true, false, 6],
        [0, 1, false, false, 45],
        [2, 2, false, false, 45],
        [2, 1, true, false, 45],
        [2, 0, true, true, 0],
        [2, 2, true, true, 0],
        [0, 1, false, true, 0]
    ];
    for (const [ordinary, covers, enabled, reduced, expected] of cases)
        assert.equal(spectrum.requestedBars(ordinary, covers, enabled, reduced), expected);

    const cover = {};
    let tokens = spectrum.addSubscriber([], cover);
    assert.equal(spectrum.requestedBars(1, tokens.length, false, false), 45);
    tokens = spectrum.removeSubscriber(tokens, cover);
    assert.equal(spectrum.requestedBars(1, tokens.length, true, false), 6);
    assert.equal(spectrum.requestedBars(1, tokens.length, false, false), 0);
});

test("automatically gained spectrum frames stay within the ordinary visualizer display range", () => {
    assert.deepEqual(array(spectrum.ordinaryBins(Array(45).fill(1))), Array(6).fill(45));
    assert.deepEqual(array(spectrum.ordinaryBins(Array(45).fill(0.5))), Array(6).fill(23));
    const quiet = Array(45).fill(0);
    quiet[7] = 1;
    const bins = array(spectrum.ordinaryBins(quiet));
    assert.deepEqual(bins, [3, 3, 0, 0, 0, 0]);
});
