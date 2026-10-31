import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash

Item {
    id: root

    property date clockDate: new Date()
    property string hourText: ""
    property string minuteText: ""
    property string dateText: ""
    property bool showSeconds: false
    property bool live: false
    property var clockOptions: ({})
    property color accent: Theme.primary
    property color foreground: Theme.onPrimary
    property color supportingColor: Theme.onSurface
    readonly property int sides: Math.max(0, Math.min(40, Math.round(Number(clockOptions.cookieSides ?? 14))))
    readonly property string dialStyle: clockOptions.cookieDial ?? "full"
    readonly property string hourStyle: clockOptions.cookieHourHand ?? "fill"
    readonly property string minuteStyle: clockOptions.cookieMinuteHand ?? "medium"
    readonly property string secondStyle: clockOptions.cookieSecondHand ?? "dot"
    readonly property string dateStyle: clockOptions.cookieDate ?? "bubble"
    readonly property bool dateVisible: dateText !== "" && dateStyle !== "hide"
    readonly property real dateHeight: dateVisible ? Theme.buttonHeightS : 0
    readonly property real dialSize: Math.max(0, Math.min(width, height - (dateVisible ? dateHeight + Theme.spacingXS : 0)))

    Item {
        id: dial
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, (root.height - root.dialSize - (root.dateVisible ? root.dateHeight + Theme.spacingXS : 0)) / 2)
        width: root.dialSize
        height: width

        Canvas {
            id: shape
            anchors.fill: parent
            rotation: 0
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            readonly property int petals: root.sides
            readonly property color fillColor: root.accent
            onPetalsChanged: requestPaint()
            onFillColorChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const radius = width / 2;
                ctx.beginPath();
                for (let i = 0; i <= 240; ++i) {
                    const angle = i * Math.PI * 2 / 240;
                    const r = radius * (petals < 2 ? 0.96 : 0.9 + 0.06 * Math.cos(angle * petals));
                    const x = radius + Math.cos(angle) * r;
                    const y = radius + Math.sin(angle) * r;
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.closePath();
                ctx.fillStyle = fillColor;
                ctx.fill();
            }
            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: Theme.clavisCoverRotationDuration
                loops: Animation.Infinite
                running: root.live && root.visible && root.clockOptions.cookieRotate === true && !SettingsData.reduceMotion
            }
        }

        Repeater {
            model: root.dialStyle === "none" ? 0 : (root.dialStyle === "full" ? 60 : 12)
            Item {
                required property int index
                anchors.centerIn: parent
                width: dial.width
                height: dial.height
                rotation: index * (root.dialStyle === "full" ? 6 : 30)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.1
                    width: root.dialStyle === "full" && index % 5 === 0 ? Theme.spacingXXS : Theme.outlineWidth
                    height: root.dialStyle === "full" ? (index % 5 === 0 ? Theme.spacingM : Theme.spacingXS) : Theme.spacingXXS
                    radius: width / 2
                    color: root.foreground
                    visible: root.dialStyle !== "numbers"
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.08
                    text: index === 0 ? "12" : String(index)
                    color: root.foreground
                    rotation: -parent.rotation
                    font.pixelSize: Theme.fontSizeSmall
                    visible: root.dialStyle === "numbers"
                }
            }
        }

        Hand {
            z: 1
            visible: root.hourStyle !== "hide"
            angle: (root.clockDate.getHours() % 12 + root.clockDate.getMinutes() / 60) * 30
            lengthRatio: 0.24
            thickness: root.hourStyle === "classic" ? Theme.spacingXS : Theme.spacingM
            hollow: root.hourStyle === "hollow"
        }
        Hand {
            z: 1
            visible: root.minuteStyle !== "hide"
            angle: (root.clockDate.getMinutes() + (root.showSeconds ? root.clockDate.getSeconds() / 60 : 0)) * 6
            lengthRatio: 0.34
            thickness: root.minuteStyle === "bold" ? Theme.spacingM : (root.minuteStyle === "medium" ? Theme.spacingS : (root.minuteStyle === "classic" ? Theme.spacingXS : Theme.spacingXXS))
        }
        Hand {
            z: 1
            visible: root.showSeconds && root.secondStyle !== "hide" && root.secondStyle !== "dot"
            angle: root.clockDate.getSeconds() * 6
            lengthRatio: 0.37
            thickness: root.secondStyle === "classic" ? Theme.spacingXS : Theme.spacingXXS
        }
        Rectangle {
            z: 1
            visible: root.showSeconds && root.secondStyle === "dot"
            width: Theme.spacingS
            height: width
            radius: width / 2
            color: root.foreground
            x: dial.width / 2 + Math.sin(root.clockDate.getSeconds() * Math.PI / 30) * dial.width * 0.37 - width / 2
            y: dial.height / 2 - Math.cos(root.clockDate.getSeconds() * Math.PI / 30) * dial.height * 0.37 - height / 2
        }
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.55
            spacing: 0
            StyledText {
                width: parent.width
                height: dial.height * 0.25
                text: root.hourText
                color: Theme.withAlpha(root.foreground, DashMetrics.mutedAlpha)
                font.pixelSize: Theme.fontSizeDisplayLarge
                minimumPixelSize: Theme.fontSizeSmall
                fontSizeMode: Text.Fit
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            StyledText {
                width: parent.width
                height: dial.height * 0.25
                text: root.minuteText
                color: Theme.withAlpha(root.foreground, DashMetrics.mutedAlpha)
                font.pixelSize: Theme.fontSizeDisplayLarge
                minimumPixelSize: Theme.fontSizeSmall
                fontSizeMode: Text.Fit
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    component Hand: Rectangle {
        id: hand

        required property real angle
        required property real lengthRatio
        required property real thickness
        property bool hollow: false
        x: (dial.width - width) / 2
        y: dial.height / 2 - height
        width: thickness
        height: dial.height * lengthRatio
        radius: width / 2
        color: hollow ? "transparent" : root.foreground
        border.width: hollow ? Theme.outlineWidthFocused : 0
        border.color: root.foreground
        transform: Rotation {
            origin.x: hand.width / 2
            origin.y: hand.height
            angle: hand.angle
        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dial.bottom
        anchors.topMargin: Theme.spacingXS
        width: Math.min(parent.width, dateLabel.implicitWidth + Theme.spacingM * 2)
        height: root.dateHeight
        radius: root.dateStyle === "rect" ? Theme.cornerRadiusS : height / 2
        color: root.dateStyle === "border" ? "transparent" : root.accent
        border.width: root.dateStyle === "border" ? Theme.outlineWidth : 0
        border.color: root.accent
        visible: root.dateVisible
        StyledText {
            id: dateLabel
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: Theme.spacingS
            text: root.dateText
            color: root.dateStyle === "border" ? root.supportingColor : root.foreground
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
