pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Services
import qs.Modules.Settings.Widgets

SettingsReorderRow {
    id: root

    required property var modelData
    required property int widgetIndex
    required property var section
    property bool member: false
    readonly property bool configurable: BarWidgetCatalog.configurable(modelData)

    highlighted: !dragging && section.highlightedIndex === widgetIndex && section.highlightedSection === section.sectionId && section.highlightedId === modelData.id
    title: modelData.text
    iconName: modelData.icon
    iconColor: modelData.enabled ? Theme.primary : Theme.onSurfaceVariant
    titleColor: modelData.enabled ? Theme.onSurface : Theme.onSurfaceVariant
    subtitle: {
        if (modelData.id !== "gpuTemp")
            return modelData.description ?? "";
        const gpu = DgopService.availableGpus?.[modelData.selectedGpuIndex ?? 0];
        return gpu ? (gpu.driver?.toUpperCase() ?? "") : I18n.tr("No GPU detected", "empty state when no graphics card is found");
    }
    clickable: configurable
    onClicked: section.configureWidget(section.sectionId, widgetIndex)

    Item {
        width: Theme.iconButtonSize
        height: Theme.iconButtonSize
        visible: !!root.modelData.warning
        anchors.verticalCenter: parent.verticalCenter
        DIcon { name: "warning"; size: Theme.iconSizeMedium; color: Theme.error; anchors.centerIn: parent }
        MouseArea { id: warningArea; anchors.fill: parent; hoverEnabled: true }
        DTooltipHost { text: root.modelData.warning; target: parent; hoverArea: warningArea }
    }
    DIcon {
        name: "chevron_right"
        size: Theme.iconSize
        color: Theme.onSurfaceVariant
        rotation: I18n.isRtl ? 180 : 0
        visible: root.configurable
        anchors.verticalCenter: parent.verticalCenter
    }
    SettingsDivider { vertical: true; visible: root.configurable }
    DNumberStepper {
        visible: root.modelData.id === "spacer"
        anchors.verticalCenter: parent.verticalCenter
        text: (root.modelData.size || 20).toString()
        decrementEnabled: (root.modelData.size || 20) > 5
        incrementEnabled: (root.modelData.size || 20) < 5000
        onDecrement: () => root.section.spacerSizeChanged(root.section.sectionId, root.widgetIndex, Math.max(5, (root.modelData.size || 20) - 5))
        onIncrement: () => root.section.spacerSizeChanged(root.section.sectionId, root.widgetIndex, Math.min(5000, (root.modelData.size || 20) + 5))
    }
    DToggle {
        hideText: true
        visible: root.modelData.id !== "spacer"
        checked: root.modelData.enabled
        anchors.verticalCenter: parent.verticalCenter
        onToggled: value => root.section.itemEnabledChanged(root.section.sectionId, root.widgetIndex, value)
    }
    DActionButton {
        visible: root.member
        iconName: "logout"
        tooltipText: I18n.tr("Remove from group")
        Accessible.name: tooltipText
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.section.removeMember(root.widgetIndex)
    }
    DActionButton {
        iconName: "close"
        iconColor: Theme.error
        Accessible.name: I18n.tr("Remove")
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.section.removeWidget(root.section.sectionId, root.widgetIndex)
    }
}
