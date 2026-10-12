import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as UI

// Selectable monospace text with a copy action: hash results, snippets, logs.
ColumnLayout {
    id: block
    property string label: ""
    property string text: ""
    property color textColor: UI.Theme.textColor
    property color accent: UI.Theme.highlightColor
    property real fs: 1
    // 0 grows with the text; otherwise the text scrolls inside this height.
    property real maximumHeight: 0
    property string copyTip: qsTr("Copy")
    signal copyRequested(string text)
    spacing: 7
    Text {
        visible: block.label !== ""
        text: block.label
        color: "#a3b2c9"
        font.pixelSize: UI.Theme.fontPx(10, block.fs)
    }
    Rectangle {
        Layout.fillWidth: true
        readonly property real fullHeight: edit.implicitHeight + 16
        implicitHeight: block.maximumHeight > 0 ? Math.min(block.maximumHeight, fullHeight) : fullHeight
        radius: 6
        color: "#14000000"
        border.color: "#0effffff"
        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 8
            anchors.rightMargin: copyButton.width + 8
            clip: true
            contentWidth: width
            contentHeight: edit.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            ScrollBar.vertical: UI.ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            TextEdit {
                id: edit
                width: flick.width
                text: block.text
                textFormat: TextEdit.PlainText
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                color: block.textColor
                selectionColor: UI.Theme.wash(block.accent, .35)
                font.family: UI.Theme.fixedWidthFont.family
                font.pixelSize: UI.Theme.fontPx(9, block.fs)
            }
        }
        UI.ActionButton {
            id: copyButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            implicitHeight: 25
            glyph: Qt.resolvedUrl("../assets/ic_copy.svg")
            flatStyle: true
            tip: block.copyTip
            onClicked: block.copyRequested(block.text)
        }
    }
}
