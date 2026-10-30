pragma ComponentBehavior: Bound

import QtQuick

BarSection {
    id: root

    property alias widgetLayoutLoader: layoutLoader
    readonly property var layoutItem: layoutLoader.item
    entryRepeater: layoutItem?.repeater ?? null
    property real contentSize: 0
    property real contentThickness: 0
    onLayoutRequested: rolesTimer.restart()

    onXChanged: refreshBlur()
    onYChanged: refreshBlur()

    implicitHeight: isVertical ? contentSize : contentThickness
    implicitWidth: isVertical ? Math.max(widgetThickness, groupCrossThickness) : contentSize

    onSegmentedChanged: rolesTimer.restart()

    function updateRoles() {
        const repeater = entryRepeater;
        if (!repeater)
            return;
        const entries = [];
        const participating = [];
        for (let index = 0; index < repeater.count; index++) {
            const wrapper = repeater.itemAt(index);
            entries.push(wrapper?.itemData ?? null);
            participating.push(participation(wrapper, wrapper?.visible ?? false, wrapper?.widgetItem ?? null));
        }
        applyRoles(entries, participating);
        const layout = inlineLayout();
        contentSize = layout.totalSize;
        updateGroups(layout.units);
        let thickness = Math.max(overflowCount > 0 ? barThickness : 0, groupCrossThickness);
        for (let index = 0; index < repeater.count; index++) {
            const wrapper = repeater.itemAt(index);
            if (wrapper && layout.positions[index] !== null)
                thickness = Math.max(thickness, wrapper.itemHeight);
        }
        for (let index = 0; index < repeater.count; index++) {
            const wrapper = repeater.itemAt(index);
            if (!wrapper || layout.positions[index] === null)
                continue;
            wrapper.x = isVertical ? (width - wrapper.width) / 2 : layout.positions[index];
            wrapper.y = isVertical ? layout.positions[index] : (thickness - wrapper.height) / 2;
        }
        contentThickness = thickness;
        overflowButtonPosition = layout.buttonPosition ?? 0;
        refreshBlur();
    }

    Timer {
        id: rolesTimer
        interval: 0
        repeat: false
        onTriggered: root.updateRoles()
    }

    Loader {
        id: layoutLoader
        anchors.fill: parent
        sourceComponent: root.isVertical ? columnComponent : rowComponent
        onLoaded: rolesTimer.restart()
    }

    Component {
        id: rowComponent

        Item {
            readonly property int widgetCount: rowRepeater.count
            readonly property alias repeater: rowRepeater

            Repeater {
                id: rowRepeater
                model: root.widgetsModel
                delegate: widgetComponent
                onCountChanged: rolesTimer.restart()
            }
        }
    }

    Component {
        id: columnComponent

        Item {
            readonly property int widgetCount: columnRepeater.count
            readonly property alias repeater: columnRepeater
            width: parent.width

            Repeater {
                id: columnRepeater
                model: root.widgetsModel
                delegate: widgetComponent
                onCountChanged: rolesTimer.restart()
            }
        }
    }

    Component {
        id: widgetComponent

        SectionEntry {
            required property var modelData
            required property int index
            sectionContext: root
            itemData: modelData
            occurrenceOrder: index
            onXChanged: {
                if (!root.isVertical)
                    root.refreshBlur();
            }
            onYChanged: {
                if (root.isVertical)
                    root.refreshBlur();
            }
            onParticipatesChanged: rolesTimer.restart()
            onWidgetItemChanged: rolesTimer.restart()
        }
    }
}
