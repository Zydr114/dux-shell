pragma ComponentBehavior: Bound

import QtQuick
import qs.Modules.SurfaceWidgets

Item {
    id: root
    required property var controller
    required property var mediaModel
    readonly property bool isVertical: controller.isVertical
    readonly property Item face: presenter.item as Item
    readonly property MediaActivityFace standardFace: presenter.item as MediaActivityFace
    readonly property bool clockHovered: standardFace?.clockHovered ?? false
    implicitWidth: face?.implicitWidth ?? 0
    implicitHeight: face?.implicitHeight ?? 0

    function updateLength() {
        controller.setMediaContentLength(controller.isVertical ? implicitHeight : implicitWidth);
    }
    onImplicitWidthChanged: updateLength()
    onImplicitHeightChanged: updateLength()
    onIsVerticalChanged: updateLength()
    Component.onCompleted: updateLength()
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

    Loader {
        id: presenter
        anchors.fill: parent
        sourceComponent: root.controller.mediaLyricsPresentation ? lyricsComponent : standardComponent
    }

    Component {
        id: standardComponent

        MediaActivityFace {
            mediaModel: root.mediaModel
            dense: root.controller.compactDense
            isVertical: root.controller.isVertical
            artworkSize: root.controller.compactIconSize
            clockVisible: root.controller.mediaClockVisible
            textMode: root.controller.mediaTextMode
            onClockClicked: root.controller.activateCompact("clock")
        }
    }

    Component {
        id: lyricsComponent

        ClavisLyricsCompact {
            mediaModel: root.mediaModel
        }
    }
}
