pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list <MprisPlayer> list: Mpris.players.values

    // prefer an actively playing player over a paused/stopped one
    // matches how most "now playing" widgets behave with multiple
    // MPRIS sources (browser + mpv, etc.) active at once
    readonly property MprisPlayer active: {
        for (const p of list) {
            if (p.isPlaying)
                return p;
        }
        return list[0] ?? null;
    }
    
    readonly property string trackTitle:  active?.trackTitle  ?? ""
    readonly property string trackArtist: active?.trackArtist ?? ""
    readonly property bool   isPlaying:   active?.isPlaying   ?? false

    function togglePlaying(): void {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }
    function next(): void {
        if (active?.canGoNext)
            active.next();
    }
    function previous(): void {
        if (active?.canGoPrevious)
            active.previous()
    }

    readonly property bool shuffleSupported: active?.shuffleSupported ?? false
    readonly property bool shuffle:          active?.shuffle          ?? false
    readonly property bool loopSupported:    active?.loopSupported    ?? false
    readonly property int  loopState:        active?.loopState        ?? MprisLoopState.None

    function toggleShuffle(): void {
        if (active?.shuffleSupported)
            active.shuffle = !active.shuffle
    }
    
    function cycleLoop(): void {
        if (!active?.loopSupported) return

        if (active.loopState === MprisLoopState.None)
            active.loopState = MprisLoopState.Track
        else if (active.loopState === MprisLoopstate.track)
            active.loopState = MprisLoopState.Playlist
        else
            active.loopState = MprisLoopState.None
    }

    readonly property string loopLabel: {
        if (loopState == MprisLoopState.Track)    return "repeat: track"
        if (loopState == MprisLoopState.Playlist) return "repeat: all"
        return "repeat: off"
    }
}
