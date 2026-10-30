.pragma library

function opacity(value, inherited) {
    const fallback = typeof inherited === "number" && Number.isFinite(inherited) ? Math.max(0, Math.min(1, inherited)) : 1;
    if (typeof value !== "number" || !Number.isFinite(value))
        return fallback;
    return Math.max(0, Math.min(1, value));
}

function blurRequested(mode, inherited) {
    return mode === "on" || (mode !== "off" && inherited === true);
}

function needsBlur(enabled, alpha) {
    return enabled === true && typeof alpha === "number" && Number.isFinite(alpha) && alpha >= 0 && alpha < 1;
}

function barBlurRequested(config, inherited) {
    if (blurRequested(config?.blur, inherited))
        return true;
    if (Object.values(config?.widgetGroups ?? {}).some(group => group?.blur === "on"))
        return true;
    return ["leftWidgets", "centerWidgets", "rightWidgets"].some(key => Array.isArray(config?.[key]) && config[key].some(entry => entry?.blur === "on"));
}
