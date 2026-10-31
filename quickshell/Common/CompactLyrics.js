.pragma library

function lineText(lines, index, at) {
    const parts = lines[index]?.parts ?? [];
    const active = parts.filter(part => part.t <= at && at < part.e);
    const lead = active.filter(part => !part.background);
    return (lead.length > 0 ? lead : active).map(part => part.x.replace(/\s+/g, " ").trim()).filter(text => text.length > 0).join(" · ");
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
