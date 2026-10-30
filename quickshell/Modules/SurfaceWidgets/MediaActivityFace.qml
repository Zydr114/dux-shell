pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DBar.Widgets
import qs.DCommon.Widgets
import qs.Widgets

Item {
    id: root

    required property var mediaModel

    property bool dense: false
    property real contentScale: 1
    property bool isVertical: false
    property real artworkSize: Theme.iconSizeLarge
    readonly property real textGutter: Theme.spacingXS
    readonly property real cavaWidth: 20
    readonly property real minTextWidth: 48
    readonly property real clockLeadPad: Theme.spacingXS / 2
    readonly property real clockTrailPad: Theme.spacingS
    readonly property real clockPillHeight: root.dense ? Math.max(22, root.artworkSize - Theme.spacingXS) : 32
    // A fully rounded side strip crowds square content, so the vertical face insets on both axes.
    readonly property real verticalPad: Theme.spacingS
    readonly property real verticalArtworkSize: Math.max(12, Math.min(root.artworkSize, root.width - root.verticalPad * 2))
    property bool clockVisible: false
    readonly property real naturalTextWidth: Math.max(root.minTextWidth, titleMetrics.width, root.dense ? 0 : artistMetrics.width) + root.textGutter * 2
    readonly property real measuredWidth: {
        let width = Theme.spacingS + root.artworkSize + Theme.spacingXS + root.cavaWidth + Theme.spacingXS + root.naturalTextWidth + Theme.spacingXS;
        if (root.clockVisible)
            width += clockText.width + Theme.spacingXS * 2 + Theme.spacingS;
        return width;
    }

    implicitWidth: isVertical ? artworkSize + verticalPad * 2 : measuredWidth
    implicitHeight: isVertical ? verticalFace.implicitHeight + verticalPad * 2 : artworkSize
    readonly property bool clockHovered: enabled && visible && ((clockArea.visible && clockArea.containsMouse) || (verticalClockArea.visible && verticalClockArea.containsMouse))
    signal clockClicked

    StyledTextMetrics {
        id: titleMetrics

        font.pixelSize: Theme.fontSizeSmall * root.contentScale
        font.weight: Theme.fontWeightMedium
        text: root.mediaModel.title
    }

    StyledTextMetrics {
        id: artistMetrics

        font.pixelSize: Math.max(9, Theme.fontSizeSmall - 2) * root.contentScale
        text: root.dense ? "" : root.mediaModel.artist
    }

    MediaArtwork {
        id: artwork

        anchors {
            left: parent.left
            leftMargin: Theme.spacingS
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
            right: root.clockVisible ? rightActivity.left : parent.right
            rightMargin: Theme.spacingXS
            verticalCenter: parent.verticalCenter
        }
        height: root.artworkSize
        spacing: Theme.spacingXS

        AudioVisualization {
            anchors.verticalCenter: parent.verticalCenter
            width: root.cavaWidth
            height: parent.height
            maxBarHeight: Math.max(3, height - 2)
            idleIconName: "graphic_eq"
        }

        Column {
            width: parent.width - root.cavaWidth - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            ScrollingText {
                x: root.textGutter
                width: parent.width - root.textGutter * 2
                text: root.mediaModel.title
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall * root.contentScale
                font.weight: Theme.fontWeightMedium
                active: root.enabled && root.mediaModel.playing
                holdStartMs: 1600
                holdEndMs: 1200
                pxPerMs: 1 / 62.5
                overscroll: root.textGutter
            }

            StyledText {
                x: root.textGutter
                width: parent.width - root.textGutter * 2
                visible: !root.dense
                text: root.mediaModel.artist
                color: Theme.surfaceTextSecondary
                font.pixelSize: Math.max(9, Theme.fontSizeSmall - 2) * root.contentScale
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
    }

    Item {
        id: rightActivity

        anchors {
            right: parent.right
            rightMargin: Theme.spacingS
            verticalCenter: parent.verticalCenter
        }
        width: root.clockVisible ? (clockText.width + Theme.spacingXS * 2) : 0
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
                fontSize: Theme.fontSizeSmall * root.contentScale
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

    // A side strip has no room for track text, so the vertical face is artwork over the meter.
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
            maxBarHeight: Math.max(3, height - 2)
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
