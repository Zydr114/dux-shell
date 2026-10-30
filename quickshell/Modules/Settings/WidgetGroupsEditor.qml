pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import "WidgetGroups.js" as Groups

Column {
    id: root

    required property string barId
    required property string sectionId
    property var items: []
    property string selectedGroup: ""
    readonly property var config: SettingsData.getBarConfig(barId)
    readonly property string listKey: sectionId + "Widgets"
    readonly property var entries: config?.[listKey] ?? []
    readonly property var groups: config?.widgetGroups ?? ({})
    readonly property var group: Object.prototype.hasOwnProperty.call(groups, selectedGroup) && Groups.plainObject(groups[selectedGroup]) ? groups[selectedGroup] : null
    readonly property int first: entries.findIndex(entry => Groups.groupOf(entry) === selectedGroup && selectedGroup !== "")
    readonly property int last: {
        if (first < 0)
            return -1;
        let end = first;
        while (end + 1 < entries.length && Groups.groupOf(entries[end + 1]) === selectedGroup)
            end++;
        return end;
    }
    visible: group !== null && first >= 0
    spacing: Theme.spacingS

    function canGroup(index) {
        return index >= 0 && index < entries.length && Groups.eligible(entries[index]) && BarWidgetCatalog.get(Groups.idOf(entries[index])) !== null;
    }

    function save(entries, groups) {
        const patch = Groups.normalize(Object.assign({}, root.config, { widgetGroups: groups }), { [root.listKey]: entries });
        SettingsData.updateBarConfig(root.barId, patch);
    }

    function selectOrCreate(index) {
        if (!canGroup(index))
            return;
        const existing = Groups.groupOf(entries[index]);
        if (existing && Object.prototype.hasOwnProperty.call(groups, existing) && Groups.plainObject(groups[existing])) {
            selectedGroup = existing;
            return;
        }
        const nextGroups = Object.assign({}, groups);
        const id = Groups.nextId(nextGroups);
        nextGroups[id] = { name: I18n.tr("Group"), style: "pills", padding: Theme.spacingXS, spacing: Theme.spacingXS, tone: "surface", blur: "inherit", overflowMode: "auto" };
        const next = entries.slice();
        next[index] = Groups.withGroup(next[index], id);
        selectedGroup = id;
        save(next, nextGroups);
    }

    function update(key, value) {
        if (!group)
            return;
        const next = Object.assign({}, groups);
        next[selectedGroup] = Object.assign({}, group, { [key]: value });
        SettingsData.updateBarConfig(barId, { widgetGroups: next });
    }

    function canAdd(index) {
        return canGroup(index) && !Groups.groupOf(entries[index]);
    }

    function add(index) {
        if (!canAdd(index))
            return;
        const next = entries.slice();
        next[index] = Groups.withGroup(next[index], selectedGroup);
        save(next, groups);
    }

    function remove(index) {
        if (index !== first && index !== last)
            return;
        const next = entries.slice();
        next[index] = Groups.withGroup(next[index], "");
        const nextGroups = Object.assign({}, groups);
        if (first === last) {
            delete nextGroups[selectedGroup];
            selectedGroup = "";
        }
        save(next, nextGroups);
    }

    function ungroup() {
        const next = entries.map(entry => Groups.groupOf(entry) === selectedGroup ? Groups.withGroup(entry, "") : entry);
        const nextGroups = Object.assign({}, groups);
        delete nextGroups[selectedGroup];
        selectedGroup = "";
        save(next, nextGroups);
    }

    function move(direction) {
        if (first < 0 || (direction < 0 && first === 0) || (direction > 0 && last === entries.length - 1))
            return;
        const next = entries.slice();
        const block = next.splice(first, last - first + 1);
        let target = first;
        if (direction < 0) {
            target = first - 1;
            const adjacent = Groups.groupOf(next[target]);
            while (adjacent && target > 0 && Groups.groupOf(next[target - 1]) === adjacent)
                target--;
        } else {
            const adjacent = Groups.groupOf(next[target]);
            target++;
            while (adjacent && target < next.length && Groups.groupOf(next[target]) === adjacent)
                target++;
        }
        next.splice(target, 0, ...block);
        save(next, groups);
    }

    SettingsCard {
        width: parent.width
        title: I18n.tr("Group")

        SettingsTextFieldRow {
            text: I18n.tr("Name")
            value: root.group?.name ?? ""
            onEditingFinished: value => root.update("name", value.trim() || I18n.tr("Group"))
        }

        SettingsRow {
            title: I18n.tr("Members")
            subtitle: root.items.slice(root.first, root.last + 1).map(item => item.text).join(" · ")
            body: Flow {
                width: parent.width
                spacing: Theme.spacingS
                DButton { text: I18n.tr("Add previous"); enabled: root.canAdd(root.first - 1); onClicked: root.add(root.first - 1) }
                DButton { text: I18n.tr("Add next"); enabled: root.canAdd(root.last + 1); onClicked: root.add(root.last + 1) }
                DButton { text: I18n.tr("Remove first"); onClicked: root.remove(root.first) }
                DButton { text: I18n.tr("Remove last"); onClicked: root.remove(root.last) }
            }
        }

        SettingsRow {
            title: I18n.tr("Position")
            DActionButton { iconName: "arrow_upward"; tooltipText: I18n.tr("Move up"); enabled: root.first > 0; onClicked: root.move(-1) }
            DActionButton { iconName: "arrow_downward"; tooltipText: I18n.tr("Move down"); enabled: root.last < root.entries.length - 1; onClicked: root.move(1) }
            DButton { text: I18n.tr("Ungroup"); onClicked: root.ungroup() }
        }

        SettingsDropdownRow {
            text: I18n.tr("Style")
            options: [I18n.tr("Pills"), I18n.tr("Segments")]
            currentValue: root.group?.style === "segments" ? options[1] : options[0]
            onValueChanged: value => root.update("style", value === options[1] ? "segments" : "pills")
        }
        SettingsDropdownRow {
            text: I18n.tr("Color")
            options: [I18n.tr("Surface"), I18n.tr("Primary")]
            currentValue: root.group?.tone === "primary" ? options[1] : options[0]
            onValueChanged: value => root.update("tone", value === options[1] ? "primary" : "surface")
        }
        SettingsDropdownRow {
            text: I18n.tr("Blur")
            options: [I18n.tr("Default"), I18n.tr("On"), I18n.tr("Off")]
            currentValue: root.group?.blur === "on" ? options[1] : root.group?.blur === "off" ? options[2] : options[0]
            onValueChanged: value => root.update("blur", value === options[1] ? "on" : value === options[2] ? "off" : "inherit")
        }
        SettingsDropdownRow {
            text: I18n.tr("Overflow")
            options: [I18n.tr("Automatic"), I18n.tr("Bar"), I18n.tr("Always")]
            currentValue: root.group?.overflowMode === "bar" ? options[1] : root.group?.overflowMode === "always" ? options[2] : options[0]
            onValueChanged: value => root.update("overflowMode", value === options[1] ? "bar" : value === options[2] ? "always" : "auto")
        }
        SettingsSliderRow {
            text: I18n.tr("Padding")
            description: I18n.tr("Padding applies along the bar; cross-axis padding adapts to the available thickness.", "widget group padding description")
            minimum: 0
            maximum: Theme.spacingXL
            value: root.group?.padding ?? Theme.spacingXS
            onSliderValueChanged: value => root.update("padding", value)
        }
        SettingsSliderRow {
            text: I18n.tr("Spacing")
            minimum: 0
            maximum: Theme.spacingM
            value: root.group?.spacing ?? Theme.spacingXS
            onSliderValueChanged: value => root.update("spacing", value)
        }
    }
}
