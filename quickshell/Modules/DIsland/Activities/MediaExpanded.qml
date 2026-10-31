pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DDash

DashTabFace {
    id: root

    activityId: "media"
    fitMediaContent: MediaOptions.borderless
    tabComponent: Component {
        MediaPlayerTab {
            live: root.live
        }
    }
}
