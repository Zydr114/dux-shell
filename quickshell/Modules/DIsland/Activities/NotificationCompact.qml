pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets

Item {
    id: root

    required property var notificationModel
    required property var controller
    property bool dense: false
    property real iconSize: Theme.iconSizeLarge

    readonly property bool isVertical: root.controller.isVertical
    readonly property string headerText: root.notificationModel.appName + (root.notificationModel.timeText ? " · " + root.notificationModel.timeText : "")
    readonly property string summaryText: root.dense && root.notificationModel.appName ? root.notificationModel.appName + " · " + root.notificationModel.summary : root.notificationModel.summary
    readonly property real measuredWidth: Theme.spacingM * 2 + root.iconSize + Theme.spacingS + Math.max(root.dense ? 0 : headerLabel.implicitWidth, summaryLabel.implicitWidth)
    readonly property bool countdownVisible: controller.notificationCountdown && controller.notificationTimeout > 0
    readonly property real countdownSpace: countdownVisible ? Theme.spacingXXS + Theme.spacingXS + Theme.spacingXXS : 0
    readonly property real measuredHeight: Math.max(root.iconSize, (root.dense ? 0 : headerLabel.implicitHeight + textColumn.spacing) + summaryLabel.implicitHeight) + Theme.spacingXS * 2 + countdownSpace

    function reportSize() {
        root.controller.setNotificationContentLength(root.isVertical ? root.iconSize + Theme.spacingS * 2 : root.measuredWidth);
        root.controller.setNotificationContentThickness(root.isVertical ? root.controller.compactFaceThickness : root.measuredHeight);
    }

    onMeasuredWidthChanged: Qt.callLater(reportSize)
    onMeasuredHeightChanged: Qt.callLater(reportSize)
    onIsVerticalChanged: Qt.callLater(reportSize)
    Component.onCompleted: Qt.callLater(reportSize)

    // A side strip only fits the sender's icon; the text lives in the expanded face.
    DCircularImage {
        anchors.centerIn: parent
        visible: root.isVertical
        width: root.iconSize
        height: width
        imageSource: root.notificationModel.imageSource
        fallbackIcon: root.notificationModel.fallbackIcon
        fallbackText: root.notificationModel.fallbackText
        cacheImages: false
    }

    NotificationExpiryBar {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: Theme.spacingM
            rightMargin: Theme.spacingM
            bottomMargin: Theme.spacingXS
        }
        controller: root.controller
    }

    Row {
        visible: !root.isVertical
        anchors {
            fill: parent
            leftMargin: Theme.spacingM
            rightMargin: Theme.spacingM
            topMargin: Theme.spacingXS
            bottomMargin: Theme.spacingXS + root.countdownSpace
        }
        spacing: Theme.spacingS

        DCircularImage {
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: width
            imageSource: root.notificationModel.imageSource
            fallbackIcon: root.notificationModel.fallbackIcon
            fallbackText: root.notificationModel.fallbackText
            cacheImages: false
        }

        Column {
            id: textColumn

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - root.iconSize - parent.spacing)
            spacing: Theme.spacingXXS

            StyledText {
                id: headerLabel

                width: parent.width
                visible: !root.dense
                text: root.headerText
                color: Theme.surfaceTextSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }

            StyledText {
                id: summaryLabel

                width: parent.width
                text: root.summaryText
                color: Theme.surfaceText
                font.pixelSize: root.dense ? Theme.fontSizeSmall : Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
    }
}
