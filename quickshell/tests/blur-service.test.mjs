import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

function service(blurEnabled, available = true) {
    const source = readFileSync(new URL("../Services/BlurService.qml", import.meta.url), "utf8");
    const context = vm.createContext({ SettingsData: { blurEnabled }, available });
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
