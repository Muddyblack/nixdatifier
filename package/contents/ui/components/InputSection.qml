import QtQuick
import QtQuick.Layouts
import "../shared" as UI

// A collapsible list of flake inputs below the update cards: the ones that are
// up to date (each can be hidden) or the ones that are not checked (each can be
// checked again, and shows while it waits for its first result).
Rectangle {
    id: section
    // Each entry: { input, detail }
    property var entries: []
    property string title: ""
    // "hide": offer to stop checking an input. "resume": offer to check it again.
    property string mode: "hide"
    property var pendingInputs: []
    property var failedInputs: []
    property real fs: 1
    property color accentColor: "#7aa2f7"
    property bool uiActive: true
    property bool expanded: false
    // Stay open while a row is loading or failed, so the state is not hidden away.
    readonly property bool forceOpen: pendingInputs.length > 0 || failedInputs.length > 0
    signal actionRequested(string inputName)

    visible: entries.length > 0
    Layout.fillWidth: true
    Layout.topMargin: 6
    implicitHeight: column.implicitHeight + 16
    radius: 9
    color: "#03ffffff"
    border.color: "#0effffff"

    // One pulse for all loading rows; it only runs while some row is loading.
    property real pulse: 1
    SequentialAnimation on pulse {
        running: section.pendingInputs.length > 0 && section.uiActive && section.visible
        loops: Animation.Infinite
        onRunningChanged: if (!running)
            section.pulse = 1
        NumberAnimation {
            to: 0.4
            duration: 600
        }
        NumberAnimation {
            to: 1
            duration: 600
        }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 4
        UI.ActionButton {
            objectName: "sectionToggle-" + section.mode
            Layout.fillWidth: true
            flatStyle: true
            text: qsTr("%1 (%2)").arg(section.title).arg(section.entries.length)
            glyph: Qt.resolvedUrl(section.expanded || section.forceOpen ? "../assets/ic_chevron_up.svg" : "../assets/ic_chevron_down.svg")
            onClicked: section.expanded = !section.expanded
        }
        Repeater {
            model: section.expanded || section.forceOpen ? section.entries : []
            RowLayout {
                id: row
                required property var modelData
                readonly property bool pending: section.pendingInputs.indexOf(modelData.input) >= 0
                readonly property bool failed: section.failedInputs.indexOf(modelData.input) >= 0
                readonly property bool hidden: section.mode === "resume" && !pending && !failed
                Layout.fillWidth: true
                Layout.leftMargin: 6
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.input
                    color: "#91a4bd"
                    opacity: row.hidden ? 0.55 : 1
                    font.pixelSize: 11 * section.fs
                    font.strikeout: row.hidden
                    elide: Text.ElideRight
                }
                Text {
                    text: row.pending ? qsTr("checking…") : row.failed ? qsTr("could not check") : row.modelData.detail || ""
                    color: row.pending ? section.accentColor : row.failed ? UI.Theme.negative : "#7f8ba0"
                    opacity: row.pending ? section.pulse : row.hidden ? 0.55 : 1
                    font.pixelSize: 9 * section.fs
                }
                UI.ActionButton {
                    objectName: (section.mode === "hide" ? "hide-" : "resume-") + row.modelData.input
                    visible: !row.pending
                    glyph: row.failed ? "view-refresh" : section.mode === "hide" ? "view-hidden" : "view-visible"
                    implicitHeight: 27
                    tip: section.mode === "hide" ? qsTr("Stop checking %1").arg(row.modelData.input) : row.failed ? qsTr("Retry checking %1").arg(row.modelData.input) : qsTr("Check %1 again").arg(row.modelData.input)
                    onClicked: section.actionRequested(row.modelData.input)
                }
            }
        }
    }
}
