.pragma library

function radiusAtAngle(profile, degrees) {
    if (!profile.length || !Number.isFinite(degrees))
        return 0;
    // MaterialShapes profiles start at -180 degrees; wrap the seam before interpolation.
    const position = ((degrees + 180) % 360 + 360) % 360 * profile.length / 360;
    const index = Math.floor(position);
    const fraction = position - index;
    return profile[index] * (1 - fraction) + profile[(index + 1) % profile.length] * fraction;
}
