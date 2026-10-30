pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Services
import qs.Modules.Settings.Widgets
import "../DBar/OverflowLayout.js" as OverflowLayout
import "WidgetGroups.js" as Groups

Column {
    id: root
    readonly property var log: Log.scoped("WidgetsTabSection")

    Component.onCompleted: DgopService.ensureMeta()

    property var items: []
    property var allWidgets: []
    property string title: ""
    property string sectionId: ""
    property string barId: ""
    property bool overflowSettingsExpanded: false
    property var collapsedGroups: ({})
    property string selectedGroup: ""
    readonly property var entries: barConfig?.[sectionId + "Widgets"] ?? []
    readonly property var treeNodes: Groups.tree(entries)
    readonly property var barConfig: SettingsData.getBarConfig(barId)
    readonly property bool autoOverflow: barConfig?.[sectionId + "OverflowMode"] !== "bar"
    readonly property int overflowPosition: barConfig?.[sectionId + "OverflowPosition"] ?? OverflowLayout.defaultPosition(sectionId, items.length)
    // An omitted key is the default; resetting clears it so the position keeps following the widget count.
    readonly property var overflowStore: ({
            "isDefault": keys => keys.every(key => (root.barConfig?.[key] ?? root.overflowDefault(key)) === root.overflowDefault(key)),
            "resetToDefault": keys => root.clearOverflowOptions(keys)
        })

    function overflowDefault(key) {
        return key.endsWith("Mode") ? "auto" : OverflowLayout.defaultPosition(sectionId, items.length);
    }

    function clearOverflowOptions(keys) {
        const patch = {};
        for (const key of keys)
            patch[key] = undefined;
        SettingsData.updateBarConfig(barId, patch);
    }

    function setOverflowOption(name, value) {
        SettingsData.updateBarConfig(barId, {
            [sectionId + "Overflow" + name]: value
        });
    }

    signal itemEnabledChanged(string sectionId, int widgetIndex, bool enabled)
    signal itemOrderChanged(string sectionId, var indices)
    signal addWidget(string sectionId)
    signal removeWidget(string sectionId, int widgetIndex)
    signal spacerSizeChanged(string sectionId, int widgetIndex, int newSize)
    signal configureWidget(string sectionId, int widgetIndex)
    signal pickGroupMember(string sectionId, string groupId)

    signal dragStarted(string sectionId, string itemId)

    property var reorderGroup: null
    property string highlightedId: ""
    property string highlightedSection: ""
    property int highlightedIndex: -1

    function saveEntries(next) {
        SettingsData.updateBarConfig(barId, Groups.normalize(barConfig, { [sectionId + "Widgets"]: next }));
    }

    function canGroup(index) {
        return index >= 0 && index < entries.length && !Groups.groupOf(entries[index]) && Groups.eligible(entries[index]) && BarWidgetCatalog.get(Groups.idOf(entries[index])) !== null;
    }

    function createGroup(index) {
        if (!canGroup(index))
            return;
        const groups = Object.assign({}, barConfig?.widgetGroups ?? {});
        const id = Groups.nextId(groups);
        groups[id] = { name: I18n.tr("Group"), style: "pills", padding: Theme.spacingXS, spacing: Theme.spacingXS, tone: "surface", blur: "inherit", overflowMode: "auto" };
        const next = entries.slice();
        next[index] = Groups.withGroup(next[index], id);
        SettingsData.updateBarConfig(barId, Groups.normalize(Object.assign({}, barConfig, { widgetGroups: groups }), { [sectionId + "Widgets"]: next }));
        selectedGroup = id;
    }

    function addMember(index, groupId) {
        if (!canGroup(index))
            return;
        if (!groupId) {
            createGroup(index);
            return;
        }
        saveEntries(Groups.addMember(entries, index, groupId));
    }

    function removeMember(index) {
        saveEntries(Groups.removeMember(entries, index));
    }

    function toggleGroup(id) {
        collapsedGroups = Object.assign({}, collapsedGroups, { [id]: !collapsedGroups[id] });
    }

    function editGroup(id) {
        selectedGroup = selectedGroup === id ? "" : id;
    }

    width: parent.width
    height: implicitHeight
    spacing: Theme.spacingM

    SettingsSectionLabel {
        text: root.title
        actions: [
            DActionButton {
                buttonSize: Theme.buttonHeightXXS
                iconName: "more_horiz"
                tooltipText: I18n.tr("Overflow")
                Accessible.name: root.title + ": " + I18n.tr("Overflow")
                iconSize: Theme.iconSizeSmall
                iconColor: root.overflowSettingsExpanded ? Theme.primary : Theme.outline
                visible: root.barId !== ""
                onClicked: root.overflowSettingsExpanded = !root.overflowSettingsExpanded
            },
            DActionButton {
                buttonSize: Theme.buttonHeightXXS
                iconName: "format_list_numbered"
                tooltipText: I18n.tr("Index centering")
                iconSize: Theme.iconSizeSmall
                iconColor: SettingsData.centeringMode === "index" ? Theme.primary : Theme.outline
                visible: root.sectionId === "center"
                onClicked: SettingsData.set("centeringMode", "index")
            },
            DActionButton {
                buttonSize: Theme.buttonHeightXXS
                iconName: "center_focus_weak"
                tooltipText: I18n.tr("Geometric centering")
                iconSize: Theme.iconSizeSmall
                iconColor: SettingsData.centeringMode === "geometric" ? Theme.primary : Theme.outline
                visible: root.sectionId === "center"
                onClicked: SettingsData.set("centeringMode", "geometric")
            }
        ]
    }

    SettingsCard {
        visible: root.overflowSettingsExpanded
        title: I18n.tr("Overflow")

        SettingsToggleRow {
            text: I18n.tr("Auto overflow")
            description: I18n.tr("Widgets in this section move into overflow when space runs out", "bar section overflow description")
            checked: root.autoOverflow
            onToggled: checked => root.setOverflowOption("Mode", checked ? "auto" : "bar")
        }

        SettingsDropdownRow {
            readonly property var positionLabels: {
                const labels = [I18n.tr("Start", "noun, overflow button position before the first widget", true)];
                const seen = {};
                for (const item of root.items) {
                    seen[item.text] = (seen[item.text] ?? 0) + 1;
                    labels.push(I18n.tr("After %1", "overflow button position option, %1 is a widget name").arg(seen[item.text] > 1 ? item.text + " " + seen[item.text] : item.text));
                }
                return labels;
            }

            text: I18n.tr("Overflow button position", "bar section dropdown label")
            resetStore: root.overflowStore
            resetKeys: [root.sectionId + "OverflowPosition"]
            options: positionLabels
            currentValue: positionLabels[Math.min(root.overflowPosition, positionLabels.length - 1)]
            onValueChanged: value => root.setOverflowOption("Position", positionLabels.indexOf(value))
        }
    }

    SettingsReorderList {
        id: reorderArea
        model: root.treeNodes
        group: root.reorderGroup
        groupKey: root.sectionId
        dropArea: root
        onReordered: indices => root.saveEntries(Groups.reorder(root.entries, root.treeNodes, indices))
        onDragStarted: (index, position) => root.dragStarted(root.sectionId, root.items[root.treeNodes[index].first]?.id ?? "")

        delegate: Column {
            id: nodeRow
            required property var modelData
            required property int index
            readonly property bool isGroup: modelData.groupId !== ""
            width: reorderArea.width
            spacing: Theme.spacingXS
            opacity: reorderArea.draggingIndex === index && reorderArea.crossSectionActive ? 0 : 1

            function focusHandle(reason) {
                if (isGroup)
                    groupRow.focusHandle(reason);
                else
                    widgetRow.focusHandle(reason);
            }

            WidgetTreeRow {
                id: widgetRow
                visible: !nodeRow.isGroup
                width: parent.width
                height: visible ? implicitHeight : 0
                index: nodeRow.index
                reorderList: reorderArea
                modelData: root.items[nodeRow.modelData.first] ?? ({})
                widgetIndex: nodeRow.modelData.first
                section: root
            }

            SettingsReorderRow {
                id: groupRow
                readonly property string treeGroup: nodeRow.modelData.groupId
                readonly property int widgetIndex: nodeRow.modelData.first
                visible: nodeRow.isGroup
                width: parent.width
                height: visible ? implicitHeight : 0
                index: nodeRow.index
                reorderList: reorderArea
                title: root.barConfig?.widgetGroups?.[nodeRow.modelData.groupId]?.name ?? I18n.tr("Group")
                iconName: "group_work"
                highlighted: !dragging && root.highlightedSection === root.sectionId && root.highlightedId === "@group:" + nodeRow.modelData.groupId
                clickable: true
                onClicked: root.editGroup(nodeRow.modelData.groupId)
                DActionButton {
                    iconName: root.collapsedGroups[nodeRow.modelData.groupId] ? "expand_more" : "expand_less"
                    tooltipText: root.collapsedGroups[nodeRow.modelData.groupId] ? I18n.tr("Expand") : I18n.tr("Collapse")
                    Accessible.name: tooltipText
                    onClicked: root.toggleGroup(nodeRow.modelData.groupId)
                }
                DActionButton {
                    iconName: "add"
                    tooltipText: I18n.tr("Add widget")
                    Accessible.name: tooltipText
                    onClicked: root.pickGroupMember(root.sectionId, nodeRow.modelData.groupId)
                }
            }

            Loader {
                width: parent.width
                active: nodeRow.isGroup && root.selectedGroup === nodeRow.modelData.groupId
                sourceComponent: Component {
                    WidgetGroupsEditor {
                        width: nodeRow.width
                        barId: root.barId
                        sectionId: root.sectionId
                        selectedGroup: nodeRow.modelData.groupId
                        items: root.items
                    }
                }
            }

            SettingsReorderList {
                id: memberList
                visible: nodeRow.isGroup && !root.collapsedGroups[nodeRow.modelData.groupId]
                x: Theme.spacingL
                width: parent.width - Theme.spacingL
                height: visible ? implicitHeight : 0
                model: nodeRow.isGroup ? root.items.slice(nodeRow.modelData.first, nodeRow.modelData.end) : []
                onReordered: indices => {
                    const next = root.entries.slice();
                    const members = next.slice(nodeRow.modelData.first, nodeRow.modelData.end);
                    next.splice(nodeRow.modelData.first, members.length, ...indices.map(i => members[i]));
                    root.saveEntries(next);
                }
                delegate: WidgetTreeRow {
                    reorderList: memberList
                    widgetIndex: nodeRow.modelData.first + index
                    section: root
                    member: true
                }
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingS
        DButton {
            text: I18n.tr("Add widget")
            iconName: "add"
            backgroundColor: Theme.secondaryContainer
            textColor: Theme.onSecondaryContainer
            onClicked: root.addWidget(root.sectionId)
        }
        DButton {
            text: I18n.tr("Add group")
            iconName: "group_add"
            onClicked: root.pickGroupMember(root.sectionId, "")
        }
    }
}
