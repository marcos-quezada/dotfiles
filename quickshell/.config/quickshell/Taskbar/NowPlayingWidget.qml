import QtQuick
import Quickshell
import qs.Services

Text {
    function trunc(s, n) {
        return s.length > n ? s.substring(0, n) + "\u2026" : s
    }
    
    visible:          Players.trackTitle !== ""
    text:             Players.trackArtist !== ""
                      ? "\ue405 " + trunc(Players.trackArtist, 17) + " - " + trunc(Players.trackTitle, 17)
                      : "\ue405 " + trunc(Players.trackTitle, 17)
    color:            Config.colors.text
    font.pixelSize:   Config.settings.bar.fontSize
    font.family:      Fonts.body

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        onClicked:    Players.togglePlaying()

        onWheel:      wheel => {
            if (wheel.angleDelta.y > 0) Sound.volumeUp()
            else Sound.volumeDown()
        }
    }
}
