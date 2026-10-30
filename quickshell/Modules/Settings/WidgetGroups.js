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

function tree(entries) {
    const result = [];
    for (let i = 0; i < entries.length;) {
        const groupId = groupOf(entries[i]);
        let end = i + 1;
        if (groupId)
            while (end < entries.length && groupOf(entries[end]) === groupId)
                end++;
        result.push({ groupId: groupId, first: i, end: end });
        i = end;
    }
    return result;
}

function reorder(entries, nodes, order) {
    return order.reduce((out, index) => out.concat(entries.slice(nodes[index].first, nodes[index].end)), []);
}

function transfer(source, destination, sourceNode, destinationNodes, targetIndex) {
    const src = source.slice();
    const dst = destination.slice();
    const block = src.splice(sourceNode.first, sourceNode.end - sourceNode.first);
    const position = targetIndex < destinationNodes.length ? destinationNodes[targetIndex].first : dst.length;
    dst.splice(position, 0, ...block);
    return { source: src, destination: dst, position: position };
}

function addMember(entries, index, groupId) {
    const nodes = tree(entries);
    const group = nodes.find(node => node.groupId === groupId && groupId);
    if (!group || index < 0 || index >= entries.length || groupOf(entries[index]) || !eligible(entries[index]))
        return entries;
    const next = entries.slice();
    const member = withGroup(next.splice(index, 1)[0], groupId);
    next.splice(group.end - (index < group.first ? 1 : 0), 0, member);
    return next;
}

function removeMember(entries, index) {
    const groupId = groupOf(entries[index]);
    const group = tree(entries).find(node => node.groupId === groupId && groupId);
    if (!group)
        return entries;
    const next = entries.slice();
    const member = withGroup(next.splice(index, 1)[0], "");
    next.splice(group.end - 1, 0, member);
    return next;
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
