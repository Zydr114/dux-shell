.pragma library

function plainLines(text) {
    return text.replace(/\r\n?/g, "\n").split("\n").map(line => line.trim()).filter(line => line.length > 0);
}
