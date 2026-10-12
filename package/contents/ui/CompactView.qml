import QtQuick
import QtQuick.Layouts
import "shared" as UI

Item {
    id: root
    required property color accentColor
    required property color textColor
    required property int activeGenNum
    required property var flakeUpdates
    required property bool isBusy
    required property bool isLoadingGens
    property bool isSpinning: isBusy || isLoadingGens
    property bool enableMotion: true
    required property string compactStyle
    required property bool compactShowBadge
    required property string iconStyle
    readonly property bool pill: compactStyle === "pill"
    implicitWidth: pill ? 100 : 36
    implicitHeight: 36
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.minimumHeight: 24
    signal toggleExpanded
    Rectangle {
        anchors.fill: parent
        radius: root.pill ? height / 2 : 6
        color: mouse.containsMouse ? "#20ffffff" : root.pill ? "#10ffffff" : "transparent"
    }
    RowLayout {
        anchors.centerIn: parent
        spacing: 6
        visible: root.pill
        UI.Flake {
            implicitWidth: 24
            implicitHeight: 24
            working: root.isSpinning
            motion: root.enableMotion
            style: root.iconStyle
            accent: root.accentColor
        }
        Text {
            text: root.activeGenNum > 0 ? "#" + root.activeGenNum : "—"
            color: root.textColor
            font.pixelSize: 12
        }
    }
    UI.Flake {
        visible: !root.pill && (root.compactStyle !== "number" || root.isSpinning)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.compactStyle === "both" ? -4 : 0
        implicitWidth: root.compactStyle === "both" ? Math.min(24, root.height - 14) : Math.min(root.width, root.height) - 6
        implicitHeight: implicitWidth
        working: root.isSpinning
        motion: root.enableMotion
        style: root.iconStyle
        accent: root.accentColor
    }
    Text {
        visible: !root.pill && (root.compactStyle === "both" || root.compactStyle === "number" && !root.isSpinning)
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.compactStyle === "both" ? parent.height - height : (parent.height - height) / 2
        text: root.activeGenNum > 0 ? root.activeGenNum : "—"
        color: root.textColor
        font.pixelSize: root.compactStyle === "both" ? 10 : 13
    }
    Rectangle {
        visible: root.compactShowBadge && root.flakeUpdates.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        implicitWidth: Math.max(14, badge.implicitWidth + 6)
        implicitHeight: 14
        radius: 7
        color: root.accentColor
        Text {
            id: badge
            anchors.centerIn: parent
            text: root.flakeUpdates.length
            color: "#131923"
            font.pixelSize: 9
            font.bold: true
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleExpanded()
    }
}
