pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets

Item {
    id: root

    property bool vertical: false
    property bool live: visible && enabled
    property string displayMode: "both"
    property bool dateFirst: false
    property real fontSize: Theme.fontSizeMedium
    property real availableWidth: fontSize * 2
    property color textColor: Theme.primary
    property color dateColor: Theme.surfaceText
    property color separatorColor: Theme.outlineButton
    property bool segmented: false
    property var locale: I18n.locale()
    property date date: systemClock.date

    readonly property string timeText: date.toLocaleTimeString(locale, SettingsData.getEffectiveTimeFormat())
    readonly property string dateText: date.toLocaleDateString(locale, SettingsData.getEffectiveDateFormat())
    readonly property var timeLines: vertical ? stackedTime() : [timeText]
    readonly property var dateLines: vertical ? stackedDate() : [dateText]
    readonly property bool showTime: displayMode !== "date"
    readonly property bool showDate: displayMode !== "time"
    readonly property bool split: segmented && !vertical && showTime && showDate
    readonly property real splitOffset: split ? layout.x + separator.x + separator.width / 2 : 0

    implicitWidth: vertical ? availableWidth : layout.implicitWidth
    implicitHeight: layout.implicitHeight

    function pad(value) {
        return String(value).padStart(2, "0");
    }

    function stackedTime() {
        const hours = date.getHours();
        const lines = [pad(SettingsData.use24HourClock ? hours : (hours % 12 || 12)), pad(date.getMinutes())];
        if (SettingsData.showSeconds)
            lines.push(pad(date.getSeconds()));
        if (!SettingsData.use24HourClock)
            lines.push(hours >= 12 ? locale.pmText : locale.amText);
        return lines;
    }

    function stackedDate() {
        const format = locale.dateFormat(Locale.ShortFormat);
        const day = pad(date.getDate());
        const month = pad(date.getMonth() + 1);
        return format.indexOf("d") < format.indexOf("M") ? [day, month] : [month, day];
    }

    component StackedLines: Column {
        id: stack

        property var lines: []
        property color color: root.textColor

        width: root.vertical ? root.availableWidth : implicitWidth

        Repeater {
            model: stack.lines.length

            NumericText {
                required property int index
                anchors.horizontalCenter: parent.horizontalCenter
                text: stack.lines[index]
                reserveText: text.replace(/\d/g, "0")
                width: Math.ceil(reservedWidth)
                horizontalAlignment: Text.AlignHCenter
                isMonospace: false
                color: stack.color
                font.pixelSize: root.fontSize
                font.weight: Theme.fontWeightBold
            }
        }
    }

    Grid {
        id: layout

        anchors.centerIn: parent
        columns: root.vertical ? 1 : Math.max(1, layout.visibleChildren.length)
        spacing: root.vertical ? 0 : Theme.spacingS
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Loader {
            sourceComponent: root.dateFirst && root.showDate || !root.showTime ? dateComponent : timeComponent
        }

        Item {
            id: separator
            visible: root.showTime && root.showDate
            width: root.vertical ? root.availableWidth : (root.split ? Theme.groupedListGap : Theme.spacingS)
            height: root.vertical ? Theme.spacingM : Theme.clockTextSize(root.fontSize)

            Rectangle {
                visible: !root.split
                anchors.centerIn: parent
                width: root.vertical ? parent.width * 0.6 : Theme.spacingXXS
                height: root.vertical ? Theme.spacingXXS : root.fontSize
                radius: Math.min(width, height) / 2
                color: root.separatorColor
            }
        }

        Loader {
            active: root.showTime && root.showDate
            visible: active
            sourceComponent: root.dateFirst ? timeComponent : dateComponent
        }
    }

    Component {
        id: timeComponent

        Column {
            width: root.vertical ? root.availableWidth : implicitWidth

            Repeater {
                model: root.timeLines.length

                Column {
                    id: timeLine

                    required property int index

                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        visible: root.vertical && timeLine.index === 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingXS
                        height: Theme.spacingS

                        Repeater {
                            model: 2

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.spacingXXS
                                height: width
                                radius: width / 2
                                color: root.separatorColor
                            }
                        }
                    }

                    RollingClock {
                        text: root.timeLines[timeLine.index]
                        fontSize: Theme.clockTextSize(root.fontSize)
                        color: root.textColor
                        decorated: !root.vertical
                        animate: root.live
                        scale: root.vertical ? Math.min(1, root.availableWidth / implicitWidth) : 1
                    }
                }
            }
        }
    }

    Component {
        id: dateComponent

        StackedLines {
            lines: root.dateLines
            color: root.dateColor
        }
    }

    SystemClock {
        id: systemClock
        enabled: root.live
        precision: SettingsData.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Connections {
        target: SessionService
        function onSessionResumed() {
            systemClock.enabled = false;
            systemClock.enabled = Qt.binding(() => root.live);
        }
    }
}
