pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

Rectangle {
    id: root

    property string groupId: ""
    property var groupConfig: null
    property var barConfig: null
    property var blurBarWindow: null
    property bool isVertical: false
    property real alongPosition: 0
    property real alongSize: 0
    property real crossPosition: 0
    property real crossSize: 0
    readonly property real blurRadius: radius
    readonly property bool blurEnabled: BlurService.available && (groupConfig?.blur === "on" || (groupConfig?.blur !== "off" && (blurBarWindow?.backgroundBlurEnabled ?? BlurService.enabled)))
    readonly property color surfaceColor: groupConfig?.tone === "primary" ? Theme.blend(Theme.surfaceContainerLow, Theme.primaryContainer, Theme.stateLayerDrag) : Theme.surfaceContainerLow

    x: isVertical ? crossPosition : alongPosition
    y: isVertical ? alongPosition : crossPosition
    width: isVertical ? crossSize : alongSize
    height: isVertical ? alongSize : crossSize
    visible: width > 0 && height > 0
    radius: Math.min(width, height) / 2
    color: Theme.withAlpha(surfaceColor, blurEnabled ? SettingsData.barTransparency(barConfig) : 1)
    border.width: Theme.outlineWidth
    border.color: Theme.outlineLight

    property var registeredWindow: null
    readonly property var targetWindow: blurEnabled && color.a > 0 && color.a < 1 && visible && !!blurBarWindow?.registerBlurWidget ? blurBarWindow : null

    function updateRegistration() {
        if (registeredWindow === targetWindow)
            return;
        registeredWindow?.unregisterBlurWidget(root);
        registeredWindow = targetWindow;
        registeredWindow?.registerBlurWidget(root);
    }

    onTargetWindowChanged: updateRegistration()
    onXChanged: blurBarWindow?.refreshBlurRegion?.()
    onYChanged: blurBarWindow?.refreshBlurRegion?.()
    onWidthChanged: blurBarWindow?.refreshBlurRegion?.()
    onHeightChanged: blurBarWindow?.refreshBlurRegion?.()
    Component.onCompleted: updateRegistration()
    Component.onDestruction: registeredWindow?.unregisterBlurWidget(root)
}
