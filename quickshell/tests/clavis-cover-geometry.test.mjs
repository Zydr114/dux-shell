import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const geometry = loadScript(new URL("../Common/ClavisCoverGeometry.js", import.meta.url));
const shapes = loadScript(new URL("../DCommon/Widgets/MaterialShapes.js", import.meta.url));

test("fixed spectrum directions interpolate the rotated contour across its seam", () => {
    const profile = [0.3, 0.4, 0.5, 0.6];
    assert.equal(geometry.radiusAtAngle(profile, 0), 0.5);
    assert.equal(geometry.radiusAtAngle(profile, -90), 0.4);
    assert.equal(geometry.radiusAtAngle(profile, -135), 0.35);
    assert.ok(Math.abs(geometry.radiusAtAngle(profile, 135) - 0.45) < 1e-12);
    assert.ok(Math.abs(geometry.radiusAtAngle(profile, -225) - 0.45) < 1e-12);
    for (const angle of [-721, -180, -1, 0, 179, 360, 721])
        assert.ok(Math.abs(geometry.radiusAtAngle(profile, angle) - geometry.radiusAtAngle(profile, angle + 360)) < 1e-12);
});

test("cookie edge moves under a stationary bar and joins smoothly after a full turn", () => {
    const profile = shapes.polarProfile("cookie9", 360);
    const radii = [0, 10, 20, 30].map(rotation => geometry.radiusAtAngle(profile, -rotation));
    assert.ok(Math.max(...radii) - Math.min(...radii) > 0.015);
    const before = geometry.radiusAtAngle(profile, -179.999);
    const after = geometry.radiusAtAngle(profile, 180.001);
    assert.ok(Math.abs(before - after) < 1e-10);
});
