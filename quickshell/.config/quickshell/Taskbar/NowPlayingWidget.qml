import QtQuick
import qs.Services

Text {
    visible:          Players.trackTitle !== ""
    text:             Players.trackArtist !== ""
                      ? "\ue405 " + Players.trackArtist + " - " + Players.trackTitle
                      : "\ue405 " + Players.trackTitle
    color:            Config.colors.text
    font.pixelSize:   Config.settings.bar.fontSize
    font.family:      Fonts.body
    elide:            Text.ElideRight
    maximumLineCount: 1
}
