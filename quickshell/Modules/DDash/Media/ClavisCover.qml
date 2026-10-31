pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import "../../../DCommon/Widgets/MaterialShapes.js" as Shapes
import "../../../Common/Spectrum.js" as Spectrum

Item {
    id: root

    required property var player
    property string artUrl: ""
    property bool caelestia: false
    property color accent: MediaAccentService.accent
    property real rotationAngle: 0
    property bool spectrumHeld: false

    readonly property bool live: visible && player.live
    readonly property bool moving: live && !!player.presentation?.playing && !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
    readonly property bool spectrumWanted: caelestia && moving && SettingsData.audioVisualizerEnabled
    readonly property real spectrumInset: caelestia ? Theme.clavisSpectrumMaxHeight + Theme.clavisSpectrumGap : 0
    readonly property list<real> contour: Shapes.polarProfile("cookie9", Theme.clavisSpectrumCount)
    readonly property list<real> spectrum: spectrumHeld ? Spectrum.aggregate(CavaService.spectrumValues, Theme.clavisSpectrumCount) : Array(Theme.clavisSpectrumCount).fill(0)

    onSpectrumWantedChanged: syncSpectrum()
    onSpectrumChanged: ring.requestPaint()
    onAccentChanged: ring.requestPaint()
    Component.onCompleted: syncSpectrum()
    Component.onDestruction: {
        if (spectrumHeld)
            CavaService.releaseSpectrum(root);
    }

    function syncSpectrum() {
        if (spectrumWanted === spectrumHeld)
            return;
        spectrumHeld = spectrumWanted;
        if (spectrumHeld) {
            CavaService.acquireSpectrum(root);
            return;
        }
        CavaService.releaseSpectrum(root);
    }

    FrameAnimation {
        running: root.spectrumWanted
        onTriggered: root.rotationAngle = (root.rotationAngle + frameTime * 360 * 1000 / Theme.clavisCoverRotationDuration) % 360
    }

    Canvas {
        id: ring
        anchors.fill: parent
        visible: root.caelestia && SettingsData.audioVisualizerEnabled && CavaService.cavaAvailable
        rotation: root.rotationAngle
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: {
            if (visible)
                requestPaint();
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineCap = "round";
            ctx.lineWidth = Theme.clavisSpectrumBarWidth;
            ctx.strokeStyle = root.accent;
            const count = Theme.clavisSpectrumCount;
            const size = Math.max(0, Math.min(width, height) - root.spectrumInset * 2);
            for (let i = 0; i < count; i++) {
                const angle = -Math.PI + Math.PI * 2 * i / count;
                const radius = (root.contour[i] ?? 0.5) * size + Theme.clavisSpectrumGap;
                const bar = Theme.clavisSpectrumMinHeight + (root.spectrum[i] ?? 0) * Theme.clavisSpectrumMaxHeight;
                const dx = Math.cos(angle);
                const dy = Math.sin(angle);
                ctx.beginPath();
                ctx.moveTo(width / 2 + dx * radius, height / 2 + dy * radius);
                ctx.lineTo(width / 2 + dx * (radius + bar), height / 2 + dy * (radius + bar));
                ctx.stroke();
            }
        }
    }

    ClippingRectangle {
        id: artwork
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width, parent.height) - root.spectrumInset * 2)
        height: width
        radius: root.caelestia ? 0 : Theme.cornerRadius
        color: MediaAccentService.accentSecondaryContainer
        antialiasing: true
        layer.enabled: root.caelestia
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cookieMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Image {
            id: artImage
            anchors.fill: parent
            source: root.artUrl
            sourceSize.width: artwork.width
            sourceSize.height: artwork.height
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        DIcon {
            anchors.centerIn: parent
            name: "music_note"
            size: Theme.iconSizeLarge
            color: MediaAccentService.onAccentSecondaryContainer
            visible: artImage.status !== Image.Ready
        }
    }

    Item {
        id: cookieMask
        width: artwork.width
        height: artwork.height
        layer.enabled: root.caelestia
        visible: false

        Shape {
            anchors.fill: parent
            rotation: root.rotationAngle
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillColor: Theme.withAlpha(Theme.surface, 1)
                PathSvg {
                    path: Shapes.buildPath("cookie9", artwork.width, artwork.height, false)
                }
            }
        }
    }
}
