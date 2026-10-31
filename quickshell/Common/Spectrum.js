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

function peakBins(values, count) {
    if (!values.length || count <= 0)
        return [];
    const result = [];
    for (let i = 0; i < count; i++) {
        const end = Math.floor((i + 1) * values.length / count);
        let peak = 0;
        for (let j = Math.floor(i * values.length / count); j < end; j++)
            peak = Math.max(peak, Math.max(0, Math.min(1, Number(values[j]) || 0)));
        result.push(peak);
    }
    return result;
}

function requestedBars(ordinaryRefs, spectrumRefs, ordinaryEnabled, reduceMotion) {
    if (reduceMotion)
        return 0;
    if (spectrumRefs > 0)
        return 45;
    return ordinaryEnabled && ordinaryRefs > 0 ? 6 : 0;
}

function ordinaryBins(spectrum) {
    // Existing blob/backdrop consumers use 45 as their display full scale.
    return aggregate(spectrum, 6).map(value => Math.round(value * 45));
}
