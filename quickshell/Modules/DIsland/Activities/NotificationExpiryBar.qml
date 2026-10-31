pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import "../../../Common/TransientExpiry.js" as TransientExpiry

Rectangle {
    id: root

    required property var controller
    readonly property real startedAt: controller.notificationStartedAt
    readonly property real expiresAt: controller.notificationExpiresAt
    readonly property real pausedProgress: controller.notificationPausedProgress
    readonly property bool counting: controller.notificationCounting
    property real progress: 1

    visible: controller.notificationCountdown && controller.notificationActive && controller.notificationTimeout > 0 && (Window.window?.visible ?? false)
    height: Theme.spacingXXS
    radius: height / 2
    color: Theme.surfaceVariant

    function refresh() {
        countdown.stop();
        if (!visible)
            return;
        progress = counting ? TransientExpiry.remainingRatio(startedAt, expiresAt, Date.now()) : pausedProgress;
        if (!counting)
            return;
        countdown.from = progress;
        countdown.duration = Math.max(0, expiresAt - Date.now());
        countdown.start();
    }

    onStartedAtChanged: Qt.callLater(refresh)
    onExpiresAtChanged: Qt.callLater(refresh)
    onPausedProgressChanged: Qt.callLater(refresh)
    onCountingChanged: Qt.callLater(refresh)
    onVisibleChanged: Qt.callLater(refresh)
    Component.onCompleted: refresh()

    Rectangle {
        width: parent.width * root.progress
        height: parent.height
        radius: parent.radius
        color: root.controller.notificationCountdown ? Theme.primary : "transparent"
    }

    NumberAnimation {
        id: countdown

        target: root
        property: "progress"
        to: 0
        easing.type: Easing.Linear
    }
}
