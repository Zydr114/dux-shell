pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DBar.Widgets
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

Item {
    id: root

    required property var mediaModel

    property bool dense: false
    property real contentScale: 1
    property bool isVertical: false
    property real artworkSize: Theme.iconSizeLarge
    property bool clockVisible: false
    property string textMode: "title"
    readonly property bool lyricActive: textMode !== "title" && LyricsService.allowed && (mediaModel.lyricText ?? "").length > 0
    readonly property string primaryText: textMode === "lyrics" && lyricActive ? mediaModel.lyricText : mediaModel.title
    readonly property string secondaryText: textMode === "title-lyrics" && lyricActive ? mediaModel.lyricText : mediaModel.artist
    readonly property bool secondaryVisible: !dense || (textMode === "title-lyrics" && lyricActive)
    readonly property real textGutter: Theme.spacingXS
    readonly property real cavaWidth: Theme.iconSizeSmall
    readonly property real minTextWidth: Theme.iconSizeLarge + Theme.spacingM
    readonly property real clockLeadPad: Theme.spacingXS / 2
    readonly property real clockTrailPad: Theme.spacingS
    readonly property real clockPillHeight: Math.min(root.artworkSize, Theme.buttonHeightS)
    readonly property real fullClockExtent: clockVisible ? fullClockMetrics.width + Theme.spacingS + Theme.spacingXS * 2 : 0
    readonly property bool clockSecondsVisible: width >= measuredWidth
    readonly property real clockExtent: clockVisible ? clockText.width + Theme.spacingS + Theme.spacingXS * 2 : 0
    readonly property real verticalPad: Theme.spacingS
    readonly property real verticalArtworkSize: Math.max(Theme.spacingM, Math.min(root.artworkSize, root.width - root.verticalPad * 2))
    readonly property real naturalTextWidth: Math.max(root.minTextWidth, titleMetrics.width, root.secondaryVisible ? artistMetrics.width : 0) + root.textGutter * 2
    readonly property real measuredWidth: Theme.spacingS * 2 + root.fullClockExtent + root.artworkSize + Theme.spacingXS * 3 + root.cavaWidth + root.naturalTextWidth
    readonly property bool meterVisible: width >= clockExtent + artworkSize + cavaWidth + naturalTextWidth + Theme.spacingS * 2 + Theme.spacingXS * 3

    implicitWidth: isVertical ? artworkSize + verticalPad * 2 : measuredWidth
    implicitHeight: isVertical ? verticalFace.implicitHeight + verticalPad * 2 : artworkSize
    readonly property bool clockHovered: enabled && visible && ((clockArea.visible && clockArea.containsMouse) || (verticalClockArea.visible && verticalClockArea.containsMouse))
    signal clockClicked

    LyricsSubscription {
        active: root.enabled && root.visible && (root.Window.window?.visible ?? false) && !root.isVertical && root.textMode !== "title" && root.mediaModel.available && LyricsService.allowed
    }

    StyledTextMetrics {
        id: fullClockMetrics

        font.pixelSize: Theme.clockTextSize(Theme.fontSizeSmall * root.contentScale)
        font.weight: Theme.fontWeightBold
        text: clockText.date.toLocaleTimeString(I18n.locale(), SettingsData.getEffectiveTimeFormat())
    }

    StyledTextMetrics {
        id: titleMetrics

        font.pixelSize: Theme.fontSizeSmall * root.contentScale
        font.weight: Theme.fontWeightMedium
        text: root.primaryText
    }

    StyledTextMetrics {
        id: artistMetrics

        font.pixelSize: (Theme.fontSizeSmall - Theme.spacingXXS) * root.contentScale
        text: root.secondaryVisible ? root.secondaryText : ""
    }

    Item {
        id: clockActivity

        anchors {
            left: parent.left
            leftMargin: Theme.spacingS
            verticalCenter: parent.verticalCenter
        }
        width: root.clockVisible ? clockText.width + Theme.spacingXS * 2 : 0
        height: root.clockPillHeight
        visible: root.clockVisible && !root.isVertical

        Rectangle {
            anchors.fill: parent
            radius: Math.min(Theme.cornerRadiusFull, height / 2)
            color: clockArea.containsMouse ? Theme.surfaceTextHover : "transparent"

            ClockContent {
                id: clockText

                anchors.centerIn: parent
                displayMode: "time"
                showSeconds: root.clockSecondsVisible
                fontSize: Theme.fontSizeSmall * root.contentScale
                live: root.visible && root.enabled && (Window.window?.visible ?? false) && root.clockVisible && !root.isVertical
            }

            MouseArea {
                id: clockArea

                anchors.verticalCenter: parent.verticalCenter
                x: -root.clockLeadPad
                width: parent.width + root.clockLeadPad + root.clockTrailPad
                height: root.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clockClicked()
            }
        }
    }

    MediaArtwork {
        id: artwork

        anchors {
            left: parent.left
            leftMargin: Theme.spacingS + root.clockExtent
            verticalCenter: parent.verticalCenter
        }
        visible: !root.isVertical
        width: root.artworkSize
        height: width
        artUrl: root.mediaModel.artUrl
    }

    Row {
        visible: !root.isVertical
        anchors {
            left: artwork.right
            leftMargin: Theme.spacingXS
            right: parent.right
            rightMargin: Theme.spacingS
            verticalCenter: parent.verticalCenter
        }
        height: root.artworkSize
        spacing: Theme.spacingXS

        AudioVisualization {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.meterVisible
            width: root.cavaWidth
            height: parent.height
            enabled: root.enabled && root.visible && root.meterVisible
            maxBarHeight: Math.max(Theme.spacingXXS, height - Theme.spacingXXS)
            idleIconName: "graphic_eq"
        }

        Column {
            width: Math.max(0, parent.width - (root.meterVisible ? root.cavaWidth + parent.spacing : 0))
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            ScrollingText {
                x: root.textGutter
                width: Math.max(0, parent.width - root.textGutter * 2)
                text: root.primaryText
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall * root.contentScale
                font.weight: Theme.fontWeightMedium
                active: root.enabled && root.visible && root.mediaModel.playing
                holdStartMs: 1600
                holdEndMs: 1200
                pxPerMs: 1 / 62.5
                overscroll: root.textGutter
            }

            ScrollingText {
                x: root.textGutter
                width: Math.max(0, parent.width - root.textGutter * 2)
                visible: root.secondaryVisible
                text: root.secondaryText
                color: Theme.surfaceTextSecondary
                font.pixelSize: (Theme.fontSizeSmall - Theme.spacingXXS) * root.contentScale
                active: root.enabled && root.visible && root.lyricActive && root.mediaModel.playing
                overscroll: root.textGutter
            }
        }
    }

    // Side bars keep the cover and time readable; track text remains in the expanded panel.
    Column {
        id: verticalFace

        anchors.centerIn: parent
        visible: root.isVertical
        spacing: Theme.spacingXS

        MediaArtwork {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.verticalArtworkSize
            height: width
            artUrl: root.mediaModel.artUrl
        }

        AudioVisualization {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.verticalArtworkSize
            height: root.cavaWidth
            enabled: root.enabled && root.visible && root.isVertical
            maxBarHeight: Math.max(Theme.spacingXXS, height - Theme.spacingXXS)
            idleIconName: "graphic_eq"
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.clockVisible
            width: verticalClock.width
            height: verticalClock.height

            ClockContent {
                id: verticalClock

                vertical: true
                displayMode: "time"
                availableWidth: root.verticalArtworkSize
                fontSize: Theme.fontSizeSmall * root.contentScale
                live: root.visible && root.enabled && (Window.window?.visible ?? false) && root.clockVisible && root.isVertical
            }

            MouseArea {
                id: verticalClockArea

                anchors.centerIn: parent
                width: root.width
                height: parent.height + Theme.spacingXS
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clockClicked()
            }
        }
    }
}
