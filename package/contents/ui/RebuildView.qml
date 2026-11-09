import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "shared" as UI
import "components"

// Rebuild the system: pick a mode, see what runs, follow it live.
// `nixdatifier rebuild` decides the command: yours labelled "rebuild" as
// saved, else nh, else nixos-rebuild.
FocusScope {
    id: view
    property var plan: null
    property var progress: null
    property bool running: false
    property bool inTerminal: false
    property bool outputPanel: false
    property bool isBusy: false
    property bool isLoadingPlan: false
    property real fraction: -1
    property string progressLabel: ""
    property color textColor: UI.Theme.textColor
    property color accentColor: UI.Theme.highlightColor
    property real fs: 1
    property bool working: false
    property bool enableMotion: true
    property string iconStyle: "colored"
    property string mode: "switch"
    property string hostName: ""   // rebuilding another machine over ssh
    readonly property bool custom: !!(plan && plan.custom)
    readonly property var modes: [
        {
            id: "switch",
            label: qsTr("Switch"),
            hint: qsTr("Build and run it now. It is also what boots next.")
        },
        {
            id: "boot",
            label: qsTr("Boot"),
            hint: qsTr("Build and make it the next boot; the running system stays as it is.")
        },
        {
            id: "test",
            label: qsTr("Test"),
            hint: qsTr("Build and run it now without adding a boot entry; a reboot goes back.")
        },
        {
            id: "dry-build",
            label: qsTr("Dry build"),
            hint: qsTr("Only show what would be built and downloaded. Changes nothing.")
        }
    ]
    readonly property var currentMode: modes.find(m => m.id === mode) || modes[0]
    readonly property string command: {
        if (!plan || !plan.commands)
            return "";
        const entry = plan.commands[custom ? "switch" : mode] || {};
        return (outputPanel ? entry.panel : entry.terminal) || "";
    }
    readonly property string sourceLabel: !plan ? "" : custom ? qsTr("Your command") : plan.source === "nh" ? "nh" : plan.source === "nixos-rebuild" ? "nixos-rebuild" : ""
    readonly property bool finished: !!progress && !running && progress.exists
    readonly property bool failed: finished && (progress.interrupted || progress.exitCode !== 0)
    readonly property string logText: progress && progress.tail ? progress.tail.join("\n") : ""

    signal closeRequested
    signal startRequested(string mode)
    signal outputPanelToggled(bool panel)
    signal planRequested
    signal copyLogRequested
    signal historyRequested
    signal configureRequested

    function focusBack() {
        backButton.forceActiveFocus(Qt.TabFocusReason);
    }
    function formatTime(epoch) {
        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "d MMM, hh:mm") : "";
    }
    onVisibleChanged: if (visible)
        view.planRequested()
    Keys.onEscapePressed: event => {
        view.closeRequested();
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
                objectName: "rebuildBack"
                glyph: "go-previous"
                flatStyle: true
                tip: qsTr("Back to widget")
                onClicked: view.closeRequested()
            }
            UI.Flake {
                implicitWidth: 24
                implicitHeight: 24
                working: view.working && view.visible
                motion: view.enableMotion
                style: view.iconStyle
                accent: view.accentColor
            }
            Text {
                Layout.fillWidth: true
                text: view.hostName !== "" ? qsTr("Rebuild %1").arg(view.hostName) : qsTr("Rebuild")
                color: view.textColor
                font.pixelSize: 14 * view.fs
                font.weight: Font.Medium
            }
            UI.ActionButton {
                objectName: "rebuildClose"
                text: "×"
                implicitWidth: 29
                font.pixelSize: 18
                flatStyle: true
                tip: qsTr("Close rebuild")
                onClicked: view.closeRequested()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: UI.Theme.line
        }
        UI.ScrollView {
            id: scroll
            objectName: "rebuildScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: view.width < 440 ? 16 : 21
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 16
                    text: view.hostName !== "" ? (view.custom ? qsTr("Runs your command labelled “rebuild” for %1, with {host} replaced by its name.").arg(view.hostName) : qsTr("Build the configuration of %1 here and activate it on %1 over ssh.").arg(view.hostName)) : view.custom ? qsTr("Runs your command labelled “rebuild” exactly as saved, from your flake directory.") : qsTr("Build your configuration and make it the running system.")
                    color: "#9bacc4"
                    font.pixelSize: UI.Theme.fontPx(11, view.fs)
                    wrapMode: Text.Wrap
                    lineHeight: 1.5
                }

                // ── Mode ──────────────────────────────────────────────────
                Flow {
                    visible: !view.custom
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    spacing: 5
                    Repeater {
                        model: view.modes
                        UI.ActionButton {
                            required property var modelData
                            objectName: "rebuildMode-" + modelData.id
                            text: modelData.label
                            tip: modelData.hint
                            accent: view.accentColor
                            primary: view.mode === modelData.id
                            flatStyle: view.mode !== modelData.id
                            implicitHeight: 25 * view.fs
                            font.pixelSize: UI.Theme.fontPx(9, view.fs)
                            onClicked: view.mode = modelData.id
                        }
                    }
                }
                Text {
                    visible: !view.custom
                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                    text: view.currentMode.hint
                    color: "#8e9eb3"
                    font.pixelSize: UI.Theme.fontPx(9, view.fs)
                    wrapMode: Text.Wrap
                }

                // ── What runs ─────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 7
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("What runs")
                        color: "#a3b2c9"
                        font.pixelSize: UI.Theme.fontPx(10, view.fs)
                    }
                    Tag {
                        objectName: "rebuildSource"
                        visible: view.sourceLabel !== ""
                        text: view.sourceLabel
                        tone: view.custom ? view.accentColor : "#9ba8bc"
                        fs: view.fs
                    }
                }
                CodeBlock {
                    objectName: "rebuildCommand"
                    visible: view.command !== ""
                    Layout.fillWidth: true
                    text: view.command
                    accent: view.accentColor
                    fs: view.fs
                    copyTip: qsTr("Copy command")
                    onCopyRequested: t => view.copyRequested(t)
                }
                Text {
                    visible: view.isLoadingPlan && !view.plan
                    Layout.fillWidth: true
                    text: qsTr("Looking up what a rebuild would run…")
                    color: "#8e9eb3"
                    font.pixelSize: UI.Theme.fontPx(9, view.fs)
                }
                Notice {
                    visible: !!(view.plan && view.plan.error)
                    Layout.fillWidth: true
                    glyph: "ic_warning"
                    tone: UI.Theme.changed
                    emphasis: true
                    fs: view.fs
                    text: view.plan && view.plan.error ? view.plan.error : ""
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    visible: !!view.plan && !view.plan.error
                    text: view.custom ? qsTr("Every mode runs it unchanged; it gets the mode in $NIXDATIFIER_REBUILD_MODE.") : qsTr("Label one of your commands “rebuild” (Settings → Commands) to run your own script instead.")
                    color: "#7f90a8"
                    font.pixelSize: UI.Theme.fontPx(9, view.fs)
                    wrapMode: Text.Wrap
                    lineHeight: 1.4
                }

                // ── Output ────────────────────────────────────────────────
                Text {
                    Layout.topMargin: 18
                    Layout.bottomMargin: 7
                    text: qsTr("Show output")
                    color: "#a3b2c9"
                    font.pixelSize: UI.Theme.fontPx(10, view.fs)
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 5
                    UI.ActionButton {
                        objectName: "rebuildOutputTerminal"
                        text: qsTr("In a terminal")
                        tip: qsTr("Interactive: your script can ask for passwords or answers.")
                        accent: view.accentColor
                        primary: !view.outputPanel
                        flatStyle: view.outputPanel
                        implicitHeight: 25 * view.fs
                        font.pixelSize: UI.Theme.fontPx(9, view.fs)
                        onClicked: view.outputPanelToggled(false)
                    }
                    UI.ActionButton {
                        objectName: "rebuildOutputPanel"
                        text: qsTr("In this window")
                        tip: qsTr("Live output and progress here. Nothing can be typed in.")
                        accent: view.accentColor
                        primary: view.outputPanel
                        flatStyle: !view.outputPanel
                        implicitHeight: 25 * view.fs
                        font.pixelSize: UI.Theme.fontPx(9, view.fs)
                        onClicked: view.outputPanelToggled(true)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 7
                    text: view.outputPanel ? qsTr("Nothing can answer a prompt here: root access goes through the polkit dialog when pkexec is on (Settings → Behavior), and a script that asks for input fails instead of waiting.") : qsTr("Opens your terminal; the window follows the progress and the result.")
                    color: "#7f90a8"
                    font.pixelSize: UI.Theme.fontPx(9, view.fs)
                    wrapMode: Text.Wrap
                    lineHeight: 1.4
                }

                UI.ActionButton {
                    objectName: "rebuildStart"
                    Layout.topMargin: 18
                    text: view.running ? qsTr("Rebuilding…") : view.custom ? qsTr("Run your rebuild") : view.mode === "dry-build" ? qsTr("Start dry build") : qsTr("Rebuild now")
                    glyph: Qt.resolvedUrl("assets/ic_rebuild.svg")
                    primary: true
                    accent: view.accentColor
                    enabled: !view.isBusy && !view.running && !!view.plan && !view.plan.error
                    font.pixelSize: UI.Theme.fontPx(10, view.fs)
                    onClicked: view.startRequested(view.custom ? "switch" : view.mode)
                }

                // ── Progress and output ───────────────────────────────────
                Rectangle {
                    objectName: "rebuildProgress"
                    visible: view.running || view.finished
                    Layout.fillWidth: true
                    Layout.topMargin: 20
                    implicitHeight: progressColumn.implicitHeight + 26
                    radius: 8
                    color: "#05ffffff"
                    border.color: view.failed ? UI.Theme.wash(UI.Theme.changed, .3) : "#14ffffff"
                    ColumnLayout {
                        id: progressColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 13
                        spacing: 9
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                objectName: "rebuildStatus"
                                Layout.fillWidth: true
                                text: view.running ? view.progressLabel : !view.progress ? "" : view.progress.interrupted ? qsTr("The last rebuild stopped without a result") : view.progress.exitCode === 0 ? qsTr("Last rebuild finished") : qsTr("Last rebuild failed (status %1)").arg(view.progress.exitCode)
                                color: view.failed ? UI.Theme.changed : view.running ? view.accentColor : UI.Theme.positive
                                font.pixelSize: UI.Theme.fontPx(10, view.fs)
                                font.weight: Font.Medium
                                wrapMode: Text.Wrap
                            }
                            Tag {
                                visible: !!view.progress && view.progress.mode !== ""
                                text: view.progress ? view.progress.mode : ""
                                fs: view.fs
                            }
                        }
                        Rectangle {
                            visible: view.running
                            Layout.fillWidth: true
                            implicitHeight: 4
                            radius: 2
                            color: "#12ffffff"
                            clip: true
                            Rectangle {
                                id: bar
                                property real sweep: 0
                                height: parent.height
                                radius: 2
                                color: view.accentColor
                                width: view.fraction >= 0 ? parent.width * view.fraction : parent.width * (view.enableMotion ? .3 : 1)
                                x: view.fraction >= 0 || !view.enableMotion ? 0 : (parent.width + width) * sweep - width
                                Behavior on width {
                                    enabled: view.fraction >= 0
                                    NumberAnimation {
                                        duration: 300
                                    }
                                }
                                NumberAnimation on sweep {
                                    running: view.running && view.visible && view.enableMotion && view.fraction < 0
                                    from: 0
                                    to: 1
                                    duration: 1600
                                    loops: Animation.Infinite
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: {
                                const p = view.progress;
                                if (!p)
                                    return view.running && view.inTerminal ? qsTr("Follow it in your terminal.") : "";
                                const bits = [];
                                if (view.running && p.current)
                                    bits.push(qsTr("Now: %1").arg(p.current));
                                if (p.startedAt)
                                    bits.push(qsTr("Started %1").arg(view.formatTime(p.startedAt)));
                                if (!view.running && p.finishedAt && p.startedAt)
                                    bits.push(qsTr("took %1 s").arg(Math.max(0, p.finishedAt - p.startedAt)));
                                return bits.join(" · ");
                            }
                            color: "#8e9eb3"
                            font.pixelSize: UI.Theme.fontPx(9, view.fs)
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: !!view.progress && view.progress.command !== ""
                            text: view.progress ? view.progress.command : ""
                            textFormat: Text.PlainText
                            color: "#7f90a8"
                            font.family: UI.Theme.fixedWidthFont.family
                            font.pixelSize: UI.Theme.fontPx(9, view.fs)
                            elide: Text.ElideMiddle
                        }
                        Notice {
                            visible: view.failed && !!view.progress && view.progress.error !== ""
                            Layout.fillWidth: true
                            glyph: "ic_warning"
                            tone: UI.Theme.changed
                            emphasis: true
                            fs: view.fs
                            text: view.progress ? view.progress.error : ""
                        }
                        Rectangle {
                            objectName: "rebuildLog"
                            visible: view.logText !== ""
                            Layout.fillWidth: true
                            implicitHeight: Math.min(260 * view.fs, logEdit.implicitHeight + 16)
                            radius: 6
                            color: "#1a000000"
                            border.color: "#0effffff"
                            Flickable {
                                id: logFlick
                                anchors.fill: parent
                                anchors.margins: 8
                                clip: true
                                contentWidth: width
                                contentHeight: logEdit.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                // Follow new lines unless the reader scrolled up.
                                property bool follow: true
                                onMovementEnded: follow = contentY >= contentHeight - height - 4
                                onContentHeightChanged: if (follow)
                                    contentY = Math.max(0, contentHeight - height)
                                ScrollBar.vertical: UI.ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }
                                TextEdit {
                                    id: logEdit
                                    width: logFlick.width
                                    text: view.logText
                                    textFormat: TextEdit.PlainText
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.WrapAnywhere
                                    color: "#bac7d9"
                                    selectionColor: UI.Theme.wash(view.accentColor, .35)
                                    font.family: UI.Theme.fixedWidthFont.family
                                    font.pixelSize: UI.Theme.fontPx(8.5, view.fs)
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: !!view.progress && view.progress.lineCount > (view.progress.tail || []).length
                            text: qsTr("Showing the last %1 of %2 lines.").arg(view.progress ? (view.progress.tail || []).length : 0).arg(view.progress ? view.progress.lineCount : 0)
                            color: "#7f90a8"
                            font.pixelSize: UI.Theme.fontPx(8.5, view.fs)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            UI.ActionButton {
                                objectName: "rebuildCopyLog"
                                visible: view.logText !== ""
                                glyph: Qt.resolvedUrl("assets/ic_copy.svg")
                                text: qsTr("Copy log")
                                font.pixelSize: UI.Theme.fontPx(9, view.fs)
                                onClicked: view.copyLogRequested()
                            }
                            UI.ActionButton {
                                objectName: "rebuildHistory"
                                visible: view.finished
                                glyph: Qt.resolvedUrl("assets/ic_history.svg")
                                text: qsTr("Rebuild history")
                                flatStyle: true
                                font.pixelSize: UI.Theme.fontPx(9, view.fs)
                                onClicked: view.historyRequested()
                            }
                        }
                    }
                }
                UI.ActionButton {
                    objectName: "configureRebuild"
                    Layout.topMargin: 14
                    text: qsTr("Configure commands…")
                    glyph: "configure"
                    flatStyle: true
                    font.pixelSize: 10 * view.fs
                    onClicked: view.configureRequested()
                }
            }
        }
    }
    signal copyRequested(string text)
}
