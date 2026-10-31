pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import "../../Common/htmlElide.js" as HtmlElide

QtObject {
    id: root

    required property IslandController controller
    required property var targetScreen
    property bool enabled: true

    property var currentWrapper: null
    property bool releasingTimeout: false
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string timeText: ""
    property string imageSource: ""
    property string fallbackIcon: "material:notifications"
    property string fallbackText: ""
    property string actionLabel: ""
    property bool critical: false
    property bool important: false

    readonly property bool hasAction: actionLabel.length > 0
    readonly property bool ownsTimeout: (controller?.notificationActive ?? false) || (controller?.notificationHeldForSystem ?? false)
    readonly property int wrapperTimeoutDuration: wrapperTimeout(currentWrapper)
    readonly property string wrapperPresentationKey: currentWrapper ? JSON.stringify([currentWrapper.appName, currentWrapper.summary, currentWrapper.body, currentWrapper.displayImage, currentWrapper.fallbackIconName, currentWrapper.urgency, (currentWrapper.actions || []).map(action => action.text)]) : ""
    onWrapperPresentationKeyChanged: {
        if (!currentWrapper)
            return;
        updateDisplayFields();
        controller.refreshNotification();
    }
    readonly property string visibleNotificationIds: NotificationService.visibleNotifications.map(wrapper => wrapper.seq).join(",")
    onOwnsTimeoutChanged: applyWrapperTimeoutHold()
    onWrapperTimeoutDurationChanged: {
        if (currentWrapper)
            controller.notificationTimeout = wrapperTimeoutDuration;
    }
    onVisibleNotificationIdsChanged: {
        if (enabled)
            syncVisibleNotifications();
    }

    function scheduleDisplayFieldClear() {
        displayFieldClearTimer.restart();
    }

    function clearDisplayFields() {
        if (currentWrapper)
            return;
        appName = "";
        summary = "";
        body = "";
        timeText = "";
        imageSource = "";
        fallbackIcon = "material:notifications";
        fallbackText = "";
        actionLabel = "";
        critical = false;
        important = false;
    }

    function wrapperTimeout(wrapper) {
        const interval = wrapper?.timer?.interval ?? -1;
        return interval >= 0 ? interval : 5000;
    }

    function applyWrapperTimeoutHold() {
        const timer = currentWrapper?.timer;
        if (!timer)
            return;
        if (ownsTimeout) {
            timer.stop();
            return;
        }
        if (currentWrapper.popup && timer.interval > 0)
            timer.restart();
    }

    function releaseWrapperTimeoutHold() {
        const timer = currentWrapper?.timer;
        if (!timer || !currentWrapper.popup || timer.interval <= 0)
            return;
        releasingTimeout = true;
        timer.restart();
        releasingTimeout = false;
    }

    function adopt(wrapper) {
        if (!enabled || !wrapper || !NotificationService.isFocusedScreen(root.targetScreen))
            return false;

        const isCritical = wrapper.urgency === NotificationUrgency.Critical;
        if (!controller.canRequestNotification(isCritical))
            return false;

        releaseWrapperTimeoutHold();
        displayFieldClearTimer.stop();
        currentWrapper = wrapper;
        updateDisplayFields();
        controller.notificationTimeout = wrapperTimeout(wrapper);
        const accepted = controller.requestNotification(isCritical);
        applyWrapperTimeoutHold();
        return accepted;
    }

    function updateDisplayFields() {
        const wrapper = currentWrapper;
        if (!wrapper)
            return;
        appName = wrapper.appName || I18n.tr("Notification", "island notification face: fallback app name");
        summary = HtmlElide.plainText(wrapper.summary) || appName;
        body = HtmlElide.plainText(wrapper.body);
        timeText = wrapper.timeStr || "";
        imageSource = wrapper.displayImage;
        fallbackIcon = wrapper.fallbackIconName || "material:notifications";
        fallbackText = appName.charAt(0).toUpperCase();
        critical = wrapper.urgency === NotificationUrgency.Critical;
        important = !critical && wrapper.urgency === NotificationUrgency.Normal && fallbackIcon.startsWith("material:battery");
        const actions = wrapper.actions || [];
        actionLabel = actions.length > 0 ? (actions[0].text || I18n.tr("Open", "island notification face: default action button")) : "";
    }

    function refreshDeduplicated(wrapper) {
        if (!wrapper || wrapper !== currentWrapper)
            return;
        controller.refreshNotification();
        applyWrapperTimeoutHold();
    }

    function expirePopup() {
        const wrapper = currentWrapper;
        currentWrapper = null;
        scheduleDisplayFieldClear();
        if (wrapper)
            wrapper.popup = false;
    }

    function syncVisibleNotifications() {
        const visible = NotificationService.visibleNotifications || [];
        const latest = visible.length > 0 ? visible[visible.length - 1] : null;
        if (latest && (latest === currentWrapper || adopt(latest)))
            return;
        if (!currentWrapper || visible.indexOf(currentWrapper) !== -1)
            return;
        currentWrapper = null;
        controller.completeNotification();
        scheduleDisplayFieldClear();
    }

    onEnabledChanged: {
        if (enabled) {
            syncVisibleNotifications();
            return;
        }
        if (!currentWrapper)
            return;
        releaseWrapperTimeoutHold();
        currentWrapper = null;
        controller.completeNotification();
        scheduleDisplayFieldClear();
    }

    function activate() {
        const actions = currentWrapper?.actions || [];
        if (actions.length > 0)
            actions[0].invoke();
        dismiss();
    }

    function dismiss() {
        const wrapper = currentWrapper;
        currentWrapper = null;
        controller.completeNotification();
        scheduleDisplayFieldClear();
        if (wrapper)
            NotificationService.dismissNotification(wrapper);
    }

    property Connections notificationConnections: Connections {
        target: NotificationService
        enabled: root.enabled

        function onNotificationDeduplicated(wrapper) {
            root.refreshDeduplicated(wrapper);
        }
    }

    property Connections controllerConnections: Connections {
        target: root.controller
        function onNotificationExpired() {
            root.expirePopup();
        }
    }

    // NotificationService starts this timer after publishing a new wrapper; Island owns its deadline.
    property Connections wrapperTimerConnections: Connections {
        target: root.currentWrapper?.timer ?? null
        function onRunningChanged() {
            if (root.enabled && root.ownsTimeout && !root.releasingTimeout && root.currentWrapper?.timer?.running)
                root.currentWrapper.timer.stop();
        }
    }

    property Timer displayFieldClearTimer: Timer {
        interval: 400
        onTriggered: root.clearDisplayFields()
    }

    Component.onCompleted: syncVisibleNotifications()
    Component.onDestruction: releaseWrapperTimeoutHold()
}
