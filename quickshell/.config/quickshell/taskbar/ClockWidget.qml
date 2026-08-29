import QtQuick
import qs

Text {
  text: Time.time
  color: Config.colors.text
  font.pixelSize: Config.settings.bar.fontSize
  font.family: Fonts.body
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
}
