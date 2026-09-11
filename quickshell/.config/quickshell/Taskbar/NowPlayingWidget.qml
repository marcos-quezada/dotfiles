import QtQuick
import qs.Services

Text {
    visible:          Players.trackTitle !== ""
    text:             Players.trackArtist !== ""
                      ? " " + Players.trackArtist + " - " + Players.trackTitle
                      : " " + Players.trackTitle
    color:            Config.colors.text
    font.pixelSize:   Config.settings.bar.fontSize
    font.family:      Fonts.body
    elide:            Text.ElideRight
    maximumLineCount: 1
}
