// Playlist.qml — singleton data layer: downloaded/local tracks, the yt-dlp
// download queue, and the append-only inbox file queue-track writes to.
// no visual items live here — see the (forthcoming) popup component for that.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dataDir:  Quickshell.env("HOME") + "/.local/share/quickshell"
    readonly property string musicDir: Quickshell.env("HOME") + "/Music"

    component Track: JsonObject {
        property string title: ""
        property string path: ""
        property string sourceUrl: ""   // empty for manually-added local files
    }

    // ── persisted playlist ────────────────────────────────────────────────────

    property alias tracks: playlistAdapter.tracks

    FileView {
        path: root.dataDir + "/playlist.json"
        watchChanges: true
        onFileChanged:   reload()
        onAdapterUpdated: writeAdapter()

        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) writeAdapter()
        }

        JsonAdapter {
            id: playlistAdapter
            property list<Track> tracks: []
        }
    }

    // ── inbox: queue-track is the sole writer, append-only ───────────────────
    // we never truncate/rewrite this file ourselves — de-duplication happens
    // against the persisted track list instead, so re-reading the same lines
    // on every change is always safe.

    FileView {
        id: inboxWatcher
        path: root.dataDir + "/playlist-inbox.txt"
        watchChanges: true
        onTextChanged: root._processInbox()
        onLoadFailed: error => {} // no inbox yet — nothing queued, that's fine
    }

    function _processInbox() {
        var lines = String(inboxWatcher.text).split("\n")
        for (var i = 0; i < lines.length; i++) {
            var url = lines[i].trim()
            if (url !== "") root.addFromUrl(url)
        }
    }

    // ── download queue — one yt-dlp process at a time ─────────────────────────

    property var _pendingUrls: []
    property bool _downloading: false
    property string _currentUrl: ""
    property string _lastPrintedPath: ""

    Process {
        id: downloadProc
        stdout: SplitParser {
            onRead: data => { root._lastPrintedPath = data.trim() }
        }
        onExited: (code, signal) => {
            root._downloading = false
            if (code === 0 && root._lastPrintedPath !== "") {
                root._addTrack(root._currentUrl, root._lastPrintedPath, "")
            } else {
                console.warn("Playlist: download failed for " + root._currentUrl)
            }
            root._lastPrintedPath = ""
            root._currentUrl = ""
            root._advanceQueue()
        }
    }

    function _advanceQueue() {
        if (root._downloading || root._pendingUrls.length === 0) return

        var next = root._pendingUrls.shift()
        root._currentUrl  = next
        root._downloading = true
        downloadProc.command = [
            "yt-dlp", "-x", "--audio-format", "m4a",
            "--print", "after_move:filepath",
            "-o", root.musicDir + "/%(title)s.%(ext)s",
            next
        ]
        downloadProc.running = true
    }

    // ── public API ─────────────────────────────────────────────────────────────

    // queue a URL for download — no-op if already downloaded or already queued
    function addFromUrl(url) {
        for (var i = 0; i < root.tracks.length; i++) {
            if (root.tracks[i].sourceUrl === url) return
        }
        if (root._pendingUrls.indexOf(url) !== -1) return
        if (root._currentUrl === url) return

        root._pendingUrls.push(url)
        root._advanceQueue()
    }

    // add an existing local file directly — no download involved
    function addLocalFile(path) {
        root._addTrack("", path, "")
    }

    function play(index) {
        if (index < 0 || index >= root.tracks.length) return
        Quickshell.execDetached(["mpv", root.tracks[index].path])
    }

    function removeAt(index) {
        if (index < 0 || index >= root.tracks.length) return
        var arr = root.tracks.slice()
        arr.splice(index, 1)
        root.tracks = arr
    }

    // ── private ───────────────────────────────────────────────────────────────

    function _addTrack(sourceUrl, path, titleOverride) {
        var base = path.split("/").pop()
        var title = titleOverride || base.replace(/\.[^/.]+$/, "")
        var arr = root.tracks.slice()
        arr.push({ title: title, path: path, sourceUrl: sourceUrl })
        root.tracks = arr
    }
}
