import QtQuick
import QtQuick.Layouts
import "../shared" as UI

// What was checked when a view stays empty (tools/sh/doctor, also
// `nixdatifier doctor`): one row per check, with the fix, the command to run
// and, for a failed command, its output.
ColumnLayout {
    id: diagnosis
    property var result: null
    property bool busy: false
    // Only failures and warnings; nothing at all when everything checks out.
    property bool onlyProblems: false
    property real fs: 1
    property color textColor: UI.Theme.textColor
    property color accentColor: UI.Theme.highlightColor
    property string report: ""
    signal runRequested
    signal actionRequested(string action)
    signal copyRequested(string text)

    // Failures first, then warnings, then the rest in the helper's order (the report keeps that order).
    readonly property var checks: {
        if (!result || result.isError)
            return [];
        const rank = c => c.status === "fail" ? 0 : c.status === "warn" ? 1 : 2;
        return result.checks.filter(c => c.status !== "skip" && (!onlyProblems || rank(c) < 2)).map((c, i) => ({
                    c: c,
                    i: i
                })).sort((a, b) => rank(a.c) - rank(b.c) || a.i - b.i).map(e => e.c);
    }
    readonly property bool hasContent: (busy && !onlyProblems) || (!!result && (result.isError || checks.length > 0))
    // The parent's "this view is empty and on screen": runs the checks once when it turns true.
    property bool wanted: true
    visible: wanted && (hasContent || !onlyProblems)
    spacing: 8

    function ensureResult() {
        if (wanted && !result && !busy)
            runRequested();
    }
    onWantedChanged: Qt.callLater(ensureResult)
    Component.onCompleted: Qt.callLater(ensureResult)

    function tone(status) {
        return status === "ok" ? UI.Theme.positive : status === "fail" ? UI.Theme.negative : status === "warn" ? UI.Theme.changed : "#8c9db5";
    }
    function mark(status) {
        return status === "ok" ? "✔" : status === "fail" ? "✘" : status === "warn" ? "!" : "·";
    }
    function actionLabel(action) {
        return action === "configure" ? qsTr("Pick your config folder") : action === "tools" ? qsTr("Open tools") : "";
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            Layout.fillWidth: true
            text: diagnosis.busy ? qsTr("Checking your system…") : diagnosis.result && !diagnosis.result.isError && diagnosis.result.failures > 0 ? (diagnosis.result.failures === 1 ? qsTr("1 check failed") : qsTr("%1 checks failed").arg(diagnosis.result.failures)) : qsTr("What was checked")
            color: diagnosis.textColor
            font.pixelSize: UI.Theme.fontPx(11, diagnosis.fs)
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        UI.ActionButton {
            objectName: "doctorCopyReport"
            visible: !!diagnosis.result && !diagnosis.busy
            text: qsTr("Copy report")
            glyph: Qt.resolvedUrl("../assets/ic_copy.svg")
            tip: qsTr("Copy the full checklist for a bug report (the same as: nixdatifier doctor)")
            flatStyle: true
            implicitHeight: 27 * diagnosis.fs
            font.pixelSize: UI.Theme.fontPx(9, diagnosis.fs)
            onClicked: diagnosis.copyRequested(diagnosis.report)
        }
        UI.ActionButton {
            objectName: "doctorRerun"
            text: qsTr("Check again")
            glyph: Qt.resolvedUrl("../assets/ic_refresh.svg")
            enabled: !diagnosis.busy
            implicitHeight: 27 * diagnosis.fs
            font.pixelSize: UI.Theme.fontPx(9, diagnosis.fs)
            onClicked: diagnosis.runRequested()
        }
    }

    Notice {
        visible: !!diagnosis.result && !!diagnosis.result.isError && !diagnosis.busy
        Layout.fillWidth: true
        emphasis: true
        glyph: "ic_warning"
        tone: UI.Theme.negative
        fs: diagnosis.fs
        text: diagnosis.result && diagnosis.result.isError ? diagnosis.result.value : ""
    }

    Repeater {
        model: diagnosis.busy ? [] : diagnosis.checks
        Rectangle {
            id: check
            required property var modelData
            readonly property color tone: diagnosis.tone(modelData.status)
            readonly property bool problem: modelData.status === "fail" || modelData.status === "warn"
            objectName: "doctorCheck-" + modelData.id
            Layout.fillWidth: true
            implicitHeight: body.implicitHeight + 18
            radius: 7
            color: problem ? UI.Theme.wash(tone, .05) : "#03ffffff"
            border.color: problem ? UI.Theme.wash(tone, .2) : "#0bffffff"
            RowLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 9
                spacing: 9
                Text {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 14 * diagnosis.fs
                    horizontalAlignment: Text.AlignHCenter
                    text: diagnosis.mark(check.modelData.status)
                    color: check.tone
                    font.pixelSize: UI.Theme.fontPx(11, diagnosis.fs)
                    font.weight: Font.Bold
                    Accessible.name: check.modelData.status
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Text {
                        Layout.fillWidth: true
                        text: check.modelData.title
                        color: diagnosis.textColor
                        font.pixelSize: UI.Theme.fontPx(10, diagnosis.fs)
                        font.weight: Font.Medium
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: check.modelData.detail
                        textFormat: Text.PlainText
                        color: "#9fb0c7"
                        font.pixelSize: UI.Theme.fontPx(9, diagnosis.fs)
                        wrapMode: Text.Wrap
                        lineHeight: 1.3
                    }
                    Text {
                        visible: check.modelData.fix !== ""
                        Layout.fillWidth: true
                        text: "→ " + check.modelData.fix
                        textFormat: Text.PlainText
                        color: check.problem ? check.tone : "#9fb0c7"
                        font.pixelSize: UI.Theme.fontPx(9, diagnosis.fs)
                        wrapMode: Text.Wrap
                        lineHeight: 1.3
                    }
                    CodeBlock {
                        visible: check.modelData.fixCommand !== ""
                        Layout.fillWidth: true
                        text: check.modelData.fixCommand
                        copyTip: qsTr("Copy the command")
                        fs: diagnosis.fs
                        accent: diagnosis.accentColor
                        onCopyRequested: text => diagnosis.copyRequested(text)
                    }
                    CodeBlock {
                        objectName: "doctorOutput-" + check.modelData.id
                        visible: check.modelData.failedCommand !== ""
                        Layout.fillWidth: true
                        label: qsTr("Failed: %1").arg(check.modelData.failedCommand)
                        text: check.modelData.output || qsTr("(no output)")
                        copyTip: qsTr("Copy the command and its output")
                        maximumHeight: 150 * diagnosis.fs
                        fs: diagnosis.fs
                        accent: diagnosis.accentColor
                        onCopyRequested: text => diagnosis.copyRequested("$ " + check.modelData.failedCommand + "\n" + text)
                    }
                    UI.ActionButton {
                        objectName: "doctorAction-" + check.modelData.id
                        visible: check.problem && diagnosis.actionLabel(check.modelData.action) !== ""
                        text: diagnosis.actionLabel(check.modelData.action)
                        primary: true
                        accent: diagnosis.accentColor
                        implicitHeight: 27 * diagnosis.fs
                        font.pixelSize: UI.Theme.fontPx(9, diagnosis.fs)
                        onClicked: diagnosis.actionRequested(check.modelData.action)
                    }
                }
            }
        }
    }
}
