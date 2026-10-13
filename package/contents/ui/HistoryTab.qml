import QtQuick
import QtQuick.Layouts
import "shared" as UI
import "components"

Item {
    id: historyTab

    required property color accentColor
    required property color textColor
    required property real fs
    required property var actionHistory
    property bool isLoadingHistory: false
    required property string activeViewMode

    // Expanded runs by key, kept outside the delegates because the list is
    // replaced after every recorded run.
    property var expandedRuns: ({})

    signal clearHistoryRequested
    signal copyToClipboard(string text)

    anchors.fill: parent
    visible: activeViewMode === "history"

    function runKey(entry) {
        return entry.timestamp + "|" + entry.action;
    }
    function toggle(key) {
        const next = Object.assign({}, expandedRuns);
        next[key] = !next[key];
        expandedRuns = next;
    }
    function formatTimestamp(iso) {
        const d = new Date(iso);
        return isNaN(d.getTime()) ? "" : Qt.formatDateTime(d, "d MMM, hh:mm");
    }
    function describe(entry) {
        const parts = [formatTimestamp(entry.timestamp)];
        if (entry.genNum > 0)
            parts.push(qsTr("generation #%1").arg(entry.genNum));
        if (!entry.success)
            parts.push(qsTr("exit code %1").arg(entry.exitCode));
        return parts.filter(p => p).join("  ·  ");
    }

    UI.ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 9

            SectionIntro {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                title: historyTab.actionHistory.length ? qsTr("%n recorded run(s)", "", historyTab.actionHistory.length) : qsTr("Nothing recorded yet")
                subtitle: qsTr("Switches, cleanups, flake updates, and custom commands. The last 50 runs are kept.")
                textColor: historyTab.textColor
                fs: historyTab.fs
                UI.ActionButton {
                    objectName: "clearHistory"
                    text: qsTr("Clear")
                    glyph: Qt.resolvedUrl("assets/ic_delete.svg")
                    tip: qsTr("Clear rebuild history")
                    flatStyle: true
                    implicitHeight: 27
                    font.pixelSize: UI.Theme.fontPx(10, historyTab.fs)
                    visible: historyTab.actionHistory.length > 0
                    onClicked: historyTab.clearHistoryRequested()
                }
            }
            Repeater {
                model: historyTab.actionHistory
                ToolRow {
                    id: run
                    required property var modelData
                    readonly property string key: historyTab.runKey(modelData)
                    readonly property bool hasOutput: (modelData.output || "") !== ""
                    Layout.fillWidth: true
                    expanded: hasOutput && !!historyTab.expandedRuns[key]
                    glyph: modelData.success ? "ic_check" : "ic_warning"
                    iconColor: modelData.success ? UI.Theme.positive : UI.Theme.negative
                    title: modelData.label || modelData.action
                    detail: historyTab.describe(modelData)
                    monoDetail: false
                    textColor: historyTab.textColor
                    fs: historyTab.fs
                    Tag {
                        text: run.modelData.success ? qsTr("Done") : qsTr("Failed")
                        tone: run.modelData.success ? UI.Theme.positive : UI.Theme.negative
                        fs: historyTab.fs
                    }
                    UI.DisclosureButton {
                        visible: run.hasOutput
                        expanded: run.expanded
                        tip: run.expanded ? qsTr("Hide output") : qsTr("Show output")
                        onClicked: historyTab.toggle(run.key)
                    }
                    details: CodeBlock {
                        Layout.fillWidth: true
                        text: run.modelData.output || ""
                        maximumHeight: 220
                        textColor: historyTab.textColor
                        accent: historyTab.accentColor
                        fs: historyTab.fs
                        copyTip: qsTr("Copy output")
                        onCopyRequested: t => historyTab.copyToClipboard(t)
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 25
                visible: !historyTab.isLoadingHistory && historyTab.actionHistory.length === 0
                text: qsTr("The output of switches, rollbacks, deletions, cleanups, and flake updates shows up here, so you can read it after the notification is gone.")
                color: "#91a4bd"
                font.pixelSize: UI.Theme.fontPx(11, historyTab.fs)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.5
            }
        }
    }
}
