import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as UI

// Packages and their known vulnerabilities (tools/sh/cve): one row per package,
// a chip per CVE coloured by severity. A chip opens the NVD advisory.
// packages: [{ name, version, cves: [{ id, severity, score, url, description, whitelisted }] }]
ColumnLayout {
    id: list
    property var packages: []
    // Rows shown before "Show all"; 0 shows every row.
    property int limit: 8
    property bool showAll: false
    // Fixed ones (an update's comparison): calm, whatever their severity.
    property bool resolved: false
    property real fs: 1
    property color textColor: UI.Theme.textColor
    spacing: 6

    function tone(severity) {
        return severity === "critical" || severity === "high" ? UI.Theme.negative : severity === "medium" ? UI.Theme.changed : UI.Theme.muted;
    }
    function severityText(severity) {
        return {
            critical: qsTr("critical"),
            high: qsTr("high"),
            medium: qsTr("medium"),
            low: qsTr("low"),
            unknown: qsTr("no score")
        }[severity] || severity;
    }
    readonly property var shown: limit > 0 && !showAll ? packages.slice(0, limit) : packages

    Repeater {
        model: list.shown
        ColumnLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: row.modelData.name
                    textFormat: Text.PlainText
                    color: list.textColor
                    font.pixelSize: UI.Theme.fontPx(10, list.fs)
                    elide: Text.ElideRight
                    Layout.maximumWidth: list.width * 0.6
                }
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.version || ""
                    textFormat: Text.PlainText
                    color: UI.Theme.muted
                    font.pixelSize: UI.Theme.fontPx(9, list.fs)
                    elide: Text.ElideRight
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 5
                Repeater {
                    model: row.modelData.cves || []
                    Rectangle {
                        id: chip
                        required property var modelData
                        objectName: "cve-" + modelData.id
                        readonly property color tone: chip.modelData.whitelisted ? UI.Theme.muted : list.resolved ? UI.Theme.positive : list.tone(chip.modelData.severity)
                        implicitWidth: chipText.implicitWidth + 12
                        implicitHeight: chipText.implicitHeight + 6
                        radius: 4
                        color: UI.Theme.wash(tone, chipHover.hovered ? .2 : .1)
                        opacity: chip.modelData.whitelisted ? 0.7 : 1
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.id + "  " + (chip.modelData.score ? chip.modelData.score : list.severityText(chip.modelData.severity)) + (chip.modelData.whitelisted ? "  ·  " + qsTr("whitelisted") : "")
                            textFormat: Text.PlainText
                            color: chip.tone
                            font.pixelSize: UI.Theme.fontPx(9, list.fs)
                        }
                        HoverHandler {
                            id: chipHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: Qt.openUrlExternally(chip.modelData.url)
                        }
                        ToolTip.visible: chipHover.hovered
                        ToolTip.delay: 500
                        ToolTip.text: list.severityText(chip.modelData.severity) + (chip.modelData.score ? " (CVSS " + chip.modelData.score + ")" : "") + (chip.modelData.description ? "\n" + String(chip.modelData.description).slice(0, 400) : "") + "\n" + qsTr("Click to open the advisory")
                    }
                }
            }
        }
    }
    UI.ActionButton {
        visible: list.limit > 0 && list.packages.length > list.limit
        text: list.showAll ? qsTr("Show fewer") : qsTr("Show all %1").arg(list.packages.length)
        flatStyle: true
        implicitHeight: 22 * list.fs
        font.pixelSize: 9 * list.fs
        onClicked: list.showAll = !list.showAll
    }
}
