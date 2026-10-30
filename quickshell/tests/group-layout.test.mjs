import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const groups = loadScript(new URL("../Modules/DBar/GroupLayout.js", import.meta.url));
const overflow = loadScript(new URL("../Modules/DBar/OverflowLayout.js", import.meta.url));
const center = loadScript(new URL("../Modules/DBar/CenterLayout.js", import.meta.url));
const plain = value => JSON.parse(JSON.stringify(value));
const widget = (size, mode = "bar", extra = {}) => ({ size, mode, ...extra });
const grouped = (size, extra = {}) => widget(size, "bar", { groupId: "system", groupPadding: 8, groupSpacing: 6, groupMode: "auto", ...extra });
const solve = (left, center = [], right = [], options = {}, previous = {}) => overflow.resolve({ left, center, right }, {
    length: 400, spacing: 4, triggerSize: 30, restoreMargin: 8, ...options
}, previous);

test("cross metrics keep content, outline and padding inside the available bar thickness", () => {
    const cases = [
        { input: [28, 48, 1, 4], expected: [28, 1, 4, 38] },
        { input: [60, 32, 2, 8], expected: [28, 2, 0, 32] },
        { input: [16, 48, 2, 100], expected: [16, 2, 14, 48] },
        { input: [28, 32, 100, 8], expected: [0, 16, 0, 32] },
        { input: [17.5, 24.5, 0.75, 2.25], expected: [17.5, 0.75, 2.25, 23.5] },
        { input: [17.5, 24.5, 0.75, 3], expected: [17.5, 0.75, 2.75, 24.5] },
        { input: [-5, 32, -1, -2], expected: [0, 0, 0, 0] },
        { input: [NaN, 32, Infinity, 4], expected: [0, 0, 4, 8] },
        { input: [28, 0, 1, 4], expected: [0, 0, 0, 0] },
        { input: [28, Infinity, 1, 4], expected: [0, 0, 0, 0] },
        { input: [28, NaN, 1, 4], expected: [0, 0, 0, 0] }
    ];
    for (const { input, expected } of cases) {
        const result = groups.crossMetrics(...input);
        assert.deepEqual(plain(result), { widgetThickness: expected[0], outline: expected[1], padding: expected[2], thickness: expected[3] });
        assert.equal(result.widgetThickness + 2 * result.outline + 2 * result.padding, result.thickness);
        assert.ok(result.thickness <= groups.nonnegative(input[1]));
        assert.ok(Object.values(result).every(value => Number.isFinite(value) && value >= 0));
    }
});

test("groups measure only live occurrences and do not join across another configured unit", () => {
    const entries = [grouped(40, { widgetId: "clock", min: 20 }), grouped(0), grouped(60, { widgetId: "clock", min: 30 }), widget(0), grouped(15)];
    const original = structuredClone(entries);
    const units = groups.pack(entries);
    assert.equal(units.length, 3);
    assert.deepEqual(plain(units[0].members), [0, 2]);
    assert.deepEqual(plain(units[0].offsets), [8, 54]);
    assert.equal(units[0].size, 122);
    assert.equal(units[0].min, 72);
    assert.equal(units[1].size, 0);
    assert.equal(units[2].size, 31);
    assert.deepEqual(entries, original);
});

test("section positions include outer padding and inner gaps without padding each member", () => {
    const entries = [widget(10), grouped(20, { groupSpacing: 4 }), grouped(30, { groupSpacing: 4 }), widget(40)];
    const result = overflow.section(entries, [], 6, 30, 4);
    assert.deepEqual(plain(result.sizes), [10, 70, 40]);
    assert.deepEqual(plain(result.positions), [0, 24, 48, 92]);
    assert.deepEqual(plain(result.memberUnits), [0, 1, 1, 2]);
    assert.deepEqual(plain(result.memberOffsets), [0, 8, 32, 0]);
    assert.deepEqual(plain(result.inlineIndices), [0, 1, 2, 3]);
    assert.equal(result.units[1].position, 16);
    assert.equal(result.totalSize, 132);
    const centered = center.resolve(result.sizes, 400, 6, "index", undefined, result.anchor);
    assert.equal(centered.positions[1] + result.sizes[1] / 2, 200);
    assert.equal(centered.positions[1] + result.memberOffsets[2], 197);
});

test("an overflow trigger inside a group snaps before the whole group", () => {
    const entries = [widget(10), grouped(20, { groupSpacing: 4 }), grouped(30, { groupSpacing: 4 }), widget(40)];
    const result = overflow.section(entries, [3], 6, 30, 2);
    assert.deepEqual(plain(result.indices), [0, -1, 1, 3]);
    assert.deepEqual(plain(result.sizes), [10, 30, 70, null]);
    assert.equal(result.buttonPosition, 16);
    assert.deepEqual(plain(result.positions), [0, 60, 84, null]);
    assert.deepEqual(plain(result.inlineIndices), [0, -1, 1, 2]);
    const hidden = overflow.section(entries, [2], 6, 30, 2);
    assert.deepEqual(plain(hidden.positions), [0, null, null, 52]);
    assert.equal(hidden.units[2].size, 0);
    assert.deepEqual(plain(hidden.units[2].members), []);
});

