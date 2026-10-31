.pragma library

function mergeSettings(saved, visible) {
    const available = new Set(visible.map(entry => entry.id));
    const rows = visible.map(entry => ({ id: entry.id, enabled: entry.enabled === true }));
    const merged = [];
    const seen = new Set();
    let index = 0;
    for (const entry of Array.isArray(saved) ? saved : []) {
        if (typeof entry?.id !== "string" || seen.has(entry.id))
            continue;
        seen.add(entry.id);
        if (available.has(entry.id)) {
            merged.push(rows[index++]);
            continue;
        }
        merged.push(entry);
    }
    return merged.concat(rows.slice(index));
}
