pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../Common/Spectrum.js" as Spectrum

Singleton {
    id: root

    property list<int> values: Array(6).fill(0)
    readonly property real ordinaryMaximum: _activeBars === 45 ? 45 : 1000
    property list<real> spectrumValues: Array(45).fill(0)
    property int refCount: 0
    property bool cavaAvailable: false
    property bool _cavaChecked: false
    property var _spectrumTokens: []
    property int _activeBars: 0
    property bool _stopping: false
    property bool _failed: false
    readonly property bool spectrumAvailable: cavaAvailable && !_failed
    readonly property int _requestedBars: Spectrum.requestedBars(refCount, _spectrumTokens.length, SettingsData.audioVisualizerEnabled, SettingsData.reduceMotion)
    readonly property bool cavaWanted: _requestedBars > 0
    readonly property int _desiredBars: cavaAvailable ? _requestedBars : 0

    onCavaWantedChanged: {
        _checkCava();
        if (!cavaWanted)
            _failed = false;
    }
    on_DesiredBarsChanged: {
        _failed = false;
        _syncProcess();
    }

    function acquireSpectrum(token) {
        _spectrumTokens = Spectrum.addSubscriber(_spectrumTokens, token);
    }

    function releaseSpectrum(token) {
        _spectrumTokens = Spectrum.removeSubscriber(_spectrumTokens, token);
    }

    function _checkCava() {
        if (!cavaWanted || _cavaChecked || cavaCheck.running)
            return;
        cavaCheck.running = true;
    }

    function _clearValues() {
        values = Array(6).fill(0);
        spectrumValues = Array(45).fill(0);
    }

    function _syncProcess() {
        if (_stopping)
            return;
        if (cavaProcess.running) {
            if (_activeBars !== _desiredBars) {
                _stopping = true;
                cavaProcess.running = false;
            }
            return;
        }
        if (_desiredBars === 0 || _failed)
            return;
        _activeBars = _desiredBars;
        cavaProcess.running = true;
    }

    Process {
        id: cavaCheck

        command: ["sh", "-c", "command -v cava"]
        running: false
        onExited: exitCode => {
            root._cavaChecked = true;
            root.cavaAvailable = exitCode === 0 && Quickshell.env("DMS_DISABLE_CAVA") !== "1";
        }
    }

    Process {
        id: cavaProcess

        command: ["sh", "-c", `exec cava -p /dev/fd/3 3<<'CAVACONF' < /dev/null
[general]
framerate=${root._activeBars === 45 ? 45 : 25}
bars=${root._activeBars}
autosens=${root._activeBars === 45 ? 1 : 0}
sensitivity=${root._activeBars === 45 ? 100 : 30}
sleep_timer=3
lower_cutoff_freq=50
higher_cutoff_freq=${root._activeBars === 45 ? 10000 : 12000}

[output]
method=raw
raw_target=/dev/stdout
data_format=ascii
ascii_max_range=1000
channels=mono
mono_option=average

[smoothing]
noise_reduction=${root._activeBars === 45 ? 85 : 35}
integral=90
gravity=95
ignore=2
monstercat=${root._activeBars === 45 ? 1 : 1.5}
CAVACONF`]

        onExited: (exitCode, exitStatus) => {
            const stopping = root._stopping;
            root._stopping = false;
            root._activeBars = 0;
            root._clearValues();
            if (!stopping) {
                root._failed = true;
                return;
            }
            Qt.callLater(root._syncProcess);
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (root._stopping || root._activeBars !== root._desiredBars)
                    return;
                const points = Spectrum.parse(data, root._activeBars, 1000);
                if (points.length === 0)
                    return;
                if (root._activeBars === 45) {
                    if (!points.every((value, i) => value === root.spectrumValues[i]))
                        root.spectrumValues = points;
                    const bands = Spectrum.ordinaryBins(points);
                    if (!bands.every((value, i) => value === root.values[i]))
                        root.values = bands;
                } else {
                    const bands = points.map(value => Math.round(value * 1000));
                    if (!bands.every((value, i) => value === root.values[i]))
                        root.values = bands;
                }
            }
        }
    }
}
