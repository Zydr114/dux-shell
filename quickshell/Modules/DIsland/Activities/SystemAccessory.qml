pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets

Item {
    id: root

    required property var systemModel
    property bool vertical: false
    property bool expanded: false
    readonly property real padding: height <= Theme.spacingXL ? Theme.spacingXXS : Theme.spacingS
    readonly property real iconSize: Theme.iconSizeSmall
    implicitWidth: Theme.iconSize + Theme.spacingL * 4
    implicitHeight: Theme.buttonHeightS + Theme.spacingXS
    Accessible.role: Accessible.Indicator
    Accessible.name: systemModel.title + ": " + systemModel.displayValue

    Rectangle {
        anchors.fill: parent
        visible: root.expanded
        color: Theme.surfaceContainerHigh
        radius: Theme.cornerRadiusSmall
    }

    Row {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            margins: root.padding
            bottomMargin: root.systemModel.levelActivity ? root.padding + Theme.spacingXS : root.padding
        }
        spacing: Theme.spacingXS

        DIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.systemModel.iconName
            size: root.iconSize
            color: root.systemModel.muted ? Theme.surfaceTextSecondary : Theme.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.vertical
            width: Math.max(0, parent.width - root.iconSize - parent.spacing)
            text: root.systemModel.displayValue
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            elide: Text.ElideRight
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: root.padding
            rightMargin: root.padding
            bottomMargin: root.height <= Theme.spacingXL ? Theme.spacingXXS : Theme.spacingXS
        }
        visible: root.systemModel.levelActivity
        height: Theme.spacingXXS
        radius: height / 2
        color: Theme.surfaceVariant

        Rectangle {
            width: parent.width * (root.systemModel.muted ? 0 : root.systemModel.ratio)
            height: parent.height
            radius: parent.radius
            color: Theme.primary
        }
    }
}
