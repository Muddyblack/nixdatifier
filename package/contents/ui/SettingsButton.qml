import QtQuick
import QtQuick.Controls.Basic as QC
import "SettingsTheme.js" as Theme

QC.Button {
    id: btn
    property var tone: Theme.defaults
    property bool primary: false
    property bool compact: false
    opacity: enabled ? 1 : 0.45
    implicitWidth: contentItem.implicitWidth + 24
    implicitHeight: compact || primary ? 28 : 36
    horizontalPadding: 12
    verticalPadding: 6
    contentItem: Text {
        text: btn.text
        font.family: tone.fontFamily
        font.pixelSize: 11
        font.weight: btn.primary ? Font.DemiBold : Font.Normal
        color: btn.primary ? tone.brandInk : btn.hovered ? tone.text : tone.muted
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: btn.compact || btn.primary ? 8 : 10
        color: btn.primary ? (btn.down ? Qt.darker(tone.brand, 1.15) : tone.brand) : btn.hovered || btn.down ? tone.hover : "transparent"
        border.width: btn.primary && !btn.activeFocus ? 0 : 1
        border.color: btn.activeFocus ? tone.brand : tone.line2
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }
}
