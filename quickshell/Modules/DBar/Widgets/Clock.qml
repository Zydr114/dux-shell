pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DBar
import qs.Modules.Plugins
import qs.DCommon.Widgets
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property var surfaceContext: null
    property bool compactMode: false
    readonly property bool showNotificationBadge: SettingsData.widgetOption("clock", widgetData, "clockNotificationBadge")
    readonly property int notificationCount: surfaceContext?.notificationCount ?? 0
    signal clockClicked

    onClicked: clockClicked()

    content: Component {
        Item {
            id: contentRoot
            readonly property real contentScale: root.grouped && implicitHeight > root.widgetThickness ? root.widgetThickness / implicitHeight : 1
            implicitWidth: root.isVerticalOrientation ? (root.grouped ? Math.max(root.contentThickness, layout.implicitWidth) : root.contentThickness) : layout.implicitWidth
            implicitHeight: root.isVerticalOrientation ? layout.implicitHeight : (root.grouped ? Math.max(root.contentThickness, layout.implicitHeight) : root.contentThickness)

            Binding {
                target: root
                property: "splitOffset"
                value: !clock.split ? 0 : root.grouped ? root.visualWidth / 2 + (layout.x + clock.x + clock.splitOffset - contentRoot.width / 2) * contentRoot.contentScale : root.horizontalPadding + layout.x + clock.x + clock.splitOffset
            }

            FontMetrics {
                id: dateMetrics
                font.family: Theme.fontFamily
                font.pixelSize: clock.fontSize
                font.weight: Theme.fontWeightBold
                font.features: ({ "tnum": 1 })
            }

            Grid {
                id: layout
                anchors.centerIn: parent
                columns: root.isVerticalOrientation ? 1 : Math.max(1, layout.visibleChildren.length)
                spacing: root.isVerticalOrientation ? Theme.spacingXXS : Theme.spacingXS
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                ClockContent {
                    id: clock
                    vertical: root.isVerticalOrientation
                    segmented: root.surfaceContext?.kind !== "dock" && root.effectivePillStyle === "segments" && !root.noBackground
                    displayMode: SettingsData.widgetOption("clock", root.widgetData, "clockCompactMode") ? "time" : "both"
                    dateFirst: root.widgetData?.clockDateOrder === "dateFirst"
                    fontSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    availableWidth: root.grouped && vertical && showDate ? Math.max(root.widgetThickness, ...dateLines.map(line => Math.ceil(dateMetrics.advanceWidth(line.replace(/\d/g, "0"))))) : root.widgetThickness
                    textColor: Theme.primary
                    dateColor: root.contentColor
                }

                Rectangle {
                    visible: root.showNotificationBadge && root.notificationCount > 0
                    width: Math.max(height, badgeText.implicitWidth + Theme.spacingXS * 2)
                    height: badgeText.implicitHeight + Theme.spacingXXS * 2
                    radius: Theme.fullRadius(width, height)
                    color: Theme.error

                    StyledText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: root.notificationCount
                        font.pixelSize: Math.round(clock.fontSize * 0.75)
                        font.weight: Theme.fontWeightMedium
                        color: Theme.onError
                    }
                }
            }
        }
    }
}
