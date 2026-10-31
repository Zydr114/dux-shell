pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import "../../../Common/Format.js" as Format

Item {
    id: root

    required property var player
    property string progressStyle: "wave"
    property color progressColor: MediaAccentService.accent
    property color trackColor: MediaAccentService.accentTrack
    property color subduedColor: MediaAccentService.accentSubtle
    property real previewRatio: -1
    property real phase: 0
    property real visualPosition: width * value
    property bool seeking: false
    property bool positionRefHeld: false
    property int settleAttempts: 0

    readonly property MprisPlayer activePlayer: player.activePlayer
    readonly property string trackId: activePlayer?.uniqueId ?? ""
    readonly property real length: player.presentation?.length ?? 0
    readonly property bool canSeek: !!activePlayer?.canControl && !!activePlayer?.canSeek && length > 0
    readonly property real actualValue: length > 0 ? Math.max(0, Math.min(1, (activePlayer?.position ?? 0) / length)) : 0
    readonly property real value: previewRatio >= 0 ? previewRatio : actualValue
    readonly property bool material: progressStyle === "material"
    readonly property bool live: visible && player.live && (Window.window?.visible ?? false)
    readonly property bool animationsEnabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
    readonly property bool motionAllowed: live && !!player.presentation?.playing && animationsEnabled

    implicitHeight: Theme.clavisProgressHeight
    activeFocusOnTab: canSeek
    Accessible.role: Accessible.Slider
    Accessible.name: I18n.tr("Playback position", "media seekbar accessible name")
    Accessible.focusable: canSeek
    Accessible.onIncreaseAction: seekBy(5)
    Accessible.onDecreaseAction: seekBy(-5)

    onLiveChanged: {
        syncPositionRef();
        if (!live)
            playheadSmoothing.complete();
        requestProgressPaint();
    }
    onActivePlayerChanged: cancelSeek()
    onTrackIdChanged: cancelSeek()
    onCanSeekChanged: {
        if (!canSeek)
            cancelSeek();
    }
    onVisualPositionChanged: requestProgressPaint()
    onActualValueChanged: {
        if (!seeking && previewRatio >= 0 && Math.abs(actualValue - previewRatio) < 0.002)
            clearPreview();
        if (seeking)
            requestProgressPaint();
    }
    onAnimationsEnabledChanged: {
        if (!animationsEnabled)
            playheadSmoothing.complete();
    }
    onPhaseChanged: requestProgressPaint()
    onProgressStyleChanged: {
        phase = 0;
        requestProgressPaint();
    }
    onProgressColorChanged: requestProgressPaint()
    onTrackColorChanged: requestProgressPaint()
    onSubduedColorChanged: requestProgressPaint()
    onSeekingChanged: {
        if (seeking)
            playheadSmoothing.complete();
        requestProgressPaint();
    }
    Component.onCompleted: {
        syncPositionRef();
        requestProgressPaint();
    }
    Component.onDestruction: {
        if (positionRefHeld)
            MprisController.removePositionRef();
        if (seeking)
            player.isSeeking = false;
    }

    function requestProgressPaint() {
        if (live)
            progressCanvas.requestPaint();
    }

    function syncPositionRef() {
        if (live === positionRefHeld)
            return;
        positionRefHeld = live;
        if (live) {
            MprisController.addPositionRef();
            return;
        }
        MprisController.removePositionRef();
        cancelSeek();
    }

    function clearPreview() {
        settle.stop();
        previewRatio = -1;
    }

    function cancelSeek() {
        seeking = false;
        player.isSeeking = false;
        clearPreview();
    }

    function setPreview(x) {
        previewRatio = width > 0 ? Math.max(0, Math.min(1, x / width)) : 0;
    }

    function commitRatio(ratio) {
        if (!canSeek)
            return;
        const position = Math.max(0.1, Math.min(length * ratio, length * 0.99));
        activePlayer.position = position;
        previewRatio = position / length;
        settleAttempts = 15;
        settle.restart();
    }

    function seekBy(seconds) {
        if (length > 0)
            commitRatio(Math.max(0, Math.min(1, value + seconds / length)));
    }

    Keys.onPressed: event => {
        if (!canSeek)
            return;
        switch (event.key) {
        case Qt.Key_Left:
            seekBy(-5);
            break;
        case Qt.Key_Right:
            seekBy(5);
            break;
        case Qt.Key_Home:
            commitRatio(0);
            break;
        case Qt.Key_End:
            commitRatio(1);
            break;
        case Qt.Key_PageUp:
            seekBy(length / 10);
            break;
        case Qt.Key_PageDown:
            seekBy(-length / 10);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Timer {
        id: settle
        interval: 80
        repeat: true
        onTriggered: {
            if (--root.settleAttempts <= 0)
                root.clearPreview();
        }
    }

    FocusRing {
        visible: root.activeFocus
        radius: Theme.cornerRadiusXS
    }

    Behavior on visualPosition {
        enabled: root.live && !root.seeking && root.animationsEnabled
        SmoothedAnimation {
            id: playheadSmoothing
            duration: root.material ? Theme.clavisProgressMaterialSmoothingDuration : Theme.clavisProgressWaveSmoothingDuration
            velocity: root.material ? Theme.clavisProgressMaterialSmoothingVelocity : Theme.clavisProgressWaveSmoothingVelocity
            reversingMode: SmoothedAnimation.Sync
        }
    }

    Canvas {
        id: progressCanvas
        anchors.fill: parent
        onAvailableChanged: {
            if (available)
                root.requestProgressPaint();
        }
        onWidthChanged: root.requestProgressPaint()
        onHeightChanged: root.requestProgressPaint()
        onVisibleChanged: {
            if (visible)
                root.requestProgressPaint();
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0)
                return;
            const stroke = Math.min(width, Theme.clavisProgressStrokeWidth);
            const radius = stroke / 2;
            const midpoint = height / 2;
            const position = Math.max(0, Math.min(width, root.visualPosition));
            ctx.lineWidth = stroke;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            if (root.material) {
                const trackStart = Math.min(width - radius, position + Theme.clavisProgressMaterialGap);
                if (trackStart < width - radius) {
                    ctx.strokeStyle = root.trackColor;
                    ctx.beginPath();
                    ctx.moveTo(trackStart, midpoint);
                    ctx.lineTo(width - radius, midpoint);
                    ctx.stroke();
                }
                const waveEnd = Math.max(radius, position - Theme.clavisProgressMaterialGap - radius);
                if (waveEnd > radius) {
                    const frequency = Math.PI * 2 / Theme.clavisProgressMaterialWavelength;
                    ctx.strokeStyle = root.progressColor;
                    ctx.beginPath();
                    for (let x = radius; x < waveEnd; x++) {
                        const y = midpoint + Math.sin((x - radius) * frequency + root.phase) * Theme.clavisProgressMaterialAmplitude;
                        if (x === radius)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.lineTo(waveEnd, midpoint + Math.sin((waveEnd - radius) * frequency + root.phase) * Theme.clavisProgressMaterialAmplitude);
                    ctx.stroke();
                }
                ctx.fillStyle = root.progressColor;
                ctx.beginPath();
                ctx.arc(width - radius, midpoint, Math.min(width, Theme.clavisProgressEndDotSize) / 2, 0, Math.PI * 2);
                ctx.fill();
            } else {
                const split = position > 0 && position < width;
                const playedWidth = split ? Math.max(0, position - Theme.clavisProgressWaveGap / 2) : position;
                const trackStart = split ? Math.min(width, position + Theme.clavisProgressWaveGap / 2) : position;
                const remaining = width - trackStart;
                if (remaining > 0) {
                    const trackRadius = Math.min(radius, remaining / 2);
                    const top = midpoint - radius;
                    const bottom = midpoint + radius;
                    ctx.fillStyle = root.trackColor;
                    ctx.beginPath();
                    ctx.moveTo(trackStart + trackRadius, top);
                    ctx.lineTo(width - trackRadius, top);
                    ctx.quadraticCurveTo(width, top, width, top + trackRadius);
                    ctx.lineTo(width, bottom - trackRadius);
                    ctx.quadraticCurveTo(width, bottom, width - trackRadius, bottom);
                    ctx.lineTo(trackStart + trackRadius, bottom);
                    ctx.quadraticCurveTo(trackStart, bottom, trackStart, bottom - trackRadius);
                    ctx.lineTo(trackStart, top + trackRadius);
                    ctx.quadraticCurveTo(trackStart, top, trackStart + trackRadius, top);
                    ctx.closePath();
                    ctx.fill();
                }
                if (playedWidth > 0) {
                    ctx.fillStyle = root.progressColor;
                    ctx.beginPath();
                    if (playedWidth <= stroke) {
                        ctx.arc(playedWidth / 2, midpoint, playedWidth / 2, 0, Math.PI * 2);
                    } else {
                        const right = playedWidth - radius;
                        const frequency = Math.PI * 2 / Theme.clavisProgressWaveWavelength;
                        const fadeLength = Theme.clavisProgressWaveFadeLength;
                        ctx.moveTo(radius, midpoint + radius);
                        ctx.lineTo(right, midpoint + radius);
                        ctx.arc(right, midpoint, radius, Math.PI / 2, -Math.PI / 2, true);
                        for (let x = right; x > radius; x--) {
                            const edge = Math.min(x - radius, right - x);
                            const envelope = Math.sin(Math.min(1, edge / fadeLength) * Math.PI / 2);
                            const fundamental = Math.sin(x * frequency - root.phase);
                            const harmonic = Math.sin(x * frequency * Theme.clavisProgressWaveHarmonicRatio - root.phase * 2) * Theme.clavisProgressWaveHarmonicAmplitude;
                            const crest = Math.max(0, Math.min(1, 0.5 + (fundamental + harmonic) / (2 * Theme.clavisProgressWaveBias)));
                            ctx.lineTo(x, midpoint - radius - Theme.clavisProgressWaveAmplitude * envelope * crest);
                        }
                        ctx.lineTo(radius, midpoint - radius);
                        ctx.arc(radius, midpoint, radius, -Math.PI / 2, Math.PI / 2, true);
                    }
                    ctx.closePath();
                    ctx.fill();
                }
            }
            if (!root.seeking)
                return;
            ctx.lineWidth = Theme.clavisProgressStrokeWidth / 2;
            ctx.strokeStyle = root.subduedColor;
            ctx.beginPath();
            ctx.moveTo(width * root.actualValue, Theme.spacingXS);
            ctx.lineTo(width * root.actualValue, height - Theme.spacingXS);
            ctx.stroke();
            ctx.strokeStyle = root.progressColor;
            ctx.beginPath();
            ctx.moveTo(position, Theme.spacingXS);
            ctx.lineTo(position, height - Theme.spacingXS);
            ctx.stroke();
        }
    }

    FrameAnimation {
        running: root.motionAllowed
        onTriggered: {
            root.phase = (root.phase + frameTime * 1000 / Theme.clavisProgressPhaseDuration * Math.PI * 2) % (Math.PI * 2);
            if (!root.seeking)
                MprisController.refreshPosition(root.activePlayer);
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.canSeek
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onPressed: mouse => {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.clearPreview();
            root.seeking = true;
            root.player.isSeeking = true;
            root.setPreview(mouse.x);
        }
        onPositionChanged: mouse => {
            if (pressed && root.seeking)
                root.setPreview(mouse.x);
        }
        onReleased: {
            if (!root.seeking)
                return;
            root.seeking = false;
            root.player.isSeeking = false;
            root.commitRatio(root.value);
        }
        onCanceled: root.cancelSeek()
    }

    Rectangle {
        visible: root.seeking
        x: Math.max(0, Math.min(root.width - width, root.width * root.value - width / 2))
        anchors.bottom: parent.top
        width: previewLabel.implicitWidth + Theme.spacingM
        height: previewLabel.implicitHeight + Theme.spacingXS
        radius: Theme.cornerRadiusXS
        color: Theme.inverseSurface

        StyledText {
            id: previewLabel
            anchors.centerIn: parent
            text: Format.formatDuration(root.value * root.length)
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.inverseOnSurface
        }
    }
}
