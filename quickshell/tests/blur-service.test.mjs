import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const SurfaceStyle = loadScript(new URL("../Common/SurfaceStyle.js", import.meta.url));

function service(blurEnabled, available = true) {
    const source = readFileSync(new URL("../Services/BlurService.qml", import.meta.url), "utf8");
    const context = vm.createContext({ SettingsData: { blurEnabled }, available, SurfaceStyle });
    for (const name of ["requestedFor", "enabledFor"]) {
        const match = source.match(new RegExp(`^    function ${name}\\([^)]*\\) \\{\\n[\\s\\S]*?^    \\}`, "m"));
        assert.ok(match, `missing ${name}`);
        vm.runInContext(match[0], context);
    }
    return context;
}

test("bar blur overrides global settings while unknown modes inherit a strict boolean", () => {
    const blur = service(false);
    for (const [global, expectedInherited] of [[false, false], [true, true], [undefined, false], [1, false]]) {
        blur.SettingsData.blurEnabled = global;
        assert.equal(blur.requestedFor("on"), true);
        assert.equal(blur.requestedFor("off"), false);
        for (const mode of ["inherit", "unknown", undefined])
            assert.equal(blur.requestedFor(mode), expectedInherited);
    }
});

test("a local blur mode inherits the supplied bar state independently of global blur", () => {
    const blur = service(true);
    assert.equal(blur.requestedFor("inherit", false), false);
    assert.equal(blur.enabledFor("inherit", false), false);
    assert.equal(blur.enabledFor("on", false), true);
    blur.SettingsData.blurEnabled = false;
    assert.equal(blur.requestedFor("inherit", true), true);
    assert.equal(blur.enabledFor("inherit", true), true);
    assert.equal(blur.enabledFor("off", true), false);
    blur.available = false;
    assert.equal(blur.enabledFor("on", true), false);
});

test("compositor support gates effective blur without changing the requested override", () => {
    const blur = service(false, false);
    assert.equal(blur.requestedFor("on"), true);
    assert.equal(blur.enabledFor("on"), false);
    blur.available = true;
    assert.equal(blur.enabledFor("on"), true);
    blur.SettingsData.blurEnabled = true;
    assert.equal(blur.enabledFor("off"), false);
    assert.equal(blur.enabledFor("inherit"), true);
    blur.available = false;
    assert.equal(blur.enabledFor("inherit"), false);
});
