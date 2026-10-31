.pragma library

function isRecord(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function parse(text) {
    let config;
    try {
        config = JSON.parse(text);
    } catch (e) {
        return { preview: null, error: "invalid-json" };
    }
    const media = config?.keystone?.media;
    if (!isRecord(media))
        return { preview: null, error: "invalid-media" };

    const cover = media.coverStyle === "spectrum" ? "caelestia" : media.coverStyle;
    if (!["rounded", "caelestia", "background"].includes(cover))
        return { preview: null, error: "invalid-cover" };
    if (!["wave", "material"].includes(media.progressStyle))
        return { preview: null, error: "invalid-progress" };
    if (!["theme", "cover"].includes(media.colorStyle))
        return { preview: null, error: "invalid-color" };

    return {
        preview: {
            playerStyle: "clavis",
            clavisCoverStyle: cover,
            clavisProgressStyle: media.progressStyle,
            albumArtAccent: media.colorStyle === "cover"
        },
        error: ""
    };
}

function mergeDashOptions(options, preview) {
    if (!isRecord(options) || !isRecord(preview) || preview.playerStyle !== "clavis"
        || !["rounded", "caelestia", "background"].includes(preview.clavisCoverStyle)
        || !["wave", "material"].includes(preview.clavisProgressStyle)
        || typeof preview.albumArtAccent !== "boolean")
        return null;
    if (options.media !== undefined && !isRecord(options.media))
        return null;

    const media = Object.assign({}, options.media ?? {}, {
        playerStyle: preview.playerStyle,
        clavisCoverStyle: preview.clavisCoverStyle,
        clavisProgressStyle: preview.clavisProgressStyle,
        albumArtAccent: preview.albumArtAccent
    });
    return Object.assign({}, options, { media });
}
