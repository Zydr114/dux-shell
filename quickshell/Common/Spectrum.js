.pragma library

function addSubscriber(subscribers, token) {
    if (token === null || token === undefined || subscribers.indexOf(token) !== -1)
        return subscribers;
    return subscribers.concat([token]);
}

function removeSubscriber(subscribers, token) {
    const index = subscribers.indexOf(token);
    if (index === -1)
        return subscribers;
    const result = subscribers.slice();
    result.splice(index, 1);
    return result;
}

function parse(line, count, maximum) {
    if (!line || count <= 0 || maximum <= 0)
        return [];
    const parts = line.trim().split(";");
    if (parts.length === count + 1 && parts[count] === "")
        parts.pop();
    if (parts.length !== count)
        return [];
    const values = [];
    for (let i = 0; i < parts.length; i++) {
        if (!/^\d+$/.test(parts[i]))
            return [];
        values.push(Math.min(Number(parts[i]), maximum) / maximum);
    }
    return values;
}

function aggregate(values, count) {
    if (!values.length || count <= 0)
        return [];
    const result = [];
    const width = values.length / count;
    for (let i = 0; i < count; i++) {
        const start = i * width;
        const end = (i + 1) * width;
        let sum = 0;
        for (let j = Math.floor(start); j < Math.ceil(end); j++)
            sum += values[j] * (Math.min(end, j + 1) - Math.max(start, j));
        result.push(sum / width);
    }
    return result;
}
