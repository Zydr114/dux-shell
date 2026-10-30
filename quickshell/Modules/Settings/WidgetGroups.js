.pragma library

function idOf(entry) {
    return typeof entry === "string" ? entry : entry?.id;
}

function eligible(entry) {
    return !!idOf(entry) && !["spacer", "separator", "island"].includes(idOf(entry));
}

function groupOf(entry) {
    return typeof entry === "object" && entry && typeof entry.groupId === "string" ? entry.groupId : "";
}

function plainObject(value) {
    if (!value || typeof value !== "object" || Array.isArray(value))
        return false;
    const prototype = Object.getPrototypeOf(value);
    return prototype === null || (Object.getPrototypeOf(prototype) === null && Object.prototype.hasOwnProperty.call(prototype, "constructor") && prototype.constructor?.name === "Object");
}

function hasGroupProperty(entry) {
    return !!entry && typeof entry === "object" && Object.prototype.hasOwnProperty.call(entry, "groupId");
}

function withGroup(entry, groupId) {
    const copy = typeof entry === "string" ? { id: entry, enabled: true } : Object.assign({}, entry);
    if (groupId)
        copy.groupId = groupId;
    else
        delete copy.groupId;
    return copy;
}

function nextId(groups) {
    let n = 1;
    while (Object.prototype.hasOwnProperty.call(groups, "group-" + n))
        n++;
    return "group-" + n;
}

function normalize(config, updates) {
    const keys = ["leftWidgets", "centerWidgets", "rightWidgets"];
    if (!config.widgetGroups && keys.every(key => !(updates[key] || config[key] || []).some(hasGroupProperty)))
        return Object.assign({}, updates);
    const groups = Object.create(null);
    if (plainObject(config.widgetGroups)) {
        for (const id of Object.keys(config.widgetGroups)) {
            if (plainObject(config.widgetGroups[id]))
                groups[id] = config.widgetGroups[id];
        }
    }
    const seen = Object.create(null);
    const result = {};
    for (const key of keys) {
        const source = updates[key] || config[key] || [];
        let previous = "";
        let assigned = "";
        result[key] = source.map(entry => {
            const id = groupOf(entry);
            if (!id || !Object.prototype.hasOwnProperty.call(groups, id) || !eligible(entry)) {
                previous = "";
                assigned = "";
                return hasGroupProperty(entry) ? withGroup(entry, "") : entry;
            }
            if (id !== previous) {
                assigned = id;
                if (seen[id]) {
                    assigned = nextId(groups);
                    groups[assigned] = Object.assign({}, groups[id]);
                }
                seen[id] = true;
            }
            previous = id;
            return assigned === id ? entry : withGroup(entry, assigned);
        });
    }
    const used = Object.create(null);
    for (const key of keys)
        for (const entry of result[key])
            if (groupOf(entry))
                used[groupOf(entry)] = true;
    for (const id of Object.keys(groups))
        if (!used[id])
            delete groups[id];
    result.widgetGroups = groups;
    return result;
}
