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

test("outer metrics retain the default group envelope and reserve content before excessive outline", () => {
    const cases = [
        { input: [30, 48, 0, 4, 16], expected: [38, 38, 0] },
        { input: [30, 48, 2, 4, 16], expected: [42, 38, 2] },
        { input: [30, 32, 2, 4, 16], expected: [32, 28, 2] },
        { input: [30, 32, 100, 4, 16], expected: [32, 16, 8] },
        { input: [30, 12, 100, 4, 16], expected: [12, 12, 0] },
        { input: [17.5, 24.5, 0.75, 2.25, 16], expected: [23.5, 22, 0.75] },
        { input: [-5, 32, -1, -2, 16], expected: [0, 0, 0] },
        { input: [30, Infinity, 1, 4, 16], expected: [0, 0, 0] }
    ];
    for (const { input, expected } of cases) {
        const result = groups.outerMetrics(...input);
        assert.deepEqual(plain(result), { thickness: expected[0], surfaceThickness: expected[1], outline: expected[2] });
        assert.equal(result.surfaceThickness + result.outline * 2, result.thickness);
        assert.ok(result.thickness <= groups.nonnegative(input[1]));
    }
});

test("group insets consume a fixed outer envelope and preserve the minimum inner face", () => {
    const cases = [
        { input: [42, 2, 4, 16, 1], expected: [30, 2, 4, 42] },
        { input: [42, 2, 100, 16, 1], expected: [16, 2, 11, 42] },
        { input: [42, 2, 0, 16, 1], expected: [36, 2, 1, 42] },
        { input: [12, 0, 8, 16, 1], expected: [10, 0, 1, 12] },
        { input: [0, 2, 8, 16, 1], expected: [0, 0, 0, 0] },
        { input: [24.5, 0.75, 2.25, 16, 1], expected: [18.5, 0.75, 2.25, 24.5] },
        { input: [NaN, Infinity, -5, 16, 1], expected: [0, 0, 0, 0] }
    ];
    for (const { input, expected } of cases) {
        const result = groups.crossMetrics(...input);
        assert.deepEqual(plain(result), { widgetThickness: expected[0], outline: expected[1], crossInset: expected[2], thickness: expected[3] });
        assert.equal(result.widgetThickness + 2 * result.outline + 2 * result.crossInset, result.thickness);
        assert.ok(Object.values(result).every(value => Number.isFinite(value) && value >= 0));
    }
});

test("large group padding changes the inner face and along budget without enlarging the outer face", () => {
    const outer = groups.outerMetrics(30, 48, 2, 4, 16);
    const ordinary = groups.crossMetrics(outer.thickness, outer.outline, 4, 16, 1);
    const padded = groups.crossMetrics(outer.thickness, outer.outline, 24, 16, 1);
    const unit = groups.pack([grouped(40, { groupPadding: 24 })])[0];
    assert.equal(ordinary.thickness, 42);
    assert.equal(padded.thickness, ordinary.thickness);
    assert.equal(padded.widgetThickness, 16);
    assert.equal(padded.crossInset, 11);
    assert.equal(unit.size, 88);
    const result = overflow.section([widget(40)], [0], 8, outer.surfaceThickness, 0);
    assert.equal(result.totalSize, 38);
    assert.equal(result.sizes[0], outer.surfaceThickness);
});

test("fractional DPR keeps ordinary and grouped envelopes on the same bounded physical grid", () => {
    const close = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-8, `${actual} != ${expected}`);
    for (const dpr of [1.8, 1.37]) {
        for (const barThickness of [48, 32.3, 10.3, 1.2, 0]) {
            for (const outline of [0, 0.75, 2, 100]) {
                const outer = groups.outerMetrics(30, barThickness, outline, 4, 16, dpr);
                const snappedFill = Math.round(outer.surfaceThickness * dpr) / dpr;
                close(snappedFill + outer.outline * 2, outer.thickness);
                assert.ok(outer.thickness <= barThickness + 1e-8);
                close(outer.thickness * dpr, Math.round(outer.thickness * dpr));
                for (const padding of [0, 4, 24]) {
                    const inner = groups.crossMetrics(outer.thickness, outer.outline, padding, 16, 1, dpr);
                    const snappedInner = Math.round(inner.widgetThickness * dpr) / dpr;
                    close(inner.thickness, outer.thickness);
                    close(inner.outline, outer.outline);
                    close(snappedInner + inner.outline * 2 + inner.crossInset * 2, outer.thickness);
                    for (const value of Object.values(inner))
                        close(value * dpr, Math.round(value * dpr));
                    assert.ok(snappedInner + inner.outline * 2 <= outer.thickness + 1e-8);
                    assert.ok(Object.values(inner).every(value => Number.isFinite(value) && value >= 0));
                }
            }
        }
    }
    const outer = groups.outerMetrics(30, 48, 2, 4, 16, 1.8);
    close(outer.thickness * 1.8, 76);
    close(outer.surfaceThickness * 1.8, 68);
    close(outer.outline * 1.8, 4);
    const thin = groups.crossMetrics(10.3, 2, 24, 16, 1, 1.37);
    assert.ok(thin.thickness <= 10.3);
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
