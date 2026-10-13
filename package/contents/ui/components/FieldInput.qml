import QtQuick
import QtQuick.Controls
import "../shared" as UI

// Text input matching the redesigned fields (search boxes, tool inputs).
TextField {
    id: field
    property real fs: 1
    property color accent: UI.Theme.highlightColor
    property color textColor: UI.Theme.textColor
    property bool mono: false
    implicitHeight: 33 * fs
    leftPadding: 10
    rightPadding: 10
    color: textColor
    placeholderTextColor: UI.Theme.muted
    selectByMouse: true
    font.pixelSize: UI.Theme.fontPx(10, fs)
    // qmllint disable missing-property
    font.family: mono ? UI.Theme.fixedWidthFont.family : Qt.application.font.family
    // qmllint enable missing-property
    background: Rectangle {
        radius: 6
        color: "#04ffffff"
        border.color: field.activeFocus ? field.accent : "#16ffffff"
    }
}
