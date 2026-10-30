pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets
import "../../../Common/settings/ClockStyle.js" as ClockStyle

SettingsCard {
    id: root

    property string selectedDigit: "h0"
    readonly property var selectedStyle: SettingsData.clockStyle.digits[selectedDigit]
    readonly property var defaults: ClockStyle.normalize(null)
    readonly property var digitIds: SettingsData.showSeconds ? ["h0", "h1", "separator", "m0", "m1", "secondsSeparator", "s0", "s1", "ap", "periodM"] : ["h0", "h1", "separator", "m0", "m1", "ap", "periodM"]
    readonly property var digitLabels: SettingsData.showSeconds ? ["1", "2", ":", "3", "4", ":", "5", "6", "A/P", "M"] : ["1", "2", ":", "3", "4", "A/P", "M"]

    function setDigitColor(id, role, color) {
        const digit = Object.assign({}, SettingsData.clockStyle.digits[id], {
            colorRole: role,
            customColor: color
        });
        SettingsData.setClockStyleValue(["digits", id], digit);
    }

    function openColorPicker() {
        const id = root.selectedDigit;
        const digit = SettingsData.clockStyle.digits[id];
        const picker = PopoutService.colorPickerModal;
        if (!picker)
            return;
        picker.selectedColor = digit.customColor || Theme.clockDigitColor(digit);
        picker.pickerTitle = I18n.tr("Custom color");
        picker.onColorSelectedCallback = color => root.setDigitColor(id, "custom", String(color));
        picker.show();
    }

    onDigitIdsChanged: {
        if (!root.digitIds.includes(root.selectedDigit))
            root.selectedDigit = "h0";
    }

    tab: "time"
    tags: ["clock", "font", "size", "weight", "width", "optical", "grade", "roundness", "slant", "digits", "color", "rotation", "offset"]
    settingKey: "clockStyle"
    title: I18n.tr("Clock style")
    iconName: "schedule"
    collapsible: true
    expanded: true

    headerActions: DActionButton {
        iconName: "restart_alt"
        buttonSize: Theme.buttonHeightXS
        tooltipText: I18n.tr("Reset to default")
        enabled: !SettingsData.isDefault(["clockStyle"])
        onClicked: SettingsData.resetToDefault(["clockStyle"])
    }

    SettingsRow {
        title: I18n.tr("Preview")

        body: Item {
            width: parent.width
            height: preview.implicitHeight + Theme.spacingXL * 2

            ClockContent {
                id: preview

                anchors.centerIn: parent
                date: new Date(2026, 9, 30, 12, 34, 56)
                live: false
                dateFirst: true
                scale: Math.min(1, (parent.width - Theme.spacingL * 2) / implicitWidth)
            }
        }
    }

    SettingsToggleRow {
        text: I18n.tr("Hide date")
        checked: SettingsData.clockStyle.hideDate
        onToggled: checked => SettingsData.setClockStyleValue(["hideDate"], checked)
    }

    SettingsSliderRow {
        text: I18n.tr("Font Size")
        minimum: ClockStyle.FONT_SIZE.min
        maximum: ClockStyle.FONT_SIZE.max
        value: SettingsData.clockStyle.fontSize
        step: 1
        unit: "px"
        resetByKeys: false
        modified: value !== ClockStyle.FONT_SIZE.def
        onResetRequested: SettingsData.setClockStyleValue(["fontSize"], ClockStyle.FONT_SIZE.def)
        onSliderValueChanged: value => SettingsData.setClockStyleValue(["fontSize"], value, false)
        onSliderDragFinished: value => SettingsData.setClockStyleValue(["fontSize"], value)
    }

    Repeater {
        model: [
            {
                axis: "wght",
                label: I18n.tr("Weight")
            },
            {
                axis: "wdth",
                label: I18n.tr("Width")
            },
            {
                axis: "opsz",
                label: I18n.tr("Optical size")
            },
            {
                axis: "GRAD",
                label: I18n.tr("Grade")
            },
            {
                axis: "ROND",
                label: I18n.tr("Roundness")
            },
            {
                axis: "slnt",
                label: I18n.tr("Slant")
            }
        ]

        SettingsSliderRow {
            id: axisRow

            required property var modelData
            readonly property var limits: ClockStyle.AXES[modelData.axis]

            text: modelData.label + " (" + modelData.axis + ")"
            minimum: limits.min
            maximum: limits.max
            value: SettingsData.clockStyle.axes[modelData.axis]
            step: 1
            resetByKeys: false
            modified: value !== limits.def
            onResetRequested: SettingsData.setClockStyleValue(["axes", axisRow.modelData.axis], axisRow.limits.def)
            onSliderValueChanged: value => SettingsData.setClockStyleValue(["axes", axisRow.modelData.axis], value, false)
            onSliderDragFinished: value => SettingsData.setClockStyleValue(["axes", axisRow.modelData.axis], value)
        }
    }

    SettingsButtonGroupRow {
        text: I18n.tr("Position")
        model: root.digitLabels
        values: root.digitIds
        value: root.selectedDigit
        onValueSelected: value => root.selectedDigit = value
    }

    SettingsButtonGroupRow {
        text: I18n.tr("Color")
        model: [I18n.tr("Primary"), I18n.tr("Inverse"), I18n.tr("Custom")]
        values: ["primary", "inversePrimary", "custom"]
        value: root.selectedStyle.colorRole
        onValueSelected: role => root.setDigitColor(root.selectedDigit, role, root.selectedStyle.customColor || String(Theme.clockDigitColor(root.selectedStyle)))
    }

    SettingsRow {
        title: I18n.tr("Custom color")
        visible: root.selectedStyle.colorRole === "custom"
        clickable: true
        onClicked: root.openColorPicker()

        DColorSwatch {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconSize
            height: width
            swatchColor: root.selectedStyle.customColor || Theme.primary
        }

        body: DTextField {
            id: colorInput

            property string editingDigit: root.selectedDigit

            width: parent.width
            labelText: I18n.tr("Custom color")
            placeholderText: "#RRGGBB / #AARRGGBB"
            text: root.selectedStyle.customColor
            isError: !ClockStyle.customColor(text)
            onInputFocusedChanged: {
                if (inputFocused)
                    editingDigit = root.selectedDigit;
            }
            onEditingFinished: {
                if (editingDigit === root.selectedDigit && ClockStyle.customColor(text))
                    root.setDigitColor(editingDigit, "custom", text);
            }
        }
    }

    Repeater {
        model: [
            {
                field: "x",
                label: I18n.tr("Horizontal offset"),
                unit: "px"
            },
            {
                field: "y",
                label: I18n.tr("Vertical offset"),
                unit: "px"
            },
            {
                field: "rotation",
                label: I18n.tr("Rotation"),
                unit: "°"
            }
        ]

        SettingsSliderRow {
            id: digitRow

            required property var modelData
            readonly property var limits: ClockStyle.OFFSETS[modelData.field]
            readonly property real defaultValue: root.defaults.digits[root.selectedDigit][modelData.field]

            text: modelData.label
            minimum: limits.min
            maximum: limits.max
            value: root.selectedStyle[modelData.field]
            unit: modelData.unit
            step: 1
            resetByKeys: false
            modified: value !== defaultValue
            onResetRequested: SettingsData.setClockStyleValue(["digits", root.selectedDigit, digitRow.modelData.field], digitRow.defaultValue)
            onSliderValueChanged: value => SettingsData.setClockStyleValue(["digits", root.selectedDigit, digitRow.modelData.field], value, false)
            onSliderDragFinished: value => SettingsData.setClockStyleValue(["digits", root.selectedDigit, digitRow.modelData.field], value)
        }
    }

    SettingsRow {
        title: I18n.tr("Reset to default")
        iconName: "restart_alt"
        clickable: true
        onClicked: SettingsData.setClockStyleValue(["digits", root.selectedDigit], root.defaults.digits[root.selectedDigit])
    }
}
