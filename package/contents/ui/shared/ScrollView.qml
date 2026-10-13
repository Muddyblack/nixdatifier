import QtQuick.Controls.Basic as Controls

Controls.ScrollView {
    id: control

    // Custom bars need the viewport geometry normally supplied by the style.
    Controls.ScrollBar.vertical: ScrollBar {
        parent: control
        x: control.mirrored ? 0 : control.width - width
        y: control.topPadding
        height: control.availableHeight
        active: control.Controls.ScrollBar.horizontal.active
    }
    Controls.ScrollBar.horizontal: ScrollBar {
        parent: control
        x: control.leftPadding
        y: control.height - height
        width: control.availableWidth
        active: control.Controls.ScrollBar.vertical.active
    }
}
