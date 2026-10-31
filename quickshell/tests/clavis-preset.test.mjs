import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const preset = loadScript(new URL("../Common/ClavisPreset.js", import.meta.url));
const plain = value => JSON.parse(JSON.stringify(value));
const config = media => JSON.stringify({ keystone: { media } });

test("all twelve Clavis media combinations map to the corresponding DMS options", () => {
    for (const coverStyle of ["rounded", "caelestia", "background"]) {
        for (const progressStyle of ["wave", "material"]) {
            for (const colorStyle of ["theme", "cover"]) {
                const result = preset.parse(config({ coverStyle, progressStyle, colorStyle }));
                assert.equal(result.error, "");
                assert.deepEqual(plain(result.preview), {
                    playerStyle: "clavis",
                    clavisCoverStyle: coverStyle,
                    clavisProgressStyle: progressStyle,
                    albumArtAccent: colorStyle === "cover"
                });
            }
        }
    }
    assert.equal(preset.parse(config({ coverStyle: "spectrum", progressStyle: "wave", colorStyle: "theme" })).preview.clavisCoverStyle, "caelestia");
});

test("missing, malformed and unknown values cannot produce an applicable preset", () => {
    const valid = { coverStyle: "rounded", progressStyle: "wave", colorStyle: "theme" };
    const cases = [
        ["{", "invalid-json"],
        ["{}", "invalid-media"],
        [config(null), "invalid-media"],
        [config({ ...valid, coverStyle: "unknown" }), "invalid-cover"],
        [config({ ...valid, progressStyle: "unknown" }), "invalid-progress"],
        [config({ ...valid, colorStyle: "unknown" }), "invalid-color"],
        [config({ progressStyle: "wave", colorStyle: "theme" }), "invalid-cover"],
        [config({ coverStyle: "rounded", colorStyle: "theme" }), "invalid-progress"],
        [config({ coverStyle: "rounded", progressStyle: "wave" }), "invalid-color"]
    ];
    for (const [input, error] of cases) {
        const result = preset.parse(input);
        assert.equal(result.preview, null);
        assert.equal(result.error, error);
        assert.equal(preset.mergeDashOptions({}, result.preview), null);
    }
});

test("applying a preset retains unrelated and unknown dashboard and media options", () => {
    const original = { media: { playerStyle: "bento", lyrics: false, unknown: { value: 2 } }, weather: { units: "f" }, future: 42 };
    const preview = preset.parse(config({ coverStyle: "background", progressStyle: "material", colorStyle: "cover", extra: "ignored" })).preview;
    const updated = preset.mergeDashOptions(original, preview);
    assert.deepEqual(plain(updated), {
        media: { playerStyle: "clavis", lyrics: false, unknown: { value: 2 }, clavisCoverStyle: "background", clavisProgressStyle: "material", albumArtAccent: true },
        weather: { units: "f" }, future: 42
    });
    assert.equal(original.media.playerStyle, "bento");
    assert.equal(preset.mergeDashOptions({ media: [] }, preview), null);
    assert.equal(preset.mergeDashOptions(original, { ...plain(preview), clavisCoverStyle: "unknown" }), null);
});
