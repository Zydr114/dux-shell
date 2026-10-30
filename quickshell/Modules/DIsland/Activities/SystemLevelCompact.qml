pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.OSD
import qs.DCommon.Widgets

Item {
    id: root

    required property var systemModel
    property bool isVertical: false
    property real iconSize: Theme.iconSizeLarge

    readonly property int maximum: Math.max(root.systemModel.minimum + 1, Math.round(root.systemModel.maximum))
    readonly property bool showValue: SettingsData.osdAlwaysShowValue
    readonly property bool mirrored: !root.isVertical && I18n.isRtl
    readonly property real inset: Theme.spacingM
    readonly property real gap: Theme.spacingS
    readonly property real valueExtent: root.showValue ? (root.isVertical ? valueLabel.implicitHeight : valueLabel.reservedWidth) + root.gap : 0

    OsdIcon {
        id: levelIcon

        x: root.isVertical ? (parent.width - width) / 2 : root.mirrored ? parent.width - width - root.inset : root.inset
        y: root.isVertical ? root.inset : (parent.height - height) / 2
        width: Math.min(Theme.iconSize, root.iconSize)
        height: width
        iconName: root.systemModel.iconName
        iconColor: Theme.surfaceText
        tonal: false
        interactive: root.systemModel.mutable
        available: root.systemModel.available
        label: root.systemModel.muted ? I18n.tr("Unmute") : I18n.tr("Mute")
        onClicked: root.systemModel.toggleMute()
    }

    Item {
        id: sliderSlot

        x: root.isVertical ? 0 : root.mirrored ? root.inset + root.valueExtent : root.inset + levelIcon.width + root.gap
        y: root.isVertical ? levelIcon.y + levelIcon.height + root.gap : 0
        width: Math.max(0, root.isVertical ? parent.width : parent.width - root.inset * 2 - levelIcon.width - root.gap - root.valueExtent)
        height: Math.max(0, root.isVertical ? parent.height - y - root.inset - root.valueExtent : parent.height)

        DSlider {
            id: levelSlider

            anchors.centerIn: parent
            width: root.isVertical ? parent.height : parent.width
            rotation: root.isVertical ? -90 : 0
            LayoutMirroring.enabled: !root.isVertical && I18n.isRtl
            trackHeight: Theme.spacingXS
            handleHeight: Theme.iconSizeSmall
            fillColor: Theme.surfaceText
            trackColor: Theme.onSurface_38
            minimum: root.systemModel.minimum
            maximum: root.maximum
            enabled: root.systemModel.available
            showValue: false
            unit: root.systemModel.unit
            valueOverride: Math.round(root.systemModel.value)
            Accessible.name: root.systemModel.title
            onSliderValueChanged: newValue => root.systemModel.setRatio(newValue / Math.max(1, root.maximum))

            Binding on value {
                value: Math.round(root.systemModel.value)
                restoreMode: Binding.RestoreNone
                when: !levelSlider.isDragging
            }
        }
    }

    NumericText {
        id: valueLabel

        x: root.isVertical ? (parent.width - width) / 2 : root.mirrored ? root.inset : parent.width - width - root.inset
        y: root.isVertical ? parent.height - height - root.inset : (parent.height - height) / 2
        width: root.isVertical ? Math.max(0, parent.width - Theme.spacingXS * 2) : reservedWidth
        height: implicitHeight
        visible: root.showValue
        text: root.systemModel.displayValue.length > 0 ? root.systemModel.displayValue : Math.round(root.systemModel.value) + root.systemModel.unit
        reserveText: root.maximum + root.systemModel.unit
        color: Theme.surfaceText
        font.pixelSize: root.isVertical ? Theme.fontSizeSmall : Theme.fontSizeMedium
        font.weight: Theme.fontWeightBold
        horizontalAlignment: root.isVertical ? Text.AlignHCenter : Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
