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
}
