import QtQuick
import QtQuick.Controls

// Move the live detail surface into a window; closing restores its bindings.
Window {
    id: window
    required property Item detailItem
    width: Math.min(1000, Screen.desktopAvailableWidth * 0.85)
    height: Math.min(780, Screen.desktopAvailableHeight * 0.85)
    minimumWidth: 480
    minimumHeight: 320
    color: Theme.backgroundColor
    flags: Qt.Window
    transientParent: null

    function open() {
        show();
        raise();
        requestActivate();
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        contentHeight: window.detailItem.implicitHeight + 32
    }
    Shortcut {
        sequence: "Escape"
        onActivated: window.close()
    }
    Item {
        state: window.visible ? "detached" : ""
        states: State {
            name: "detached"
            ParentChange {
                target: window.detailItem
                parent: scroll.contentItem
            }
            AnchorChanges {
                target: window.detailItem
                anchors.left: undefined
                anchors.right: undefined
                anchors.top: undefined
                anchors.bottom: undefined
                anchors.verticalCenter: undefined
                anchors.horizontalCenter: undefined
            }
            PropertyChanges {
                window.detailItem.x: 16
                window.detailItem.y: 16
                window.detailItem.width: scroll.availableWidth - 32
                window.detailItem.height: window.detailItem.implicitHeight
                window.detailItem.visible: true
            }
        }
    }
}
