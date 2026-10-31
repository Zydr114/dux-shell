pragma Singleton

import QtCore
import Quickshell
import Quickshell.Io
import qs.Common
import "ClavisPreset.js" as ClavisPreset

Singleton {
    id: root

    property var preview: null
    property bool available: false
    property bool loading: false
    property string error: ""
    readonly property string configPath: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/clavis/config.json"

    function refresh() {
        if (loading)
            return;
        preview = null;
        available = false;
        error = "";
        loading = true;
        if (configFile.path === "")
            configFile.path = configPath;
        else
            configFile.reload();
    }

    function apply() {
        if (!available || loading)
            return false;
        const next = ClavisPreset.mergeDashOptions(SettingsData.dashOptions ?? {}, preview);
        if (next === null) {
            error = "invalid-settings";
            return false;
        }
        SettingsData.set("dashOptions", next);
        return true;
    }

    function applyReference() {
        const next = ClavisPreset.mergeDashOptions(SettingsData.dashOptions ?? {}, {
            playerStyle: "clavis",
            clavisCoverStyle: "caelestia",
            clavisProgressStyle: "material",
            albumArtAccent: false
        });
        if (next !== null)
            SettingsData.set("dashOptions", next);
    }

    FileView {
        id: configFile

        path: ""
        watchChanges: false
        printErrors: false
        onLoaded: {
            const result = ClavisPreset.parse(text());
            root.preview = result.preview;
            root.error = result.error;
            root.available = result.preview !== null;
            root.loading = false;
        }
        onLoadFailed: error => {
            root.preview = null;
            root.available = false;
            root.error = error === FileViewError.FileNotFound ? "not-found" : "read-failed";
            root.loading = false;
        }
    }
}
