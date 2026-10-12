import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "shared" as UI

FocusScope {
    id: root
    property var commands: []
    property color textColor: UI.Theme.textColor
    property color accentColor: UI.Theme.highlightColor
    property real fs: 1
    property bool isBusy: false
    property bool working: false
    property bool enableMotion: true
    property string iconStyle: "colored"
    readonly property var entries: Array.isArray(commands) ? commands.filter(c => c && typeof c.cmd === "string" && c.cmd.trim()).slice(0, 4) : []
    signal closeRequested
    signal configureRequested
    signal runRequested(string command, string label)
    function focusBack() {
        backButton.forceActiveFocus(Qt.TabFocusReason);
    }
    Keys.onEscapePressed: event => {
        root.closeRequested();
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 20
            Layout.bottomMargin: 18
            spacing: 9
            UI.ActionButton {
                id: backButton
                objectName: "commandsBack"
                glyph: "go-previous"
                flatStyle: true
                tip: qsTr("Back to widget")
                onClicked: root.closeRequested()
            }
            UI.Flake {
                implicitWidth: 24
                implicitHeight: 24
                working: root.working && root.visible
                motion: root.enableMotion
                style: root.iconStyle
                accent: root.accentColor
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Your commands")
                color: root.textColor
                font.pixelSize: 14 * root.fs
                font.weight: Font.Medium
            }
            UI.ActionButton {
                objectName: "commandsClose"
                text: "×"
                implicitWidth: 29
                font.pixelSize: 18
                flatStyle: true
                tip: qsTr("Close commands")
                onClicked: root.closeRequested()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: UI.Theme.line
        }
        UI.ScrollView {
            id: scroll
            objectName: "commandsScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: root.width < 440 ? 16 : 21
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 11
                    Layout.bottomMargin: 5
                    text: root.entries.length ? qsTr("Quick access to your pinned terminal commands.") : qsTr("Add your terminal commands in Settings → Commands.")
                    color: "#9bacc4"
                    font.pixelSize: 11 * root.fs
                    wrapMode: Text.WordWrap
                    lineHeight: 1.5
                }
                Repeater {
                    model: root.entries
                    AbstractButton {
                        id: commandButton
                        required property var modelData
                        required property int index
                        objectName: "command-" + index
                        readonly property string label: String(modelData.label || modelData.cmd)
                        readonly property bool stacked: commandSize.advanceWidth > availableWidth * .5 || modelData.cmd.indexOf("\n") >= 0
                        Layout.fillWidth: true
                        implicitHeight: Math.max(39 * root.fs, commandContents.implicitHeight + 20)
                        padding: 10
                        enabled: !root.isBusy
                        hoverEnabled: true
                        Accessible.name: qsTr("Run %1: %2").arg(label).arg(modelData.cmd)
                        onClicked: root.runRequested(modelData.cmd, label)
                        TextMetrics {
                            id: commandSize
                            text: commandButton.modelData.cmd
                            font.family: UI.Theme.fixedWidthFont.family
                            font.pixelSize: 9 * root.fs
                        }
                        background: Rectangle {
                            radius: 6
                            color: commandButton.down ? UI.Theme.wash(root.accentColor, .12) : commandButton.hovered ? "#09ffffff" : "#04ffffff"
                            border.color: commandButton.activeFocus ? root.accentColor : "#1cffffff"
                        }
                        contentItem: ColumnLayout {
                            id: commandContents
                            spacing: 7
                            opacity: commandButton.enabled ? 1 : .45
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 7
                                UI.Icon {
                                    source: "utilities-terminal"
                                    implicitWidth: 13
                                    implicitHeight: 13
                                    isMask: true
                                    color: "#9bacc4"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: commandButton.label
                                    textFormat: Text.PlainText
                                    color: "#bbcbe1"
                                    font.pixelSize: 10 * root.fs
                                    wrapMode: Text.Wrap
                                }
                                Text {
                                    visible: !commandButton.stacked
                                    text: commandButton.modelData.cmd
                                    textFormat: Text.PlainText
                                    color: "#bbcbe1"
                                    font.family: UI.Theme.fixedWidthFont.family
                                    font.pixelSize: 9 * root.fs
                                }
                            }
                            Text {
                                visible: commandButton.stacked
                                Layout.fillWidth: true
                                Layout.leftMargin: 20
                                text: commandButton.modelData.cmd
                                textFormat: Text.PlainText
                                color: "#9bacc4"
                                font.family: UI.Theme.fixedWidthFont.family
                                font.pixelSize: 9 * root.fs
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 15
                    implicitHeight: explanation.implicitHeight + 22
                    radius: 7
                    color: "#03ffffff"
                    border.color: "#0dffffff"
                    RowLayout {
                        id: explanation
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 11
                        spacing: 8
                        UI.Icon {
                            source: Qt.resolvedUrl("assets/ic_info.svg")
                            implicitWidth: 13
                            implicitHeight: 13
                            isMask: true
                            color: "#8c9db5"
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.isBusy ? qsTr("A command is already running. You can return to the widget to follow its progress.") : qsTr("Commands run in your terminal, from your flake directory.")
                            color: "#8c9db5"
                            font.pixelSize: 9 * root.fs
                            wrapMode: Text.WordWrap
                            lineHeight: 1.5
                        }
                    }
                }
                UI.ActionButton {
                    objectName: "configureCommands"
                    Layout.topMargin: 6
                    text: qsTr("Configure commands…")
                    glyph: "configure"
                    flatStyle: true
                    font.pixelSize: 10 * root.fs
                    onClicked: root.configureRequested()
                }
            }
        }
    }
}
