.pragma library

function partText(parts) {
    const vocals = parts.map(part => ({
        text: part.x.replace(/\s+/g, " ").trim(),
        background: part.background
    })).filter(part => part.text.length > 0);
    const lead = vocals.filter(part => !part.background);
    return {
        lead: lead.length > 0,
        text: (lead.length > 0 ? lead : vocals).map(part => part.text).join(" · ")
    };
}

function lineText(lines, index, at, shortGap = 0, focusedGroups = []) {
    if (!lines[index] || !Number.isFinite(at))
        return "";

    let active = partText((lines[index].parts ?? []).filter(part => part.t <= at && at < part.e));
    if (active.lead)
        return active.text;
    for (let i = focusedGroups.length - 1; i >= 0; i--) {
        if (focusedGroups[i] === index)
            continue;
        const candidate = partText((lines[focusedGroups[i]]?.parts ?? []).filter(part => part.t <= at && at < part.e));
        if (candidate.lead)
            return candidate.text;
        if (!active.text)
            active = candidate;
    }
    if (active.text)
        return active.text;
    if (!Number.isFinite(shortGap) || shortGap <= 0)
        return "";

    let previousEnd = -Infinity;
    let nextStart = Infinity;
    let held = { lead: false, text: "" };
    let resumed = { lead: false, text: "" };
    for (const line of lines) {
        const parts = line.parts ?? [];
        const candidate = partText(parts.filter(part => part.t <= at && at < part.e));
        if (candidate.text && (candidate.lead || !resumed.lead))
            resumed = candidate;
        let groupEnd = -Infinity;
        let ended = [];
        for (const part of parts) {
            if (!part.x.trim())
                continue;
            if (part.t > at)
                nextStart = Math.min(nextStart, part.t);
            if (part.e > at)
                continue;
            if (part.e > groupEnd) {
                groupEnd = part.e;
                ended = [];
            }
            if (part.e === groupEnd)
                ended.push(part);
        }
        if (groupEnd < previousEnd)
            continue;
        const previous = partText(ended);
        if (groupEnd > previousEnd || previous.lead || !held.lead)
            held = previous;
        previousEnd = groupEnd;
    }
    if (resumed.text)
        return resumed.text;
    if (!Number.isFinite(previousEnd) || !Number.isFinite(nextStart))
        return "";
    // Decimal timestamps can round to opposite sides of the exact gap boundary.
    const tolerance = Number.EPSILON * Math.max(previousEnd, nextStart, shortGap);
    if (nextStart - previousEnd > shortGap + tolerance)
        return "";
    return held.text;
}

function resolveWidth(current, required, minimum, maximum, threshold) {
    minimum = Number.isFinite(minimum) ? Math.max(0, Math.ceil(minimum)) : 0;
    maximum = Number.isFinite(maximum) ? Math.max(0, Math.floor(maximum)) : minimum;
    minimum = Math.min(minimum, maximum);
    threshold = Number.isFinite(threshold) ? Math.max(0, Math.ceil(threshold)) : 0;
    required = Number.isFinite(required) ? Math.ceil(required) : minimum;
    required = Math.max(minimum, Math.min(required, maximum));
    const desired = Math.min(required + threshold, maximum);
    if (!Number.isFinite(current) || current <= 0)
        return desired;

    current = Math.max(minimum, Math.min(Math.ceil(current), maximum));
    if (required > current || current - desired >= threshold)
        return desired;
    return current;
}
