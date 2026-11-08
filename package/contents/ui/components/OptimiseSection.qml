import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as UI

// Store optimisation in the Nix store card: whether Nix deduplicates on its
// own, a rough estimate of what a run would free, the last run, and the button.
ColumnLayout {
    id: section
    property var status: null       // Engine.optimiseStatus
    property var estimate: null     // Engine.optimiseEstimate
    property var lastRun: null      // Engine.lastOptimise
    property bool probing: false
    property bool estimating: false
    property bool busy: false
    // Sampling the store reads files: only on its own when store measuring is on.
    property bool autoEstimate: true
    // The card is on screen: read the status once (and the estimate, see above).
    property bool wanted: true
    property real fs: 1
    property color textColor: UI.Theme.textColor
    property color accentColor: UI.Theme.highlightColor
    signal statusRequested
    signal estimateRequested(bool force)
    signal optimiseRequested
    signal copyRequested(string text)
    spacing: 7

    readonly property bool automatic: !!status && !status.isError && (status.autoOptimise === true || status.timer === "enabled")
    readonly property bool suggest: !!status && !status.isError && status.autoOptimise === false && status.timer !== "enabled"
    readonly property string snippet: "nix.settings.auto-optimise-store = true;"

    function ensure() {
        if (!wanted)
            return;
        if (!status && !probing)
            statusRequested();
        if (autoEstimate && !estimate && !estimating)
            estimateRequested(false);
    }
    onWantedChanged: Qt.callLater(ensure)
    onEstimateChanged: if (!estimate)
        Qt.callLater(ensure)
    Component.onCompleted: Qt.callLater(ensure)

    function statusText() {
        if (!status)
            return probing ? qsTr("Checking…") : "";
        if (status.isError)
            return status.value;
        if (status.autoOptimise === true)
            return qsTr("Automatic: identical files are linked as they are added");
        if (status.timer === "enabled")
            return qsTr("Scheduled: nix-optimise.timer runs it regularly");
        return qsTr("Off: identical files are stored more than once");
    }
    function shortDate(iso) {
        const d = new Date(iso);
        return isNaN(d.getTime()) ? "" : d.toLocaleDateString(Qt.locale(), Locale.ShortFormat);
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: "#0dffffff"
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            text: qsTr("Deduplication")
            color: section.textColor
            font.pixelSize: UI.Theme.fontPx(10, section.fs)
        }
        Text {
            objectName: "optimiseStatus"
            Layout.fillWidth: true
            text: section.statusText()
            color: section.automatic ? UI.Theme.positive : section.suggest ? UI.Theme.changed : "#8fa0b7"
            font.pixelSize: UI.Theme.fontPx(9, section.fs)
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.Wrap
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            objectName: "optimiseEstimate"
            Layout.fillWidth: true
            text: section.estimating ? qsTr("Estimating (sampling the store)…") : !section.estimate ? qsTr("What optimising would free is not estimated yet.") : section.estimate.isError ? section.estimate.value : section.estimate.bytes > 0 ? qsTr("≈ %1 could be freed").arg(UI.Theme.formatBytes(section.estimate.bytes)) : qsTr("Little or nothing to free")
            color: section.estimate && !section.estimate.isError && section.estimate.bytes > 0 ? UI.Theme.changed : "#8fa0b7"
            font.pixelSize: UI.Theme.fontPx(9, section.fs)
            wrapMode: Text.Wrap
            HoverHandler {
                id: estimateHover
            }
            ToolTip.visible: estimateHover.hovered && !!section.estimate && !section.estimate.isError
            ToolTip.text: section.estimate && !section.estimate.isError ? qsTr("A rough estimate from %1 of %2 store paths: their files that are not linked yet but already exist elsewhere. A few large files make it vary between samples. The last run below is exact.").arg(section.estimate.sampledPaths).arg(section.estimate.totalPaths) : ""
        }
        UI.ActionButton {
            objectName: "optimiseEstimateButton"
            text: section.estimate ? qsTr("Estimate again") : qsTr("Estimate")
            glyph: Qt.resolvedUrl("../assets/ic_refresh.svg")
            flatStyle: true
            implicitHeight: 23 * section.fs
            font.pixelSize: UI.Theme.fontPx(9, section.fs)
            tip: qsTr("Sample about 1000 store paths and check which of their files already exist elsewhere. Takes a few seconds; the result is rough.")
            enabled: !section.estimating
            onClicked: section.estimateRequested(true)
        }
    }
    Text {
        objectName: "optimiseLastRun"
        visible: !!section.lastRun
        Layout.fillWidth: true
        text: !section.lastRun ? "" : section.lastRun.freedBytes >= 0 ? qsTr("Last run %1: freed %2").arg(section.shortDate(section.lastRun.timestamp)).arg(UI.Theme.formatBytes(section.lastRun.freedBytes) || "0 B") : qsTr("Last run %1").arg(section.shortDate(section.lastRun.timestamp))
        color: "#8fa0b7"
        font.pixelSize: UI.Theme.fontPx(9, section.fs)
        wrapMode: Text.Wrap
    }
    Notice {
        objectName: "optimiseHint"
        visible: section.suggest
        Layout.fillWidth: true
        glyph: "ic_info"
        fs: section.fs
        text: qsTr("Let Nix link identical files as they are added: put this in your configuration and rebuild. For a regular run instead, use nix.optimise.automatic = true;")
    }
    CodeBlock {
        visible: section.suggest
        Layout.fillWidth: true
        text: section.snippet
        copyTip: qsTr("Copy the setting")
        fs: section.fs
        accent: section.accentColor
        onCopyRequested: text => section.copyRequested(text)
    }
    UI.ActionButton {
        objectName: "optimiseButton"
        Layout.topMargin: 4
        text: qsTr("Optimise store…")
        glyph: Qt.resolvedUrl("../assets/ic_disk.svg")
        font.pixelSize: UI.Theme.fontPx(10, section.fs)
        tip: qsTr("Replace identical files with hard links to one copy (nix-store --optimise). Nothing is deleted; it reads the whole store and can take a while.")
        enabled: !section.busy
        onClicked: section.optimiseRequested()
    }
}
