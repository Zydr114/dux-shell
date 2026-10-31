pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets

Item {
    id: root

    required property var notificationModel
    required property var controller
    readonly property real contentPadding: Theme.spacingL + Theme.spacingXS
    implicitHeight: contentPadding * 2 + header.height + Theme.spacingM + message.implicitHeight + (actions.visible ? Theme.spacingM + actions.height : 0)

    function reportHeight() {
        if (width > 0)
            root.controller.setNotificationExpandedHeight(implicitHeight);
    }

    // The loader evaluates opacity while creating the face, before size feedback can safely change its target.
    onImplicitHeightChanged: Qt.callLater(root.reportHeight)
    onWidthChanged: Qt.callLater(root.reportHeight)
    Component.onCompleted: Qt.callLater(root.reportHeight)

    NotificationExpiryBar {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: root.contentPadding
            rightMargin: root.contentPadding
            bottomMargin: Theme.spacingXS
        }
        controller: root.controller
    }

    Item {
        anchors {
            fill: parent
            margins: root.contentPadding
        }

        Row {
            id: header

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: Theme.iconSizeLarge + Theme.spacingM
            spacing: Theme.spacingM

            DCircularImage {
                anchors.verticalCenter: parent.verticalCenter
                width: header.height
                height: width
                imageSource: root.notificationModel.imageSource
                fallbackIcon: root.notificationModel.fallbackIcon
                fallbackText: root.notificationModel.fallbackText
                cacheImages: false
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - header.height - closeButton.width - parent.spacing * 2
                spacing: Theme.spacingXXS

                StyledText {
                    width: parent.width
                    text: root.notificationModel.appName
                    color: Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: root.notificationModel.timeText
                    color: Theme.surfaceTextSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            DActionButton {
                id: closeButton

                anchors.verticalCenter: parent.verticalCenter
                iconName: "close"
                Accessible.name: I18n.tr("Dismiss")
                iconSize: Theme.iconSizeSmall
                buttonSize: Theme.buttonHeightS
                onClicked: root.notificationModel.dismiss()
            }
        }

        Column {
            id: message

            anchors {
                left: parent.left
                right: parent.right
                top: header.bottom
                topMargin: Theme.spacingM
            }
            spacing: Theme.spacingS

            StyledText {
                width: parent.width
                text: root.notificationModel.summary
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightBold
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: root.notificationModel.body
                color: Theme.surfaceTextMedium
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }

        Row {
            id: actions

            anchors {
                right: parent.right
                bottom: parent.bottom
            }
            visible: root.notificationModel.hasAction
            height: visible ? Theme.buttonHeightS : 0
            spacing: Theme.spacingS

            DButton {
                visible: root.notificationModel.hasAction
                height: parent.height
                radius: Theme.fullRadius(width, height)
                text: root.notificationModel.actionLabel
                backgroundColor: Theme.primary
                textColor: Theme.onPrimary
                buttonHeight: parent.height
                horizontalPadding: Theme.spacingL
                onClicked: root.notificationModel.activate()
            }
        }
    }
}
