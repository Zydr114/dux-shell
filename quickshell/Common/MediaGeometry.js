.pragma library

function positive(value, fallback) {
    return Number.isFinite(value) && value > 0 ? value : fallback;
}

function fitBody(width, height, availableWidth, availableHeight, chromeHeight) {
    const bodyWidth = positive(width, 1);
    const bodyHeight = positive(height, 1);
    const chrome = Math.max(0, Number(chromeHeight) || 0);
    const maxWidth = positive(availableWidth, bodyWidth);
    const maxHeight = positive(availableHeight, bodyHeight + chrome);
    const fittedWidth = Math.min(bodyWidth, maxWidth);
    const fittedBodyHeight = Math.min(bodyHeight, Math.max(1, maxHeight - chrome));
    return { width: fittedWidth, bodyHeight: fittedBodyHeight, height: Math.min(maxHeight, fittedBodyHeight + chrome) };
}
