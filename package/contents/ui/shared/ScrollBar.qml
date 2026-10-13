import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.ScrollBar {
    id: control
    implicitWidth: orientation === Qt.Vertical ? 12 : 28
    implicitHeight: orientation === Qt.Vertical ? 28 : 12
    padding: 2
    hoverEnabled: true
    minimumSize: Math.min(1, 28 / Math.max(1, orientation === Qt.Vertical ? height : width))
    visible: policy === Controls.ScrollBar.AlwaysOn || (policy === Controls.ScrollBar.AsNeeded && size < 1)
    background: null

    // Keep the drag target comfortable while drawing only a slim, rounded thumb.
    contentItem: Item {
        Rectangle {
            anchors.centerIn: parent
            width: control.orientation === Qt.Vertical ? (control.hovered || control.pressed ? 6 : 4) : parent.width
            height: control.orientation === Qt.Horizontal ? (control.hovered || control.pressed ? 6 : 4) : parent.height
            radius: Math.min(width, height) / 2
            color: control.pressed ? control.palette.highlight : control.palette.text
            opacity: control.pressed ? .9 : control.hovered ? .65 : control.active ? .45 : .25
        }
    }
}
