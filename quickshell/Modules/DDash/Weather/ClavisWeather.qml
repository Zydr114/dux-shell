import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.DCommon.Widgets

ClippingRectangle {
    id: root
    property bool showCity: false
    property bool available: false
    property real clipRadius: Theme.cornerRadiusXL
    readonly property var weather: WeatherService.weather
    readonly property var today: weather.forecast?.[0] ?? null
    readonly property bool compact: height < Theme.buttonHeightM * 2
    radius: clipRadius
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.primaryContainer
    }
    Rectangle {
        width: parent.width * 1.4
        height: parent.height * 0.8
        x: -parent.width * 0.4
        y: parent.height * 0.58
        radius: height / 2
        color: Theme.secondaryContainer
    }
    Rectangle {
        width: parent.width * 1.3
        height: parent.height * 0.7
        x: parent.width * 0.3
        y: parent.height * 0.7
        radius: height / 2
        color: Theme.tertiaryContainer
    }
    DIcon {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        name: root.available ? WeatherService.getWeatherIcon(root.weather.wCode, root.weather.isDay) : "cloud_off"
        size: root.compact ? Theme.iconSize : Theme.iconSizeLarge
        color: Theme.onPrimaryContainer
    }
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingXXS
        StyledText {
            width: parent.width - Theme.iconSizeLarge
            text: root.showCity && root.weather.city ? root.weather.city : (root.available ? WeatherService.getWeatherCondition(root.weather.wCode) : I18n.tr("No Weather"))
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.onPrimaryContainer
            elide: Text.ElideRight
        }
        StyledText {
            width: parent.width
            text: root.available ? (WeatherService.formatTemp(root.weather.temp) ?? "--") : "--"
            font.pixelSize: root.compact ? Theme.fontSizeXLarge : Theme.fontSizeDisplay
            font.weight: Theme.fontWeightMedium
            color: Theme.onPrimaryContainer
            elide: Text.ElideRight
        }
    }
    StyledText {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        text: root.today ? (WeatherService.formatTemp(root.today.tempMax) ?? "--") + " / " + (WeatherService.formatTemp(root.today.tempMin) ?? "--") : ""
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Theme.fontWeightMedium
        color: Theme.onTertiaryContainer
        elide: Text.ElideRight
        visible: !root.compact && text !== ""
    }
}
