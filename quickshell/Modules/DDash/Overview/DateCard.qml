import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import qs.Modules.ControlCenter.Widgets

Card {
    id: root
    property bool live: Window.window?.visible ?? false
    property bool opensTab: false
    property Item hostGrid: null
    property bool forwarding: false

    signal detailRequested(var eventData)
    signal editorRequested(var eventData, var initialDate)

    entryId: "date"
    tone: options.tone ?? ""
    pad: Theme.spacingM
    clickable: true
    blocksTabNavigation: calendarSheet.shown
    Accessible.name: I18n.tr("Calendar")

    function openCalendar() {
        let item = root.parent;
        while (item && typeof item.cardItemFor !== "function")
            item = item.parent;
        if (!item)
            return;
        hostGrid = item;
        const calendar = hostGrid.cardItemFor("calendar");
        const slot = hostGrid.slotFor("calendar");
        if (calendar && slot) {
            hostGrid.focusSlot(slot, Qt.OtherFocusReason);
            calendar.goToToday();
            calendar.showEventDetails = true;
            return;
        }
        forwarding = false;
        calendarSheet.present();
    }

    onClicked: openCalendar()

    CcSheetDialog {
        id: calendarSheet
        parent: root.hostGrid ?? root
        title: I18n.tr("Calendar")
        iconName: "calendar_month"
        panelWidth: DashMetrics.sheetWidth
        showScrollBar: false
        onDismissed: {
            if (!root.forwarding && root.interactive)
                root.forceActiveFocus();
        }
        Loader {
            width: parent.width
            height: DashMetrics.heightForRows(3)
            active: calendarSheet.shown
            onLoaded: Qt.callLater(() => item?.forceActiveFocus())
            sourceComponent: CalendarOverviewCard {
                id: calendarDialog
                live: root.live && calendarSheet.shown
                onNavFocusRequested: calendarDialog.forceActiveFocus()
                onDetailRequested: eventData => {
                    root.forwarding = true;
                    calendarSheet.dismiss();
                    root.detailRequested(eventData);
                }
                onEditorRequested: (eventData, initialDate) => {
                    root.forwarding = true;
                    calendarSheet.dismiss();
                    root.editorRequested(eventData, initialDate);
                }
            }
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: -root.pad
        radius: root.bodyRadius
        color: root.accentColor

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: day.height + root.pad
            color: Theme.secondaryContainer
        }
    }
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: day.top
        clip: true
        spacing: Theme.spacingXXS
        StyledText {
            width: parent.width
            text: clock.date.toLocaleDateString(I18n.locale(), "dddd")
            color: root.onAccentColor
            font.pixelSize: Theme.fontSizeMedium
            elide: Text.ElideRight
        }
        StyledText {
            width: parent.width
            text: clock.date.toLocaleDateString(I18n.locale(), "MMMM")
            color: root.onAccentColor
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }
    StyledText {
        id: day
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: String(clock.date.getDate())
        color: Theme.onSecondaryContainer
        font.pixelSize: Theme.fontSizeDisplayLarge
        minimumPixelSize: Theme.fontSizeLarge
        fontSizeMode: Text.Fit
        width: parent.width
        height: Math.max(0, parent.height * 0.55)
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        font.weight: Theme.fontWeightMedium
    }
    SystemClock {
        id: clock
        enabled: root.live
        precision: SystemClock.Minutes
    }
}
