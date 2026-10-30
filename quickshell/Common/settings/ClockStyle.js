.pragma library

var FONT_SIZE = { min: 16, max: 28, def: 22 };
var AXES = {
    wght: { min: 1, max: 1000, def: 900 },
    wdth: { min: 25, max: 151, def: 85 },
    opsz: { min: 6, max: 144, def: 18 },
    GRAD: { min: 0, max: 100, def: 0 },
    ROND: { min: 0, max: 100, def: 25 },
    slnt: { min: -10, max: 0, def: 0 }
};
var DIGITS = {
    h0: { y: -2, rotation: -3, colorRole: "inversePrimary" },
    h1: { y: 1, rotation: 3 },
    separator: {},
    m0: { y: -1, rotation: -2, colorRole: "inversePrimary" },
    m1: { y: 1, rotation: 2 },
    secondsSeparator: {},
    s0: { y: -1, rotation: -2, colorRole: "inversePrimary" },
    s1: { y: 1, rotation: 2 },
    ap: { x: 1, y: -2, rotation: -2, colorRole: "inversePrimary" },
    periodM: { x: 1, y: 1, rotation: 2 }
};
var OFFSETS = { x: { min: -8, max: 8 }, y: { min: -6, max: 6 }, rotation: { min: -12, max: 12 } };

function object(value) {
    return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function bounded(value, limits, fallback) {
    if ((typeof value !== "number" && typeof value !== "string") || String(value).trim() === "")
        return fallback;
    const number = Number(value);
    return isFinite(number) ? Math.max(limits.min, Math.min(limits.max, number)) : fallback;
}

function customColor(value) {
    const text = typeof value === "string" ? value.trim().toLowerCase() : "";
    return /^#(?:[0-9a-f]{6}|[0-9a-f]{8})$/.test(text) ? text : "";
}

function normalize(value) {
    const source = object(value);
    const axes = object(source.axes);
    const digits = object(source.digits);
    const result = {
        fontSize: Math.round(bounded(source.fontSize, FONT_SIZE, FONT_SIZE.def)),
        hideDate: source.hideDate === true,
        axes: {},
        digits: {}
    };
    for (const axis of Object.keys(AXES))
        result.axes[axis] = bounded(axes[axis], AXES[axis], AXES[axis].def);
    for (const id of Object.keys(DIGITS)) {
        const fallback = DIGITS[id];
        const candidate = object(digits[id]);
        const color = customColor(candidate.customColor);
        let role = candidate.colorRole;
        if (!["primary", "inversePrimary", "custom"].includes(role) || (role === "custom" && !color))
            role = fallback.colorRole || "primary";
        const digit = { colorRole: role, customColor: color };
        for (const field of Object.keys(OFFSETS))
            digit[field] = Math.round(bounded(candidate[field], OFFSETS[field], fallback[field] || 0));
        result.digits[id] = digit;
    }
    return result;
}

function withValue(style, path, value) {
    if (!Array.isArray(path))
        return null;
    const result = normalize(style);
    if (path.length === 1 && ["fontSize", "hideDate"].includes(path[0]))
        result[path[0]] = value;
    else if (path.length === 2 && path[0] === "axes" && Object.keys(AXES).includes(path[1]))
        result.axes[path[1]] = value;
    else if (path.length === 2 && path[0] === "digits" && Object.keys(DIGITS).includes(path[1]))
        result.digits[path[1]] = value;
    else if (path.length === 3 && path[0] === "digits" && Object.keys(DIGITS).includes(path[1]) && ["x", "y", "rotation", "colorRole", "customColor"].includes(path[2]))
        result.digits[path[1]][path[2]] = value;
    else
        return null;
    return normalize(result);
}

function characterIds(text) {
    const ids = Array(text.length).fill("");
    const numbers = /[0-9]+/g;
    let match;
    let group = 0;
    let end = 0;
    while ((match = numbers.exec(text)) !== null && group < 3) {
        const prefix = ["h", "m", "s"][group];
        for (let i = 0; i < match[0].length; i++)
            ids[match.index + i] = prefix + (i + Math.max(0, 2 - match[0].length));
        if (group > 0) {
            for (let i = end; i < match.index; i++) {
                if (text[i].trim())
                    ids[i] = group === 1 ? "separator" : "secondsSeparator";
            }
        }
        end = match.index + match[0].length;
        group++;
    }
    let period = 0;
    for (let i = end; group > 0 && i < text.length; i++) {
        if (text[i].trim())
            ids[i] = period++ === 0 ? "ap" : "periodM";
    }
    return ids;
}
