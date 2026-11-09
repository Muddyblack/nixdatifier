import QtQuick
import QtQuick.Controls
import "../shared" as UI

// `● this-pc ▾` in the header, shown once there is more than one machine. It
// opens the hosts overview; choosing a row re-scopes the tabs.
Item {
    id: picker
    property var hosts: []
    property var status: ({})
    property string current: ""
    property string localName: ""
    property bool probing: false
    property real fs: 1
    property color textColor: UI.Theme.muted
    signal chosen(string name)
    signal refreshRequested
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    readonly property string shownName: current !== "" ? current : (localName || qsTr("this machine"))
    readonly property var shownInfo: status[current !== "" ? current : localName] || null
    readonly property color dot: !shownInfo ? UI.Theme.muted : shownInfo.state === "online" ? UI.Theme.positive : shownInfo.state === "auth" ? UI.Theme.changed : UI.Theme.negative
    readonly property bool remote: current !== ""

    Rectangle {
        id: button
        objectName: "hostPicker"
        implicitWidth: label.implicitWidth + 28
        implicitHeight: label.implicitHeight + 8
        radius: 5
        color: picker.remote ? UI.Theme.wash(UI.Theme.changed, .14) : UI.Theme.wash(picker.textColor, hover.hovered ? .1 : .05)
        border.color: picker.remote ? UI.Theme.wash(UI.Theme.changed, .35) : "transparent"
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Host: %1").arg(picker.shownName)
        HoverHandler {
            id: hover
        }
        TapHandler {
            onTapped: {
                if (!popup.opened)
                    picker.refreshRequested();
                popup.opened ? popup.close() : popup.open();
            }
        }
        Row {
            id: label
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: picker.dot
            }
            Text {
                text: picker.shownName
                color: picker.remote ? UI.Theme.changed : picker.textColor
                font.pixelSize: UI.Theme.fontPx(10, picker.fs)
                font.weight: Font.Medium
            }
            Text {
                text: "▾"
                color: UI.Theme.muted
                font.pixelSize: UI.Theme.fontPx(9, picker.fs)
            }
        }
    }
    Popup {
        id: popup
        y: button.height + 4
        width: 360
        padding: 10
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            radius: 8
            color: "#1c2533"
            border.color: "#1affffff"
        }
        contentItem: HostsCard {
            hosts: picker.hosts
            status: picker.status
            current: picker.current
            probing: picker.probing
            fs: picker.fs
            textColor: "#e6ecf5"
            onChosen: name => {
                popup.close();
                picker.chosen(name);
            }
            onRefreshRequested: picker.refreshRequested()
        }
    }
}
