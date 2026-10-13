import QtQuick
import QtQuick.Layouts
import "../shared" as UI

// Card row in the style of the Updates tab: icon box, title, detail line,
// and trailing tags or buttons. `details` holds content shown when expanded.
Rectangle {
    id: row
    property string glyph: "ic_info"
    property color iconColor: "#93a5be"
    property string title: ""
    property string detail: ""
    property bool monoDetail: true
    property bool expanded: false
    property color textColor: UI.Theme.textColor
    property real fs: 1
    default property alias trailing: trailingRow.data
    property alias details: detailsColumn.data
    implicitHeight: contents.implicitHeight + 20
    radius: 9
    color: "#03ffffff"
    border.color: "#0effffff"
    ColumnLayout {
        id: contents
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 31
                implicitHeight: 31
                radius: 8
                color: "#04ffffff"
                border.color: "#0effffff"
                UI.Icon {
                    anchors.centerIn: parent
                    width: 15
                    height: 15
                    source: Qt.resolvedUrl("../assets/" + row.glyph + ".svg")
                    isMask: true
                    color: row.iconColor
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                Text {
                    Layout.fillWidth: true
                    text: row.title
                    textFormat: Text.PlainText
                    color: row.textColor
                    font.pixelSize: UI.Theme.fontPx(11, row.fs)
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: row.detail !== ""
                    text: row.detail
                    textFormat: Text.PlainText
                    color: "#8293ab"
                    // qmllint disable missing-property
                    font.family: row.monoDetail ? UI.Theme.fixedWidthFont.family : Qt.application.font.family
                    // qmllint enable missing-property
                    font.pixelSize: UI.Theme.fontPx(9, row.fs)
                    elide: Text.ElideMiddle
                }
            }
            RowLayout {
                id: trailingRow
                spacing: 5
            }
        }
        ColumnLayout {
            id: detailsColumn
            Layout.fillWidth: true
            visible: row.expanded
            spacing: 8
        }
    }
}
