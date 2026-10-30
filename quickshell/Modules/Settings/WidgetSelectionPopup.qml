import QtQuick
import qs.Common
import qs.DCommon.Widgets

WidgetPickerWindow {
    id: root

    property string targetSection: ""
    property string targetGroup: ""
    property bool selectingMember: false
    readonly property bool blurActive: Theme.blurLayersActive
    readonly property bool floatingForegroundLayers: Theme.floatingWindowForegroundLayers
    readonly property bool transparentBlurLayers: Theme.blurLayersActive && !floatingForegroundLayers
    readonly property real rowAlpha: blurActive ? Math.min(Theme.floatingWindowTransparency, transparentBlurLayers ? 0.12 : 0.52) : 0.30

    signal widgetSelected(string widgetId, string targetSection)
    signal groupSelected(string targetSection)
    signal memberSelected(string targetSection, string groupId, int index)

    function translateSection(section) {
        switch (section.toLowerCase()) {
        case "left":
            return I18n.tr("Left section");
        case "center":
            return I18n.tr("Center section");
        case "right":
            return I18n.tr("Right section");
        default:
            return section;
        }
    }

    objectName: "widgetSelectionPopup"
    title: I18n.tr("Add widget")
    headerTitle: selectingMember ? I18n.tr("Select widget") : I18n.tr("Add widget to %1", "widget picker header, %1 is the bar section name").arg(translateSection(targetSection))
    intro: selectingMember ? "" : I18n.tr("Select a widget to add. You can add multiple instances of the same widget if needed.")
    widgetDelegate: rowDelegate

    onWidgetChosen: widget => {
        if (widget.disabled)
            return;
        if (widget.groupEntry)
            groupSelected(targetSection);
        else if (selectingMember)
            memberSelected(targetSection, targetGroup, widget.sourceIndex);
        else
            widgetSelected(widget.id, targetSection);
        hide();
    }

    onVisibleChanged: {
        if (visible)
            return;
        widgets = [];
        targetSection = "";
        targetGroup = "";
        selectingMember = false;
    }

    Component {
        id: rowDelegate

        DListItem {
            width: ListView.view.width
            implicitHeight: Math.max(Theme.listItemHeight, textColumn.implicitHeight + Theme.spacingM * 2)
            isSelected: root.keyboardNavigationActive && index === root.selectedIndex && !modelData.disabled
            enabled: !modelData.disabled
            Accessible.name: modelData.text
            onClicked: root.widgetChosen(modelData)

            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                DIcon {
                    name: modelData.icon
                    size: Theme.iconSize
                    color: modelData.disabled ? Theme.onSurface_38 : Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    id: textColumn
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXXS
                    width: parent.width - Theme.iconSize * 2 - Theme.spacingM * 4 + 4

                    StyledText {
                        text: modelData.text
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Theme.fontWeightMedium
                        color: modelData.disabled ? Theme.onSurface_38 : Theme.surfaceText
                        elide: Text.ElideRight
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        text: modelData.description
                        font.pixelSize: Theme.fontSizeSmall
                        color: modelData.disabled ? Theme.onSurface_38 : Theme.outline
                        elide: Text.ElideRight
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }
                }

                DIcon {
                    name: "add"
                    size: Theme.iconSizeMedium
                    color: modelData.disabled ? Theme.onSurface_38 : Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
