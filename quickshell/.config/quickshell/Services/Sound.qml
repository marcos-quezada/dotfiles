// Audio.qml - singleton: current default sink/volume/mute, on demand refresh
// (not a live subscription - pactl subscribe would work but adds real
// complexity for a panel that's only ever looked at right after an action).

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // known outputs for this machine (Realtek ALC298 + Intel Kaby Lake HDMI/DP) -
    // hardcoded because there are only ever these three physical sinks here,
    // on a different machine: run `pactl list sinks` and update this list to match.
    readonly property var outputs: [
        { label: "Speakers",   sink: "oss_output.dsp0" },
        { label: "Headphones", sink: "oss_output.dsp1" } ,
        { label: "HDMI",       sink: "oss_output.dsp2" }
    ]
    readonly property bool expanded: Popups.current === "sound"
    
    property real   triggerX:    0
    property string currentSink: ""
    property int    volume:      0
    property bool   muted:       false

    property string _buffer: ""

    Process {
        id:       queryProc
        command:  ["sound-status"]
        stdout:   SplitParser {
            onRead: data => { root._buffer += data + "\n" }
        }
        onExited: (code, signal) => {
            root._parse(root._buffer)
            root._buffer = ""
        }
    }

    function refresh() {
        queryProc.running = true
    }

    function _parse (text) {
        var sinkMatch = text.match(/Default Sink:\s*(\S+)/)
        if (sinkMatch) root.currentSink = sinkMatch[1]

        var volMatch = text.match(/(\d+)%/)
        if (volMatch) root.volume = parseInt(volMatch[1])

        var muteMatch =  text.match(/Mute:\s(yes|no)/)
        if (muteMatch) root.muted = muteMatch[1] === "yes"
    }

    Process {
        id:       switchProc
        onExited: (code, signal) => root.refresh()
    }

    function switchOutput(sink) {
        switchProc.command = ["switch-audio-output", sink]
        switchProc.running = true
    }

    Process {
        id:       actionProc
        onExited: (code, signal) => root.refresh()
    }

    function volumeUp() {
        actionProc.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"]
        actionProc.running = true
    }

    function volumeDown() {
        actionProc.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"]
        actionProc.running = true
    }

    function toggleMute() {
        actionProc.command = ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
        actionProc.running = true
    }

    Component.onCompleted: refresh()
}
