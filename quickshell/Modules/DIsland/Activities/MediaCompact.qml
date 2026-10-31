pragma ComponentBehavior: Bound

import QtQuick
import qs.Modules.SurfaceWidgets

MediaActivityFace {
    id: root
    required property var controller
    dense: controller.compactDense
    isVertical: controller.isVertical
    artworkSize: controller.compactIconSize
    clockVisible: controller.mediaClockVisible
    textMode: controller.mediaTextMode
    function updateLength() {
        controller.setMediaContentLength(isVertical ? implicitHeight : implicitWidth);
    }
    onImplicitWidthChanged: updateLength()
    onImplicitHeightChanged: updateLength()
    onIsVerticalChanged: updateLength()
    Component.onCompleted: updateLength()
    onClockClicked: controller.activateCompact("clock")
    property bool hoverCounted: false
    onClockHoveredChanged: {
        if (hoverCounted === clockHovered)
            return;
        hoverCounted = clockHovered;
        if (clockHovered)
            controller.slotHoverEntered();
        else
            controller.slotHoverExited();
    }
    Component.onDestruction: if (hoverCounted)
        controller.slotHoverExited()
}
