pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Services
import qs.Widgets
import "../../../Common/CompactLyrics.js" as CompactLyrics
import "../../../Common/Spectrum.js" as Spectrum

Item {
    id: root

    required property var mediaModel
    required property real maximumWidth
    required property real resizeThreshold
    required property real shortGapSeconds
    required property string interludeText
    required property bool keepInterludeWidth
    readonly property LyricsController lyrics: LyricsService.controller
    readonly property bool live: enabled && visible && (Window.window?.visible ?? false) && mediaModel.available
    readonly property bool sampling: live && mediaModel.playing && !SettingsData.reduceMotion
    readonly property bool animationsEnabled: live && !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
    readonly property string lineText: live && lyrics.synced ? CompactLyrics.lineText(lyrics.lines, lyrics.activeIndex, lyrics.sampleTime, shortGapSeconds, lyrics.focusedGroups) : ""
    readonly property string displayText: {
        if (!LyricsService.available)
            return I18n.tr("Unavailable");
        if (lyrics.pending || lyrics.state === "idle")
            return I18n.tr("Loading…");
        switch (lyrics.state) {
        case "error":
            return I18n.tr("Unavailable");
        case "instrumental":
            return I18n.tr("Instrumental", "Track has no lyrics because it is instrumental");
        case "ready":
            if (!lyrics.synced)
                return I18n.tr("Unsynced", "Lyrics have no timestamps");
            return lineText || interludeText;
        }
        return I18n.tr("No results");
    }
    readonly property real fixedWidth: Theme.clavisLyricsEndPadding * 2 + Theme.clavisLyricsCoverSize + Theme.clavisLyricsGap * 2 + Theme.clavisLyricsSpectrumSize
    readonly property real minimumWidth: fixedWidth + Theme.clavisLyricsMinTextWidth
    readonly property real naturalWidth: fixedWidth + Math.max(Theme.clavisLyricsMinTextWidth, Math.ceil(Math.max(measure.width, measure.advanceWidth)) + Theme.spacingXS)
    readonly property bool interlude: lyrics.state === "ready" && lyrics.synced && lineText === ""
    readonly property list<real> levels: spectrumHeld && CavaService.spectrumAvailable ? Spectrum.peakBins(CavaService.spectrumValues, Theme.clavisLyricsSpectrumCount) : []
    property bool spectrumHeld: false
    property bool initialized: false
    property real shift: 0
    property real retainedWidth: 0

    implicitWidth: retainedWidth
    implicitHeight: Theme.clavisLyricsHeight
    clip: true

    onDisplayTextChanged: {
        if (initialized)
            turnTo(displayText);
    }
    onAnimationsEnabledChanged: {
        if (!animationsEnabled) {
            slide.stop();
            shift = 0;
            outgoing.text = "";
        }
    }
    onSamplingChanged: syncSpectrum()
    onNaturalWidthChanged: Qt.callLater(root.updateWidth)
    onMaximumWidthChanged: Qt.callLater(root.updateWidth)
    onResizeThresholdChanged: Qt.callLater(root.updateWidth)
    onKeepInterludeWidthChanged: Qt.callLater(root.updateWidth)
    onInterludeChanged: Qt.callLater(root.updateWidth)
    Component.onCompleted: {
        initialized = true;
        updateWidth();
        turnTo(displayText);
        syncSpectrum();
    }
    Component.onDestruction: {
        if (spectrumHeld)
            CavaService.releaseSpectrum(root);
    }

    function updateWidth() {
        if (!initialized)
            return;
        const currentWidth = retainedWidth;
        retainedWidth = CompactLyrics.resolveWidth(currentWidth, naturalWidth, minimumWidth, maximumWidth, resizeThreshold, interlude && keepInterludeWidth);
    }

    function syncSpectrum() {
        if (sampling === spectrumHeld)
            return;
        spectrumHeld = sampling;
        if (spectrumHeld) {
            CavaService.acquireSpectrum(root);
            return;
        }
        CavaService.releaseSpectrum(root);
    }

    function turnTo(text) {
        slide.stop();
        const animate = animationsEnabled && current.text !== "";
        outgoing.text = animate ? current.text : "";
        current.text = text;
        shift = animate ? 1 : 0;
        if (animate)
            slide.start();
    }

    LyricsSubscription {
        active: root.live && LyricsService.available
    }

    StyledTextMetrics {
        id: measure
        text: root.displayText
        font.pixelSize: Theme.clavisLyricsFontSize
        font.weight: Theme.fontWeightBold
        renderType: currentLabel.renderType
    }

    MediaArtwork {
        id: cover
        anchors.left: parent.left
        anchors.leftMargin: Theme.clavisLyricsEndPadding
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.clavisLyricsCoverSize
        height: width
        cornerRadius: Theme.clavisLyricsCoverRadius
        artUrl: root.mediaModel.artUrl
    }

    Item {
        id: lineViewport
        anchors.left: cover.right
        anchors.leftMargin: Theme.clavisLyricsGap
        anchors.right: spectrum.left
        anchors.rightMargin: Theme.clavisLyricsGap
        height: root.height
        clip: true

        Item {
            id: outgoing
            property alias text: outgoingLabel.text
            width: parent.width
            height: parent.height
            y: (root.shift - 1) * height
            opacity: root.shift
            visible: text !== ""

            StyledText {
                id: outgoingLabel
                anchors.fill: parent
                font: measure.font
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                maximumLineCount: 1
                Accessible.ignored: true
            }
        }

        Item {
            id: current
            property alias text: currentLabel.text
            width: parent.width
            height: parent.height
            y: root.shift * height
            opacity: 1 - root.shift

            StyledText {
                id: currentLabel
                anchors.fill: parent
                font: measure.font
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    NumberAnimation {
        id: slide
        target: root
        property: "shift"
        to: 0
        duration: Theme.clavisLyricsTransitionDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
        onFinished: outgoing.text = ""
    }

    Row {
        id: spectrum
        anchors.right: parent.right
        anchors.rightMargin: Theme.clavisLyricsEndPadding
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.clavisLyricsSpectrumSize
        height: width
        spacing: Theme.clavisLyricsSpectrumGap

        Repeater {
            model: Theme.clavisLyricsSpectrumCount

            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.clavisLyricsSpectrumBarWidth
                height: width + (spectrum.height - width) * (root.levels[index] ?? 0)
                radius: width / 2
                color: Theme.surfaceText

                Behavior on height {
                    enabled: root.animationsEnabled
                    NumberAnimation {
                        duration: Theme.clavisLyricsSpectrumDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                    }
                }
            }
        }
    }
}
