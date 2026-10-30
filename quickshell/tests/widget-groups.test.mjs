import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../Modules/Settings/WidgetGroups.js", import.meta.url), "utf8").replace(/^\.pragma library\s*/u, "");
const groups = vm.createContext({});
vm.runInContext(source, groups);
const plain = value => JSON.parse(JSON.stringify(value));

test("ordinary widget changes do not add group metadata or change other sections", () => {
    const config = { leftWidgets: ["clock"], centerWidgets: ["music"], rightWidgets: ["battery"] };
    const updates = { leftWidgets: [{ id: "clock", enabled: false }] };
    assert.deepEqual(plain(groups.normalize(config, updates)), updates);
});

test("splits reserve distinct sequence ids even when many occur in one operation", () => {
    const config = { widgetGroups: { a: {}, "group-1": {} }, leftWidgets: [{ id: "clock", groupId: "a" }, "spacer", { id: "clock", groupId: "a" }, "spacer", { id: "clock", groupId: "a" }], centerWidgets: [], rightWidgets: [] };
    const result = plain(groups.normalize(config, {}));
    assert.equal(result.leftWidgets[2].groupId, "group-2");
    assert.equal(result.leftWidgets[4].groupId, "group-3");
});

test("reset removes orphan groups and preserves a still-used center group", () => {
    const config = { widgetGroups: { a: {}, b: {} }, leftWidgets: [{ id: "clock", groupId: "a" }], centerWidgets: [{ id: "music", groupId: "b" }], rightWidgets: [] };
    const result = plain(groups.normalize(config, { leftWidgets: ["battery"] }));
    assert.deepEqual(result.widgetGroups, { b: {} });
    assert.equal(result.centerWidgets[0].groupId, "b");
});

test("split group runs receive independent settings and retain duplicate instances", () => {
    const config = {
        widgetGroups: { a: { name: "A", padding: 4 } },
        leftWidgets: [{ id: "clock", groupId: "a", marker: 1 }, "spacer", { id: "clock", groupId: "a", marker: 2 }],
        centerWidgets: [{ id: "battery", groupId: "a" }],
        rightWidgets: []
    };
    const result = plain(groups.normalize(config, {}));
    assert.equal(result.leftWidgets[0].groupId, "a");
    assert.equal(result.leftWidgets[2].groupId, "group-1");
    assert.equal(result.leftWidgets[2].marker, 2);
    assert.equal(result.centerWidgets[0].groupId, "group-2");
    assert.deepEqual(result.widgetGroups["group-1"], config.widgetGroups.a);
    assert.deepEqual(result.widgetGroups["group-2"], config.widgetGroups.a);
});

test("invalid members are ungrouped and unused definitions are removed", () => {
    const config = { widgetGroups: { a: { name: "A" }, unused: {} }, leftWidgets: [{ id: "island", groupId: "a" }, { id: "clock", groupId: "missing" }], centerWidgets: [], rightWidgets: [] };
    const result = plain(groups.normalize(config, {}));
    assert.deepEqual(result.leftWidgets, [{ id: "island" }, { id: "clock" }]);
    assert.deepEqual(result.widgetGroups, {});
});

test("prototype names are accepted only as own valid group definitions", () => {
    const definitions = JSON.parse('{"__proto__":{"name":"Own"},"toString":{"name":"Named"}}');
    const config = { widgetGroups: definitions, leftWidgets: [{ id: "clock", groupId: "toString" }, { id: "battery", groupId: "__proto__" }, { id: "music", groupId: "constructor" }], centerWidgets: [], rightWidgets: [] };
    const result = plain(groups.normalize(config, {}));
    assert.equal(result.leftWidgets[0].groupId, "toString");
    assert.equal(result.leftWidgets[1].groupId, "__proto__");
    assert.equal("groupId" in result.leftWidgets[2], false);
    assert.deepEqual(result.widgetGroups, definitions);
});

test("invalid group ids and non-plain definitions are removed", () => {
    const inherited = Object.create({ inherited: { name: "Inherited" } });
    inherited.valid = { name: "Valid" };
    const config = { widgetGroups: { valid: {}, nil: null, array: [], string: "group", custom: inherited }, leftWidgets: [{ id: "clock", groupId: 1 }, { id: "clock", groupId: {} }, { id: "clock", groupId: "" }, { id: "clock", groupId: "nil" }, { id: "clock", groupId: "array" }, { id: "clock", groupId: "string" }, { id: "clock", groupId: "custom" }, { id: "clock", groupId: "valid" }], centerWidgets: [], rightWidgets: [] };
    const result = plain(groups.normalize(config, {}));
    assert.deepEqual(result.leftWidgets.slice(0, 7), Array.from({ length: 7 }, () => ({ id: "clock" })));
    assert.equal(result.leftWidgets[7].groupId, "valid");
    assert.deepEqual(result.widgetGroups, { valid: {} });
    assert.deepEqual(plain(groups.normalize({ leftWidgets: [{ id: "clock", groupId: 1 }] }, {})).leftWidgets, [{ id: "clock" }]);
});
