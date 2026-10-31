.pragma library

function remainingRatio(startedAt, expiresAt, now) {
    const duration = expiresAt - startedAt;
    if (!Number.isFinite(duration) || duration <= 0 || !Number.isFinite(now))
        return 0;
    return Math.max(0, Math.min(1, (expiresAt - now) / duration));
}
