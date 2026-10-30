import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const clock = loadScript(new URL("../Common/settings/ClockStyle.js", import.meta.url));
const store = loadScript(new URL("../Common/settings/SettingsStore.js", import.meta.url));
const plain = value => JSON.parse(JSON.stringify(value));

test("malformed clock settings cannot pass invalid font axes, geometry, or colors to QML", () => {
    const style = clock.normalize({
        fontSize: 500,
        hideDate: "true",
        axes: { wght: -100, wdth: "151", opsz: Infinity, GRAD: [], slnt: -99, unknown: 42 },
        digits: {
            h0: { x: -90, y: 9, rotation: "NaN", colorRole: "custom", customColor: "red" },
            h1: { x: true, colorRole: "custom", customColor: " #80FF00AA " },
            separator: ["invalid"],
            unknown: { x: 1 }
        }
    });
    assert.equal(style.fontSize, 28);
    assert.equal(style.hideDate, false);
    assert.deepEqual(plain(style.axes), { wght: 1, wdth: 151, opsz: 18, GRAD: 0, ROND: 25, slnt: -10 });
    assert.deepEqual(plain(style.digits.h0), { x: -8, y: 6, rotation: -3, colorRole: "inversePrimary", customColor: "" });
    assert.equal(style.digits.h1.x, 0);
    assert.equal(style.digits.h1.customColor, "#80ff00aa");
    assert.equal(style.digits.h1.colorRole, "custom");
    assert.equal("unknown" in style.digits, false);
    for (const value of [null, [], "bad", { axes: null, digits: null }])
        assert.equal(Number.isFinite(clock.normalize(value).axes.wght), true);
});

test("editing one character preserves other characters and can reset that character independently", () => {
    const original = clock.normalize({ digits: { h0: { x: 3 }, h1: { y: 4 } } });
    const edited = clock.withValue(original, ["digits", "h0", "rotation"], 50);
    assert.equal(edited.digits.h0.rotation, 12);
    assert.equal(original.digits.h0.rotation, -3);
    assert.deepEqual(plain(edited.digits.h1), plain(original.digits.h1));
    const reset = clock.withValue(edited, ["digits", "h0"], clock.normalize(null).digits.h0);
    assert.equal(reset.digits.h0.x, 0);
    assert.equal(reset.digits.h1.y, 4);
    for (const path of [["unknown"], ["axes", "unknown"], ["digits", "h0", "unknown"], ["digits", "__proto__"]])
        assert.equal(clock.withValue(edited, path, 42), null);
});

test("character styles stay attached to hour ones, seconds, separators and localized periods", () => {
    const cases = [
        ["09:34", ["h0", "h1", "separator", "m0", "m1"]],
        ["9:34 AM", ["h1", "separator", "m0", "m1", "", "ap", "periodM"]],
        ["12:34:56 PM", ["h0", "h1", "separator", "m0", "m1", "secondsSeparator", "s0", "s1", "", "ap", "periodM"]],
        ["12:34 下午", ["h0", "h1", "separator", "m0", "m1", "", "ap", "periodM"]]
    ];
    for (const [text, ids] of cases)
        assert.deepEqual(plain(clock.characterIds(text)), ids);
});

test("the settings store retains customized clock styling across serialization and reload", () => {
    const root = { settingsConfigVersion: 42 };
    store.parse(root, { clockStyle: { fontSize: 26, hideDate: true, axes: { wdth: 110 }, digits: { periodM: { colorRole: "custom", customColor: "#ffcc00", x: 8 } } } });
    const serialized = store.toJson(root, new Set());
    const restored = { settingsConfigVersion: 42 };
    store.parse(restored, JSON.parse(JSON.stringify(serialized)));
    assert.equal(restored.clockStyle.fontSize, 26);
    assert.equal(restored.clockStyle.hideDate, true);
    assert.equal(restored.clockStyle.axes.wdth, 110);
    assert.equal(restored.clockStyle.digits.periodM.customColor, "#ffcc00");
    assert.equal(restored.clockStyle.digits.periodM.x, 8);
    assert.deepEqual(plain(restored.clockStyle), plain(root.clockStyle));
});
