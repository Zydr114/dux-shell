import assert from "node:assert/strict";
import test from "node:test";
import { loadScript } from "./qml-script.mjs";

const interaction = loadScript(new URL("../Common/IslandInteraction.js", import.meta.url));
const state = overrides => ({
    activeActivity: "home",
    expanded: false,
    mediaAvailable: true,
    mediaPreferred: false,
    pointerInside: false,
    hoverExpandEnabled: true,
    systemActivityActive: false,
    transientReturnActivity: "",
    notificationActive: false,
    notificationHeldForSystem: false,
    suspendedActivity: "",
    suspendedExpanded: false,
    ...overrides
});

function activate(current, target) {
    const action = interaction.compactActivation(target, current.mediaAvailable);
    if (!action)
        return current;
    return {
        ...current,
        activeActivity: action.activity,
        expanded: action.expanded,
        mediaPreferred: interaction.preferredAfterRequest(current.mediaPreferred, action.activity, action.expanded)
    };
}

function collapse(current) {
    return {
        ...current,
        expanded: false,
        activeActivity: interaction.idleActivity(current.mediaAvailable, current.mediaPreferred)
    };
}

test("viewing the clock repeatedly returns to the automatic media face without a new playback event", () => {
    let current = state();
    current = { ...current, ...interaction.autoSwitchToMedia(current) };
    for (let visit = 0; visit < 3; visit++) {
        current = activate(current, "clock");
        assert.equal(current.activeActivity, "home");
        assert.equal(current.expanded, true, "the clock opens a temporary dashboard");
        assert.equal(current.mediaPreferred, true, "viewing time preserves the compact media selection");
        current = collapse(current);
        assert.equal(current.activeActivity, "media");
        assert.equal(current.expanded, false);
    }
});

test("the home media entry selects a compact continuation before expanding the player", () => {
    let current = activate(state(), "media");
    assert.equal(current.activeActivity, "media");
    assert.equal(current.expanded, false);
    assert.equal(current.mediaPreferred, true);
    current.expanded = true;
    assert.equal(collapse(current).activeActivity, "media");
    assert.equal(activate(state({ mediaAvailable: false }), "media").activeActivity, "home");
});

test("expanded destinations preserve the chosen compact face and explicit face choices replace it", () => {
    for (const preferred of [false, true]) {
        for (const activity of ["home", "media", "weather", "launcher", "controlcenter"])
            assert.equal(interaction.preferredAfterRequest(preferred, activity, true), preferred, activity);
    }
    assert.equal(interaction.preferredAfterRequest(true, "home", false), false);
    assert.equal(interaction.preferredAfterRequest(false, "media", false), true);
    assert.equal(interaction.preferredAfterRequest(true, "weather", false), true);
});

test("playback starting during an open page records the return face without replacing the page", () => {
    for (const activity of ["home", "media", "weather", "launcher", "controlcenter"]) {
        const current = state({ activeActivity: activity, expanded: true });
        const next = { ...current, ...interaction.autoSwitchToMedia(current) };
        assert.equal(next.activeActivity, activity);
        assert.equal(next.expanded, true);
        assert.equal(collapse(next).activeActivity, "media");
    }
    const hovered = state({ pointerInside: true });
    const next = { ...hovered, ...interaction.autoSwitchToMedia(hovered) };
    assert.equal(next.activeActivity, "home", "playback must not resize the face beneath a hovering pointer");
    assert.equal(collapse(next).activeActivity, "media");
});

test("playback during notifications and OSD updates only the suspended compact return face", () => {
    const cases = [
        { activeActivity: "volume", systemActivityActive: true, transientReturnActivity: "home" },
        { activeActivity: "notification", notificationActive: true, suspendedActivity: "home" },
        { activeActivity: "volume", systemActivityActive: true, transientReturnActivity: "notification", notificationHeldForSystem: true, suspendedActivity: "home" }
    ];
    for (const scenario of cases) {
        const current = state(scenario);
        const next = interaction.autoSwitchToMedia(current);
        assert.equal(next.activeActivity, current.activeActivity);
        assert.equal(next.mediaPreferred, true);
        if (current.transientReturnActivity === "home")
            assert.equal(next.transientReturnActivity, "media");
        if (current.suspendedActivity === "home")
            assert.equal(next.suspendedActivity, "media");
    }
    const expanded = interaction.autoSwitchToMedia(state({ activeActivity: "notification", notificationActive: true, suspendedActivity: "home", suspendedExpanded: true }));
    assert.equal(expanded.suspendedActivity, "home", "an interrupted dashboard must still resume expanded");
});

test("media disappearing during a clock visit falls back to home on collapse", () => {
    const current = activate(state({ activeActivity: "media", mediaPreferred: true }), "clock");
    current.mediaAvailable = false;
    assert.equal(collapse(current).activeActivity, "home");
    assert.equal(interaction.compactActivation("unknown", true), null);
});
