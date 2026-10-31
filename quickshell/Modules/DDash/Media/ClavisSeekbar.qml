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
    property bool seeking: false
    property bool positionRefHeld: false
    property int settleAttempts: 0

    readonly property MprisPlayer activePlayer: player.activePlayer
    readonly property string trackId: activePlayer?.uniqueId ?? ""
    readonly property real length: player.presentation?.length ?? 0
    readonly property bool canSeek: !!activePlayer?.canControl && !!activePlayer?.canSeek && length > 0
    readonly property real actualValue: length > 0 ? Math.max(0, Math.min(1, (activePlayer?.position ?? 0) / length)) : 0
    readonly property real value: previewRatio >= 0 ? previewRatio : actualValue
    readonly property bool live: visible && player.live
    readonly property bool motionAllowed: live && !!player.presentation?.playing && !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None

    implicitHeight: Theme.clavisProgressHeight
    activeFocusOnTab: canSeek
    Accessible.role: Accessible.Slider
    Accessible.name: I18n.tr("Playback position", "media seekbar accessible name")
    Accessible.focusable: canSeek
    Accessible.onIncreaseAction: seekBy(5)
    Accessible.onDecreaseAction: seekBy(-5)

    onLiveChanged: syncPositionRef()
    onActivePlayerChanged: cancelSeek()
    onTrackIdChanged: cancelSeek()
    onCanSeekChanged: {
        if (!canSeek)
            cancelSeek();
    }
    onActualValueChanged: {
        if (!seeking && previewRatio >= 0 && Math.abs(actualValue - previewRatio) < 0.002)
            clearPreview();
    }
    onValueChanged: sine.requestPaint()
    onPhaseChanged: sine.requestPaint()
    onProgressColorChanged: sine.requestPaint()
    onTrackColorChanged: sine.requestPaint()
    Component.onCompleted: syncPositionRef()
    Component.onDestruction: {
        if (positionRefHeld)
            MprisController.removePositionRef();
        if (seeking)
            player.isSeeking = false;
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

    M3WaveProgress {
        anchors.fill: parent
        visible: root.progressStyle === "material"
        value: root.value
        actualValue: root.actualValue
        showActualPlaybackState: root.seeking
        lineWidth: Theme.clavisProgressStrokeWidth
        wavelength: Theme.clavisProgressWavelength
        amp: Theme.clavisProgressAmplitude
        fillColor: root.progressColor
        playheadColor: root.progressColor
        trackColor: root.trackColor
        actualProgressColor: root.subduedColor
        isPlaying: visible && root.motionAllowed
        onFrameTicked: {
            if (!root.seeking)
                MprisController.refreshPosition(root.activePlayer);
        }
    }

    Canvas {
        id: sine
        anchors.fill: parent
        visible: root.progressStyle === "wave"
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: {
            if (visible)
                requestPaint();
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0)
                return;
            const stroke = Theme.clavisProgressStrokeWidth;
            const midpoint = height / 2;
            const end = Math.max(stroke / 2, Math.min(width - stroke / 2, width * root.value));
            const gap = Theme.spacingS;
            ctx.lineWidth = stroke;
            ctx.lineCap = "round";
            ctx.strokeStyle = root.trackColor;
            ctx.beginPath();
            ctx.moveTo(Math.min(width - stroke / 2, end + gap), midpoint);
            ctx.lineTo(width - stroke / 2, midpoint);
            ctx.stroke();
            ctx.strokeStyle = root.progressColor;
            ctx.beginPath();
            const amplitude = Theme.clavisProgressAmplitude;
            const wavelength = Theme.clavisProgressWavelength;
            for (let x = stroke / 2; x <= end; x += stroke / 2) {
                const envelope = Math.min(1, x / gap, (end - x) / gap);
                const y = midpoint + Math.sin(x / wavelength * Math.PI * 2 - root.phase) * amplitude * envelope;
                if (x === stroke / 2)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.stroke();
            ctx.fillStyle = root.progressColor;
            ctx.beginPath();
            ctx.arc(width - stroke / 2, midpoint, stroke / 2, 0, Math.PI * 2);
            ctx.fill();
            if (!root.seeking)
                return;
            ctx.strokeStyle = root.subduedColor;
            ctx.beginPath();
            ctx.moveTo(width * root.actualValue, Theme.spacingXS);
            ctx.lineTo(width * root.actualValue, height - Theme.spacingXS);
            ctx.stroke();
            ctx.strokeStyle = root.progressColor;
            ctx.beginPath();
            ctx.moveTo(end, Theme.spacingXS);
            ctx.lineTo(end, height - Theme.spacingXS);
            ctx.stroke();
        }
    }

    FrameAnimation {
        running: sine.visible && root.motionAllowed
        onTriggered: {
            root.phase = (root.phase + frameTime * Theme.clavisProgressSpeed * Math.PI * 2) % (Math.PI * 2);
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
