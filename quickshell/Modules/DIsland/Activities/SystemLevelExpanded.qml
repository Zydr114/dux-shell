pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.OSD
import qs.DCommon.Widgets

Item {
    id: root

    required property var systemModel

    Column {
        anchors {
            fill: parent
            margins: Theme.spacingXL
        }
        spacing: Theme.spacingL

        Row {
            width: parent.width
            height: Math.max(Theme.iconSize, levelSlider.height)
            spacing: Theme.spacingM

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - (valueText.visible ? valueText.width + parent.spacing : 0))
                spacing: Theme.spacingXXS

                StyledText {
                    text: root.systemModel.title
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Theme.fontWeightMedium
                }

                StyledText {
                    text: root.systemModel.mutable ? I18n.tr("Click the icon to mute", "island volume face: hint under the title") : I18n.tr("Display brightness control", "island brightness face: hint under the title")
                    color: Theme.surfaceTextSecondary
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            StyledText {
                id: valueText

                anchors.verticalCenter: parent.verticalCenter
                text: root.systemModel.displayValue
                visible: SettingsData.osdAlwaysShowValue
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeXXLarge
                font.weight: Theme.fontWeightBold
            }
        }

        Row {
            width: parent.width
            visible: root.systemModel.levelActivity
            spacing: Theme.spacingM

            OsdIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSize
                height: width
                iconName: root.systemModel.iconName
                iconColor: Theme.surfaceText
                tonal: false
                interactive: root.systemModel.mutable
                available: root.systemModel.available
                label: root.systemModel.muted ? I18n.tr("Unmute") : I18n.tr("Mute")
                onClicked: root.systemModel.toggleMute()
            }

            DSlider {
                id: levelSlider

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - Theme.iconSize - parent.spacing)
                trackHeight: Theme.spacingXS
                handleHeight: Theme.iconSizeSmall
                fillColor: Theme.surfaceText
                trackColor: Theme.onSurface_38
                Accessible.name: root.systemModel.title
                minimum: root.systemModel.minimum
                maximum: Math.max(root.systemModel.minimum + 1, Math.round(root.systemModel.maximum))
                enabled: root.systemModel.available
                showValue: false
                unit: root.systemModel.unit
                valueOverride: Math.round(root.systemModel.value)
                onSliderValueChanged: newValue => root.systemModel.setRatio(newValue / Math.max(1, maximum))

                Binding on value {
                    value: Math.round(root.systemModel.value)
                    restoreMode: Binding.RestoreNone
                    when: !levelSlider.isDragging
                }
            }
        }
    }
}
