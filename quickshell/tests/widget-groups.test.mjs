import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../Modules/Settings/WidgetGroups.js", import.meta.url), "utf8").replace(/^\.pragma library\s*/u, "");
const groups = vm.createContext({});
vm.runInContext(source, groups);
const plain = value => JSON.parse(JSON.stringify(value));

test("tree operations preserve duplicate instances and move groups as blocks", () => {
    const entries = [{ id: "clock", marker: 1 }, { id: "clock", marker: 2, groupId: "a" }, { id: "music", groupId: "a" }, { id: "clock", marker: 3 }];
    const nodes = groups.tree(entries);
    assert.deepEqual(plain(nodes), [{ groupId: "", first: 0, end: 1 }, { groupId: "a", first: 1, end: 3 }, { groupId: "", first: 3, end: 4 }]);
    assert.deepEqual(plain(groups.reorder(entries, nodes, [1, 2, 0])).map(x => x.marker ?? x.id), [2, "music", 3, 1]);
    const moved = groups.transfer(entries, ["battery"], nodes[1], groups.tree(["battery"]), 1);
    assert.deepEqual(plain(moved.source).map(x => x.marker), [1, 3]);
    assert.deepEqual(plain(moved.destination), ["battery", entries[1], entries[2]]);
});

test("adding and removing any member preserves contiguous group order", () => {
    const entries = [{ id: "clock", marker: 1 }, { id: "clock", groupId: "a", marker: 2 }, { id: "clock", groupId: "a", marker: 3 }, { id: "clock", marker: 4 }];
    const added = plain(groups.addMember(entries, 0, "a"));
    assert.deepEqual(added.map(x => x.marker), [2, 3, 1, 4]);
    assert.deepEqual(added.map(x => x.groupId ?? ""), ["a", "a", "a", ""]);
    const removed = plain(groups.removeMember(added, 1));
    assert.deepEqual(removed.map(x => x.marker), [2, 1, 3, 4]);
    assert.deepEqual(removed.map(x => x.groupId ?? ""), ["a", "a", "", ""]);
    assert.deepEqual(plain(groups.addMember(entries, 3, "a")).map(x => x.marker), [1, 2, 3, 4]);
});

test("ordinary widget changes do not add group metadata or change other sections", () => {
    const config = { leftWidgets: ["clock"], centerWidgets: ["music"], rightWidgets: ["battery"] };
    const updates = { leftWidgets: [{ id: "clock", enabled: false }] };
    assert.deepEqual(plain(groups.normalize(config, updates)), updates);
});

test("cross-section group transfers retain settings and unknown neighboring entries", () => {
    const config = {
        widgetGroups: { a: { name: "A", backgroundOpacity: 0.25, blur: "off" } },
        leftWidgets: [{ id: "clock", groupId: "a", marker: 1 }, { id: "clock", groupId: "a", marker: 2 }, { id: "unknown:variant", opaque: { keep: true } }],
        centerWidgets: [],
        rightWidgets: ["battery"]
    };
    const moved = groups.transfer(config.leftWidgets, config.rightWidgets, groups.tree(config.leftWidgets)[0], groups.tree(config.rightWidgets), 0);
    const result = plain(groups.normalize(config, { leftWidgets: moved.source, rightWidgets: moved.destination }));
    assert.deepEqual(result.widgetGroups, config.widgetGroups);
    assert.deepEqual(result.leftWidgets, [config.leftWidgets[2]]);
    assert.deepEqual(result.rightWidgets, [...config.leftWidgets.slice(0, 2), "battery"]);
});

test("removing the last member dissolves only its empty definition", () => {
    const config = { widgetGroups: { a: {}, b: { blur: "on" } }, leftWidgets: [{ id: "clock", groupId: "a" }, { id: "clock", groupId: "b" }], rightWidgets: [] };
    const next = groups.removeMember(config.leftWidgets, 0);
    const result = plain(groups.normalize(config, { leftWidgets: next }));
    assert.deepEqual(result.leftWidgets, [{ id: "clock" }, { id: "clock", groupId: "b" }]);
    assert.deepEqual(result.widgetGroups, { b: { blur: "on" } });
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