test("a group yields as one unit and its placement overrides member placements", () => {
    const entries = [widget(100), grouped(40), grouped(40, { mode: "always" })];
    const result = solve(entries, [widget(80)]);
    assert.equal(result.fits, true);
    assert.deepEqual(plain(result.hidden.left), [1, 2]);
    assert.equal(result.layouts.left.totalSize, 134);
    const pinned = solve([grouped(100, { mode: "auto", groupMode: "bar" }), grouped(100, { mode: "auto", groupMode: "bar" })], [widget(80)], [], { length: 200 });
    assert.equal(pinned.fits, false);
    assert.deepEqual(plain(pinned.hidden.left), []);
    const always = solve([grouped(10, { groupMode: "always" }), grouped(20, { groupMode: "always" })]);
    assert.deepEqual(plain(always.hidden.left), [0, 1]);
});

test("flexible group members receive exactly the available content size after shell and gaps", () => {
    const entries = [widget(100), grouped(100, { min: 20 }), grouped(100, { min: 30 })];
    const result = solve(entries, [widget(80)], [], { length: 500 });
    assert.equal(result.fits, true);
    assert.deepEqual(plain(result.hidden.left), []);
    assert.deepEqual(plain(result.sizes.left), [100, 36, 44]);
    const unit = result.layouts.left.units[1];
    assert.equal(unit.size, result.sizes.left[1] + result.sizes.left[2] + 8 * 2 + 6);
    assert.equal(unit.size, 102);
    assert.equal(unit.min, 72);
    assert.equal(result.layouts.left.totalSize, 206);
});

test("restoration keeps the whole group hidden until its minimum plus margin fits", () => {
    const entries = [widget(100), grouped(100, { min: 20, groupSpacing: 4 }), grouped(100, { min: 20, groupSpacing: 4 })];
    const previous = { left: [1, 2] };
    const narrow = solve(entries, [widget(80)], [], { length: 420 }, previous);
    assert.deepEqual(plain(narrow.hidden.left), [1, 2]);
    const restored = solve(entries, [widget(80)], [], { length: 432 }, previous);
    assert.equal(restored.fits, true);
    assert.deepEqual(plain(restored.hidden.left), []);
    assert.deepEqual(plain(restored.sizes.left), [100, 24, 24]);
});

test("fractional minimums are respected before deciding whether a group fits", () => {
    const entries = [widget(100), grouped(100, { min: 20.25 }), grouped(100, { min: 20.25 })];
    const fitted = solve(entries, [widget(80)], [], { length: 421 });
    assert.equal(fitted.fits, true);
    assert.deepEqual(plain(fitted.hidden.left), []);
    assert.deepEqual(plain(fitted.sizes.left), [100, 20.25, 20.25]);
    assert.equal(fitted.layouts.left.totalSize, 166.5);
    const narrow = solve(entries, [widget(80)], [], { length: 420.5 });
    assert.equal(narrow.fits, true);
    assert.deepEqual(plain(narrow.hidden.left), [1, 2]);
});

test("invisible members consume no inner gap and an empty group has no shell or overflow button", () => {
    const entries = [grouped(20, { groupMode: "always" }), grouped(0, { groupMode: "always" }), grouped(30, { groupMode: "always" })];
    const visible = solve(entries);
    assert.deepEqual(plain(visible.hidden.left), [0, 2]);
    assert.equal(visible.layouts.left.totalSize, 30);
    const empty = solve(entries.map(entry => ({ ...entry, size: 0 })), [], [], {}, visible.hidden);
    assert.equal(empty.fits, true);
    assert.equal(empty.layouts.left.totalSize, 0);
    assert.equal(empty.layouts.left.buttonPosition, null);
    assert.deepEqual(plain(empty.hidden.left), []);
    assert.deepEqual(plain(empty.layouts.left.positions), [null, null, null]);
});

test("non-finite or negative metrics cannot poison group bounds or member allocation", () => {
    const entries = [grouped(NaN, { groupPadding: Infinity, groupSpacing: -5 }), grouped(Infinity), grouped(-1), grouped(20, { min: -5 })];
    const unit = groups.pack(entries)[0];
    assert.equal(unit.padding, 0);
    assert.equal(unit.spacing, 0);
    assert.equal(unit.size, 20);
    assert.equal(unit.min, 0);
    assert.deepEqual(plain(groups.allocate(unit, 3, entries)), [0, 0, 0, 3]);
    for (const value of [NaN, Infinity, -1]) {
        const result = groups.pack([grouped(20, { groupPadding: value, groupSpacing: value, min: value }), grouped(30)])[0];
        assert.equal(result.size, 50);
        assert.equal(result.min, 30);
    }
    const result = solve(entries);
    assert.equal(Number.isFinite(result.layouts.left.totalSize), true);
    assert.equal(result.layouts.left.totalSize, 20);
    const empty = overflow.section([grouped(Infinity), grouped(NaN)], [0, 1], 4, 30, 0);
    assert.equal(empty.totalSize, 0);
    assert.equal(empty.buttonPosition, null);
});
