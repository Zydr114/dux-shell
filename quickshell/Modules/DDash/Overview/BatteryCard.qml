import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.DDash

Card {
    id: root

    property bool live: Window.window?.visible ?? false
    property bool batteryRefHeld: false

    readonly property bool wide: width >= DashMetrics.gridRowUnit * 2
    readonly property bool tall: height >= DashMetrics.gridRowUnit * 2
    readonly property bool clavis: options.visualStyle === "clavis"
    readonly property string levelText: Math.round(BatteryService.batteryLevel) + "%"
    readonly property string meterStyle: options.style ?? "solid"
    readonly property bool levelColors: options.color !== "theme"
    readonly property string healthText: options.health === true && BatteryService.batteryHealth.endsWith("%") ? I18n.tr("Health %1", "battery health, %1 is a percentage").arg(BatteryService.batteryHealth) : ""

    entryId: "battery"
    tone: options.tone ?? ""
    clipContent: clavis

    function syncBatteryRef(wanted) {
        if (wanted === batteryRefHeld)
            return;
        batteryRefHeld = wanted;
        if (wanted) {
            BatteryService.addRef();
            return;
        }
        BatteryService.removeRef();
    }

    onLiveChanged: syncBatteryRef(live)
    Component.onCompleted: syncBatteryRef(live)
    Component.onDestruction: syncBatteryRef(false)

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingM
        visible: root.wide && !root.clavis

        BatteryMeter {
            id: wideMeter
            anchors.verticalCenter: parent.verticalCenter
            thickness: root.tall ? DashMetrics.batteryMeterThicknessHero : DashMetrics.batteryMeterThickness
            meterStyle: root.meterStyle
            levelColors: root.levelColors
            showNumber: false
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - wideMeter.width - parent.spacing
            spacing: Theme.spacingXXS

            StyledText {
                width: parent.width
                text: root.levelText
                font.pixelSize: root.tall ? Theme.fontSizeDisplay : Theme.fontSizeXXLarge
                font.weight: Theme.fontWeightMedium
                font.features: ({
                        "tnum": 1
                    })
                color: root.contentColor
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: BatteryService.batteryStatus
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                color: root.mutedColor
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: root.healthText
                font.pixelSize: Theme.fontSizeSmall
                color: root.mutedColor
                elide: Text.ElideRight
                visible: root.tall && text !== ""
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.spacingXS
        visible: !root.wide && !root.clavis

        BatteryMeter {
            anchors.horizontalCenter: parent.horizontalCenter
            thickness: DashMetrics.batteryMeterThicknessCompact
            meterStyle: root.meterStyle
            levelColors: root.levelColors
            showNumber: false
        }

        StyledText {
            width: parent.width
            text: root.levelText
            font.pixelSize: Theme.fontSizeXLarge
            font.weight: Theme.fontWeightMedium
            font.features: ({
                    "tnum": 1
                })
            color: root.contentColor
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            text: BatteryService.batteryStatus
            font.pixelSize: Theme.fontSizeSmall
            color: root.mutedColor
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: root.tall
        }
    }

    Loader {
        anchors.fill: parent
        anchors.margins: -root.pad
        active: root.clavis
        sourceComponent: Item {
            id: clavisBody

            readonly property real fillTop: liquid.y
            function foregroundAt(y) {
                return y >= fillTop ? root.onAccentColor : root.contentColor;
            }

            Rectangle {
                anchors.fill: parent
                color: root.chipColor
            }
            Rectangle {
                id: liquid
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * (BatteryService.batteryAvailable ? Math.max(0, Math.min(1, BatteryService.batteryLevel / 100)) : 0)
                color: root.accentColor
            }
            Row {
                id: heading
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingXS
                DIcon {
                    name: BatteryService.isCharging ? "bolt" : "battery_std"
                    size: Theme.iconSizeSmall
                    color: clavisBody.foregroundAt(heading.y + height / 2)
                }
                StyledText {
                    width: Math.max(0, parent.width - Theme.iconSizeSmall - parent.spacing)
                    text: I18n.tr("Battery")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: clavisBody.foregroundAt(heading.y + height / 2)
                    elide: Text.ElideRight
                }
            }
            StyledText {
                id: level
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.spacingM
                text: BatteryService.batteryAvailable ? root.levelText : "--"
                color: clavisBody.foregroundAt(y + height / 2)
                font.pixelSize: root.tall ? Theme.fontSizeDisplay : Theme.fontSizeXLarge
                font.weight: Theme.fontWeightMedium
                minimumPixelSize: Theme.fontSizeMedium
                fontSizeMode: Text.HorizontalFit
                elide: Text.ElideRight
            }
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: heading.bottom
                anchors.bottom: level.top
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                anchors.topMargin: Theme.spacingXS
                clip: true
                spacing: Theme.spacingXXS
                visible: root.tall
                Repeater {
                    model: [BatteryService.batteryStatus, BatteryService.estimatedSeconds() > 0 ? BatteryService.formatDuration(BatteryService.estimatedSeconds()) : "", BatteryService.formatPowerRate(false), BatteryService.batteryHealth.endsWith("%") ? I18n.tr("Health %1", "battery health, %1 is a percentage").arg(BatteryService.batteryHealth) : ""].filter(s => s !== "")
                    StyledText {
                        required property string modelData
                        width: parent.width
                        text: modelData
                        color: clavisBody.foregroundAt(parent.y + y + height / 2)
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
