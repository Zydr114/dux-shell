.pragma library

function nonnegative(value) {
    return typeof value === "number" && isFinite(value) ? Math.max(0, value) : 0;
}

function outerMetrics(widgetThickness, barThickness, outline, padding, minimumThickness, dpr) {
    const scale = nonnegative(dpr);
    const divisor = scale || 1;
    const available = scale ? Math.floor(nonnegative(barThickness) * scale + 1e-9) : nonnegative(barThickness);
    const base = scale ? Math.round(nonnegative(widgetThickness) * scale) : nonnegative(widgetThickness);
    const minimum = scale ? Math.ceil(nonnegative(minimumThickness) * scale - 1e-9) : nonnegative(minimumThickness);
    const floor = Math.min(base, minimum, available);
    const requestedStroke = scale ? Math.round(nonnegative(outline) * scale) : nonnegative(outline);
    const maximumStroke = scale ? Math.floor((available - floor) / 2) : (available - floor) / 2;
    const stroke = Math.min(requestedStroke, maximumStroke);
    const inset = scale ? Math.round(nonnegative(padding) * scale) : nonnegative(padding);
    const thickness = Math.min(available, base + stroke * 2 + inset * 2);
    return { thickness: thickness / divisor, surfaceThickness: Math.max(0, thickness - stroke * 2) / divisor, outline: stroke / divisor };
}

function crossMetrics(outerThickness, outline, padding, minimumThickness, border, dpr) {
    const scale = nonnegative(dpr);
    const divisor = scale || 1;
    const thickness = scale ? Math.floor(nonnegative(outerThickness) * scale + 1e-9) : nonnegative(outerThickness);
    const requestedStroke = scale ? Math.round(nonnegative(outline) * scale) : nonnegative(outline);
    const stroke = Math.min(requestedStroke, scale ? Math.floor(thickness / 2) : thickness / 2);
    const available = Math.max(0, thickness - stroke * 2);
    const requestedBorder = scale ? Math.ceil(nonnegative(border) * scale - 1e-9) : nonnegative(border);
    const borderInset = Math.min(requestedBorder, scale ? Math.floor(available / 2) : available / 2);
    const minimum = scale ? Math.ceil(nonnegative(minimumThickness) * scale - 1e-9) : nonnegative(minimumThickness);
    const floor = Math.min(minimum, available - borderInset * 2);
    const maximumInset = scale ? Math.floor((available - floor) / 2) : (available - floor) / 2;
    const requestedInset = scale ? Math.round(nonnegative(padding) * scale) : nonnegative(padding);
    const inset = Math.min(Math.max(requestedInset, borderInset), maximumInset);
    return {
        widgetThickness: (available - inset * 2) / divisor,
        outline: stroke / divisor,
        crossInset: inset / divisor,
        thickness: thickness / divisor
    };
}

function minimum(entry) {
    const size = nonnegative(entry?.size);
    return entry?.min === undefined ? size : Math.min(size, nonnegative(entry.min));
}

function mode(entries, indices, grouped) {
    if (grouped) {
        const override = entries[indices[0]]?.groupMode;
        if (["auto", "bar", "always"].includes(override))
            return override;
    }
    const modes = indices.filter(index => nonnegative(entries[index]?.size) > 0).map(index => entries[index].mode ?? "bar");
    return modes.includes("bar") ? "bar" : modes.includes("always") ? "always" : "auto";
}

function pack(entries) {
    const units = [];
    for (let index = 0; index < entries.length; index++) {
        const entry = entries[index];
        const groupId = typeof entry?.groupId === "string" ? entry.groupId : "";
        let unit = units[units.length - 1];
        if (!groupId || !unit || unit.groupId !== groupId) {
            unit = {
                groupId,
                sourceIndices: [],
                members: [],
                offsets: [],
                padding: groupId ? nonnegative(entry?.groupPadding) : 0,
                spacing: groupId ? nonnegative(entry?.groupSpacing) : 0,
                size: 0,
                min: 0,
                mode: "bar"
            };
            units.push(unit);
        }
        unit.sourceIndices.push(index);
        const size = nonnegative(entry?.size);
        if (size <= 0)
            continue;
        unit.members.push(index);
    }
    for (const unit of units) {
        let offset = unit.padding;
        let floor = unit.padding;
        for (const index of unit.members) {
            unit.offsets.push(offset);
            offset += nonnegative(entries[index].size) + unit.spacing;
            floor += minimum(entries[index]) + unit.spacing;
        }
        if (unit.members.length > 0) {
            unit.size = offset - unit.spacing + unit.padding;
            unit.min = floor - unit.spacing + unit.padding;
        }
        unit.mode = mode(entries, unit.sourceIndices, unit.groupId !== "");
    }
    return units;
}

function insertion(units, rawIndex, count) {
    const position = typeof rawIndex === "number" && isFinite(rawIndex) ? Math.max(0, Math.min(count, Math.floor(rawIndex))) : count;
    const index = units.findIndex(unit => unit.sourceIndices[unit.sourceIndices.length - 1] >= position);
    return index < 0 ? units.length : index;
}

function allocate(unit, allottedSize, entries) {
    const sizes = entries.map(() => 0);
    if (unit.members.length === 0)
        return sizes;
    const target = Math.max(unit.min, Math.min(unit.size, nonnegative(allottedSize)));
    if (target === unit.size) {
        for (const index of unit.members)
            sizes[index] = nonnegative(entries[index].size);
        return sizes;
    }
    const ratio = unit.size > unit.min ? (target - unit.min) / (unit.size - unit.min) : 0;
    let remaining = target - unit.padding * 2 - Math.max(0, unit.members.length - 1) * unit.spacing;
    for (const index of unit.members) {
        const floor = minimum(entries[index]);
        sizes[index] = Math.max(floor, Math.floor(floor + (nonnegative(entries[index].size) - floor) * ratio));
        remaining -= sizes[index];
    }
    for (const index of unit.members) {
        const extra = Math.min(nonnegative(entries[index].size) - sizes[index], Math.max(0, remaining));
        sizes[index] += extra;
        remaining -= extra;
    }
    return sizes;
}
