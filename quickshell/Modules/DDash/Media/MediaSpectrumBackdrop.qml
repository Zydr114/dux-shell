pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Modules.DDash

ClippingRectangle {
    id: root

    property bool playing: false
    property bool live: false
    property color spectrumColor: Theme.primary

    readonly property bool sampling: live && playing && visible && (Window.window?.visible ?? false) && SettingsData.audioVisualizerEnabled && !SettingsData.reduceMotion
    readonly property list<int> bands: sampling ? CavaService.values : []
    readonly property int barCount: 32
    readonly property real fullScale: 45

    color: "transparent"
    antialiasing: true

    Ref {
        service: CavaService
        active: root.sampling
    }

    Repeater {
        model: root.barCount

        Rectangle {
            required property int index

            // Interpolate the shared six bands; do not start a second audio analyzer.
            readonly property real bandPosition: index * Math.max(0, root.bands.length - 1) / (root.barCount - 1)
            readonly property int leftBand: Math.floor(bandPosition)
            readonly property real fraction: bandPosition - leftBand
            readonly property real level: ((root.bands[leftBand] ?? 0) * (1 - fraction) + (root.bands[Math.min(leftBand + 1, root.bands.length - 1)] ?? 0) * fraction) / root.fullScale

            x: index * root.width / root.barCount
            y: root.height - height
            width: Math.ceil(root.width / root.barCount)
            height: root.sampling ? Math.min(1, Math.max(0, level)) * root.height : 0
            color: root.spectrumColor
            opacity: DashMetrics.groupIdleAlpha

            Behavior on height {
                enabled: root.sampling
                NumberAnimation {
                    duration: Theme.shorterDuration
                }
            }
        }
    }
}
