pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import "CenterLayout.js" as CenterLayout

BarSection {
    id: root

    property var centerWidgets: []
    property int totalWidgets: 0
    property real totalSize: 0
    property real contentStart: 0
    property real contentSize: 0
    readonly property var bounds: barContent?.centerBounds ?? null
    entryRepeater: centerRepeater
    onLayoutRequested: layoutTimer.restart()

    onBoundsChanged: layoutTimer.restart()

    function requestLayout() {
        layoutTimer.restart();
    }

    function updateLayout() {
        positionWidgets();
        updateContentExtent();
        refreshBlur();
    }

    function updateContentExtent() {
        if (centerWidgets.length === 0) {
            contentStart = 0;
            contentSize = 0;
            return;
        }
        let start = Infinity;
        let end = -Infinity;
        for (const widget of centerWidgets) {
            const pos = isVertical ? widget.y : widget.x;
            const size = isVertical ? widget.height : widget.width;
            start = Math.min(start, pos);
            end = Math.max(end, pos + size);
        }
        for (const group of groupGeometries) {
            start = Math.min(start, group.position);
            end = Math.max(end, group.position + group.size);
        }
        contentStart = start;
        contentSize = end - start;
    }

    function positionWidgets() {
        const length = isVertical ? height : width;
        if (length <= 0 || !visible)
            return;

        const widgets = [];
        const entries = [];
        const participating = [];
        for (let index = 0; index < centerRepeater.count; index++) {
            const wrapper = centerRepeater.itemAt(index) as SectionEntry;
            const widget = wrapper?.participates ? wrapper : null;
            widgets.push(widget);
            entries.push(wrapper?.itemData ?? null);
            participating.push(participation(wrapper, widget !== null, wrapper?.item));
        }
        applyRoles(entries, participating);

        const inline = inlineLayout();
        const layout = CenterLayout.resolve(inline.sizes, length, widgetSpacing, SettingsData.centeringMode, bounds, inline.anchor);
        for (let index = 0; index < inline.indices.length; index++) {
            if (inline.indices[index] === -1) {
                overflowButtonPosition = layout.positions[index];
                continue;
            }
            if (layout.positions[index] === null)
                continue;
            const unit = inline.units[index];
            for (let memberIndex = 0; memberIndex < unit.members.length; memberIndex++) {
                const widget = widgets[unit.members[memberIndex]];
                if (!widget)
                    continue;
                const position = layout.positions[index] + unit.offsets[memberIndex];
                if (isVertical) {
                    widget.anchors.verticalCenter = undefined;
                    widget.y = position;
                    widget.x = (width - widget.width) / 2;
                    continue;
                }
                widget.anchors.horizontalCenter = undefined;
                widget.x = position;
                widget.y = (height - widget.height) / 2;
            }
        }
        updateGroups(inline.units, layout.positions);
        centerWidgets = widgets.filter(widget => widget !== null);
        if (overflowButton)
            centerWidgets.push(overflowButton);
        totalWidgets = centerWidgets.length;
        totalSize = layout.totalSize;
    }

    height: parent.height
    width: parent.width
    anchors.centerIn: parent

    implicitWidth: isVertical ? Math.max(outerThickness, groupCrossThickness) : totalSize
    implicitHeight: isVertical ? totalSize : Math.max(outerThickness, groupCrossThickness)

    Timer {
        id: layoutTimer
        interval: 0
        repeat: false
        onTriggered: root.updateLayout()
    }

    Component.onCompleted: layoutTimer.restart()

    onWidthChanged: {
        if (width > 0)
            layoutTimer.restart();
    }

    onHeightChanged: {
        if (height > 0)
            layoutTimer.restart();
    }

    onVisibleChanged: {
        if (visible && (isVertical ? height : width) > 0)
            layoutTimer.restart();
    }

    onSegmentedChanged: layoutTimer.restart()

    Repeater {
        id: centerRepeater
        model: root.widgetsModel

        onCountChanged: layoutTimer.restart()

        SectionEntry {
            required property var modelData
            required property int index
            sectionContext: root
            itemData: modelData
            occurrenceOrder: index
            onParticipatesChanged: root.requestLayout()
            onItemWidthChanged: root.requestLayout()
            onItemHeightChanged: root.requestLayout()
            onActiveChanged: layoutTimer.restart()
        }
    }

    readonly property string settingsCenteringMode: SettingsData.centeringMode

    onSettingsCenteringModeChanged: layoutTimer.restart()
}
