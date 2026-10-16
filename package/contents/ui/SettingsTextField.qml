import QtQuick
import "SettingsTheme.js" as Theme
import QtQuick.Controls.Basic as QQC

QQC.TextField {
    id: control
    property var tone: Theme.defaults
    implicitHeight: 32
    leftPadding: 12
    rightPadding: 10
    selectByMouse: true
    color: tone.text
    placeholderTextColor: tone.dim
    selectionColor: tone.brand
    selectedTextColor: tone.brandInk
    font.family: tone.fontFamily
    font.pixelSize: 12
    background: Rectangle {
        radius: 8
        color: tone.sunk
        border.color: control.activeFocus ? tone.brand : control.hovered ? "#33ffffff" : tone.line2
    }
}
