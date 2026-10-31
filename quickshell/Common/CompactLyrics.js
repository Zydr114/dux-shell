.pragma library

function lineText(lines, index, at) {
    const parts = lines[index]?.parts ?? [];
    const active = parts.filter(part => part.t <= at && at < part.e);
    const lead = active.filter(part => !part.background);
    return (lead.length > 0 ? lead : active).map(part => part.x.replace(/\s+/g, " ").trim()).filter(text => text.length > 0).join(" · ");
}
