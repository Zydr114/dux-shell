.pragma library

function idleActivity(mediaAvailable, mediaPreferred) {
    return mediaAvailable && mediaPreferred ? "media" : "home";
}

function compactActivation(target, mediaAvailable) {
    if (target === "clock")
        return { activity: "home", expanded: true };
    if (target === "media" && mediaAvailable)
        return { activity: "media", expanded: false };
    return null;
}

function preferredAfterRequest(mediaPreferred, activity, expanded) {
    if (!expanded && (activity === "home" || activity === "media"))
        return activity === "media";
    return mediaPreferred;
}

function autoSwitchToMedia(state) {
    const next = {
        activeActivity: state.activeActivity,
        transientReturnActivity: state.transientReturnActivity,
        suspendedActivity: state.suspendedActivity,
        mediaPreferred: true
    };
    if (state.activeActivity === "home" && !state.expanded && !(state.pointerInside && state.hoverExpandEnabled))
        next.activeActivity = "media";
    else if (state.systemActivityActive && state.transientReturnActivity === "home")
        next.transientReturnActivity = "media";
    else if ((state.notificationActive || state.notificationHeldForSystem) && state.suspendedActivity === "home" && !state.suspendedExpanded)
        next.suspendedActivity = "media";
    return next;
}
