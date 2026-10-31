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
import "../../../Common/ClavisCoverGeometry.js" as CoverGeometry

Item {
    id: root

    required property var player
    property string artUrl: ""
    property bool caelestia: false
    property color accent: MediaAccentService.accent
    property real rotationAngle: 0
    property bool spectrumHeld: false

    readonly property bool live: visible && player.live && (Window.window?.visible ?? false)
    readonly property bool moving: live && !!player.presentation?.playing && !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
    readonly property bool spectrumWanted: caelestia && moving
    readonly property real artworkSize: Math.min(width, height) * (caelestia ? Theme.clavisCaelestiaArtRatio : 1)
    readonly property real spectrumScale: Math.min(1, Math.min(width, height) / Theme.clavisSpectrumCoverSize)
    readonly property list<real> contour: Shapes.polarProfile("cookie9", Theme.clavisContourSamples)
    readonly property list<real> spectrum: spectrumHeld ? Spectrum.peakBins(CavaService.spectrumValues, Theme.clavisSpectrumCount) : Array(Theme.clavisSpectrumCount).fill(0)

    onSpectrumWantedChanged: syncSpectrum()
    onSpectrumChanged: ring.requestPaint()
    onRotationAngleChanged: ring.requestPaint()
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
        running: root.caelestia && root.moving
        onTriggered: root.rotationAngle = (root.rotationAngle - frameTime * 360 * 1000 / Theme.clavisCoverRotationDuration) % 360
    }

    Canvas {
        id: ring
        anchors.fill: parent
        anchors.margins: -Theme.clavisSpectrumMaxHeight * root.spectrumScale
        visible: root.caelestia
        opacity: root.spectrumWanted && CavaService.spectrumAvailable ? 1 : Theme.clavisSpectrumRestOpacity
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
            ctx.lineWidth = Theme.clavisSpectrumBarWidth * root.spectrumScale;
            ctx.strokeStyle = root.accent;
            const count = Theme.clavisSpectrumCount;
            for (let i = 0; i < count; i++) {
                const degrees = 360 * i / count;
                const angle = degrees * Math.PI / 180;
                const radius = CoverGeometry.radiusAtAngle(root.contour, degrees - root.rotationAngle) * root.artworkSize + Theme.clavisSpectrumGap * root.spectrumScale;
                const bar = (Theme.clavisSpectrumMinHeight + (root.spectrum[i] ?? 0) * (Theme.clavisSpectrumMaxHeight - Theme.clavisSpectrumMinHeight)) * root.spectrumScale;
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
        width: Math.max(0, root.artworkSize)
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
