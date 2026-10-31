import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets

ClippingRectangle {
    id: root
    property string metricId: ""
    property string label: ""
    property string iconName: ""
    property string valueText: ""
    property string supportingText: ""
    property string badgeText: ""
    property real usage: -1
    property var trend: []
    property bool trendVisible: false
    property color accent: Theme.primary
    property color foreground: Theme.onPrimary
    property real clipRadius: Theme.cornerRadiusL
    readonly property bool split: metricId === "network" || metricId === "disk"
    readonly property bool memory: metricId === "memory"
    radius: clipRadius
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: root.accent
    }
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * 0.52
        color: Theme.surfaceContainerHigh
        radius: Theme.cornerRadiusL
        visible: root.split
    }
    DMaterialShape {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -width * 0.3
        anchors.bottomMargin: -height * 0.3
        width: Math.min(parent.width, parent.height) * 0.65
        height: width
        shape: "cookie9"
        color: Theme.withAlpha(root.foreground, Theme.stateLayerHover)
        visible: !root.split && !root.memory
    }
    Rectangle {
        id: liquid
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - Theme.spacingM * 2
        height: width
        radius: Theme.cornerRadiusXL
        color: Theme.withAlpha(root.foreground, Theme.stateLayerFocus)
        clip: true
        visible: root.memory
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * Math.max(0, Math.min(1, root.usage))
            color: Theme.withAlpha(root.foreground, Theme.stateLayerPressed)
            Behavior on height {
                enabled: !SettingsData.reduceMotion
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }
        }
    }
    DSparkline {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        width: parent.width * 0.48
        height: parent.height * 0.35
        visible: !root.split && !root.memory && root.trendVisible
        values: root.trend
        maximum: 100
        lineColor: root.foreground
        lineWidth: Theme.outlineWidthFocused
    }
    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        width: root.split ? parent.width * 0.45 - Theme.spacingM : (root.trendVisible && !root.memory ? parent.width * 0.46 - Theme.spacingM : parent.width - Theme.spacingM * 2)
        spacing: Theme.spacingXXS
        DIcon {
            name: root.iconName
            size: Theme.iconSizeSmall
            color: root.foreground
        }
        StyledText {
            width: parent.width
            text: root.label
            color: root.foreground
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            elide: Text.ElideRight
        }
        StyledText {
            width: parent.width
            text: root.badgeText
            color: root.foreground
            font.pixelSize: Theme.fontSizeSmall
            visible: !root.split && text !== ""
            elide: Text.ElideRight
        }
    }
    Column {
        anchors.left: root.split ? parent.horizontalCenter : parent.left
        anchors.right: !root.split && !root.memory && root.trendVisible ? parent.horizontalCenter : parent.right
        anchors.bottom: root.split ? undefined : parent.bottom
        anchors.verticalCenter: root.split ? parent.verticalCenter : undefined
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingXXS
        Row {
            width: parent.width
            spacing: Theme.spacingXXS
            DIcon {
                visible: root.split
                name: "south"
                size: Theme.iconSizeSmall
                color: Theme.onSurface
            }
            StyledText {
                width: parent.width - (root.split ? Theme.iconSizeSmall + parent.spacing : 0)
                text: root.valueText
                color: root.split ? Theme.onSurface : root.foreground
                font.pixelSize: root.split ? Theme.fontSizeMedium : Theme.fontSizeXXLarge
                minimumPixelSize: Theme.fontSizeSmall
                fontSizeMode: Text.HorizontalFit
                font.weight: Theme.fontWeightMedium
                elide: Text.ElideRight
            }
        }
        Row {
            width: parent.width
            spacing: Theme.spacingXXS
            visible: root.split || (root.height >= Theme.buttonHeightM * 2 && !root.trendVisible)
            DIcon {
                visible: root.split
                name: "north"
                size: Theme.iconSizeSmall
                color: Theme.onSurfaceVariant
            }
            StyledText {
                width: parent.width - (root.split ? Theme.iconSizeSmall + parent.spacing : 0)
                text: root.split ? root.badgeText : root.supportingText
                color: root.split ? Theme.onSurfaceVariant : root.foreground
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }
    }
}
