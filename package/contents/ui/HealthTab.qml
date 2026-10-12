import QtQuick
import QtQuick.Layouts
import "shared" as UI
import "components"

// The quiet failures on a Nix system: a pending reboot, a full /boot, a release
// about to lose support, an unreachable binary cache, failed units.
Item {
    id: healthTab

    required property color accentColor
    required property color textColor
    required property real fs
    required property var healthResult
    required property string activeViewMode
    property bool isProbingHealth: false

    readonly property var h: healthResult
    readonly property bool ready: !!h && !h.isError

    signal healthRequested(bool force)
    signal copyToClipboard(string text)

    anchors.fill: parent
    visible: activeViewMode === "health"
    onVisibleChanged: if (visible)
        healthRequested(false)

    function ago(epoch) {
        if (!epoch)
            return "—";
        const days = Math.floor((Date.now() / 1000 - epoch) / 86400);
        return days < 1 ? qsTr("today") : days === 1 ? qsTr("yesterday") : days < 60 ? qsTr("%1 days ago").arg(days) : qsTr("%1 months ago").arg(Math.round(days / 30));
    }
    readonly property real bootUsed: ready && h.bootTotalKb > 0 ? 1 - h.bootAvailKb / h.bootTotalKb : -1
    readonly property int eolDays: ready && h.eol !== "" ? Math.round((Date.parse(h.eol) - Date.now()) / 86400000) : 9999
    readonly property var problems: {
        if (!ready)
            return [];
        const out = [];
        if (h.rebootRequired)
            out.push({
                tone: UI.Theme.changed,
                text: qsTr("Restart to finish the update: the running kernel (%1) is older than the one just activated%2.").arg(h.kernelRunning).arg(h.kernelNext ? " (" + h.kernelNext + ")" : "")
            });
        if (bootUsed >= 0.8)
            out.push({
                tone: bootUsed >= 0.92 ? UI.Theme.negative : UI.Theme.changed,
                text: qsTr("/boot is %1% full. Deleting old generations frees space there; a full /boot makes rebuilds fail.").arg(Math.round(bootUsed * 100))
            });
        if (h.eol !== "" && eolDays < 60)
            out.push({
                tone: eolDays < 0 ? UI.Theme.negative : UI.Theme.changed,
                text: eolDays < 0 ? qsTr("NixOS %1 has most likely reached end of life. Plan an upgrade.").arg(h.release) : qsTr("NixOS %1 is expected to reach end of life in about %2 days.").arg(h.release).arg(eolDays)
            });
        const down = h.caches.filter(c => c.status === "unreachable");
        if (down.length)
            out.push({
                tone: UI.Theme.negative,
                text: qsTr("Unreachable binary cache: %1. Builds may fall back to compiling from source.").arg(down.map(c => c.url).join(", "))
            });
        if (h.failedUnits.length)
            out.push({
                tone: UI.Theme.negative,
                text: qsTr("%n unit(s) failed.", "", h.failedUnits.length)
            });
        return out;
    }

    UI.ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 14
                spacing: 12
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Checks the things that quietly go wrong: pending reboots, /boot space, release support, binary caches and failed units.")
                    color: "#9bacc4"
                    font.pixelSize: UI.Theme.fontPx(11, healthTab.fs)
                    wrapMode: Text.Wrap
                    lineHeight: 1.5
                }
                UI.ActionButton {
                    objectName: "healthRefresh"
                    text: healthTab.isProbingHealth ? qsTr("Checking…") : qsTr("Check again")
                    glyph: Qt.resolvedUrl("assets/ic_refresh.svg")
                    enabled: !healthTab.isProbingHealth
                    font.pixelSize: UI.Theme.fontPx(10, healthTab.fs)
                    onClicked: healthTab.healthRequested(true)
                }
            }

            Notice {
                Layout.fillWidth: true
                visible: !!healthTab.h && healthTab.h.isError
                glyph: "ic_warning"
                tone: UI.Theme.negative
                emphasis: true
                fs: healthTab.fs
                text: healthTab.h && healthTab.h.isError ? healthTab.h.value : ""
            }
            Notice {
                Layout.fillWidth: true
                visible: healthTab.ready && healthTab.problems.length === 0
                glyph: "ic_check"
                tone: UI.Theme.positive
                emphasis: true
                fs: healthTab.fs
                text: qsTr("Nothing needs attention.")
            }
            Repeater {
                model: healthTab.problems
                Notice {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    glyph: "ic_warning"
                    tone: modelData.tone
                    emphasis: true
                    fs: healthTab.fs
                    text: modelData.text
                }
            }

            InfoRows {
                Layout.fillWidth: true
                Layout.topMargin: 14
                visible: healthTab.ready
                textColor: healthTab.textColor
                fs: healthTab.fs
                rows: {
                    if (!healthTab.ready)
                        return [];
                    const h = healthTab.h, out = [];
                    if (h.nixos) {
                        out.push({
                            label: qsTr("Release"),
                            value: (h.release || "—") + (h.unstable ? " (unstable)" : "") + (h.eol ? "  ·  " + qsTr("supported until about %1").arg(h.eol) : ""),
                            tone: h.eol !== "" && healthTab.eolDays < 60 ? UI.Theme.changed : undefined
                        });
                        if (h.rebootKnown)
                            out.push({
                                label: qsTr("Reboot"),
                                value: h.rebootRequired ? qsTr("Required") : qsTr("Not needed"),
                                tone: h.rebootRequired ? UI.Theme.changed : UI.Theme.positive
                            });
                        if (healthTab.bootUsed >= 0)
                            out.push({
                                label: qsTr("/boot"),
                                value: qsTr("%1% of %2 used").arg(Math.round(healthTab.bootUsed * 100)).arg(UI.Theme.formatBytes(h.bootTotalKb * 1024)) + (h.bootEntries >= 0 ? "  ·  " + qsTr("%n entries", "", h.bootEntries) : ""),
                                tone: healthTab.bootUsed >= 0.92 ? UI.Theme.negative : healthTab.bootUsed >= 0.8 ? UI.Theme.changed : undefined
                            });
                    }
                    if (h.nixVersion)
                        out.push({
                            label: qsTr("Nix"),
                            value: h.nixVersion.replace(/^nix \(Nix\) /, "")
                        });
                    if (h.experimental)
                        out.push({
                            label: qsTr("Experimental features"),
                            value: h.experimental
                        });
                    if (h.channels > 0)
                        out.push({
                            label: qsTr("Channels"),
                            value: String(h.channels)
                        });
                    if (h.hmGenerations > 0)
                        out.push({
                            label: qsTr("Home Manager"),
                            value: qsTr("%n generation(s), newest %1", "", h.hmGenerations).arg(healthTab.ago(h.hmNewest))
                        });
                    if (h.profileGenerations > 0)
                        out.push({
                            label: qsTr("nix profile"),
                            value: qsTr("%n generation(s), newest %1", "", h.profileGenerations).arg(healthTab.ago(h.profileNewest))
                        });
                    return out;
                }
            }

            Subheading {
                Layout.fillWidth: true
                Layout.topMargin: 22
                visible: healthTab.ready && healthTab.h.caches.length > 0
                text: qsTr("Binary caches")
                detail: healthTab.ready ? String(healthTab.h.caches.length) : ""
                fs: healthTab.fs
            }
            InfoRows {
                Layout.fillWidth: true
                Layout.topMargin: 9
                visible: healthTab.ready && healthTab.h.caches.length > 0
                textColor: healthTab.textColor
                fs: healthTab.fs
                rows: healthTab.ready ? healthTab.h.caches.map(c => ({
                            label: c.url.replace(/^https?:\/\//, ""),
                            value: c.status === "ok" ? qsTr("%1 ms").arg(c.ms) : c.status === "slow" ? qsTr("Slow, %1 ms").arg(c.ms) : qsTr("Unreachable"),
                            tone: c.status === "ok" ? UI.Theme.positive : c.status === "slow" ? UI.Theme.changed : UI.Theme.negative
                        })) : []
            }

            Subheading {
                Layout.fillWidth: true
                Layout.topMargin: 22
                visible: healthTab.ready && healthTab.h.failedUnits.length > 0
                text: qsTr("Failed units")
                detail: healthTab.ready ? String(healthTab.h.failedUnits.length) : ""
                fs: healthTab.fs
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 9
                Layout.bottomMargin: 6
                visible: healthTab.ready && healthTab.h.failedUnits.length > 0
                implicitHeight: unitList.implicitHeight + 12
                radius: 9
                color: "#03ffffff"
                border.color: "#0effffff"
                ColumnLayout {
                    id: unitList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 0
                    Repeater {
                        model: healthTab.ready ? healthTab.h.failedUnits : []
                        RowLayout {
                            id: unitRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: unitRow.modelData.name.replace(/\.service$/, "") + (unitRow.modelData.paired ? "  +  .path" : "")
                                    color: healthTab.textColor
                                    font.pixelSize: UI.Theme.fontPx(11, healthTab.fs)
                                    elide: Text.ElideMiddle
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: unitRow.modelData.why !== ""
                                    text: unitRow.modelData.why
                                    textFormat: Text.PlainText
                                    color: UI.Theme.muted
                                    font.pixelSize: UI.Theme.fontPx(9, healthTab.fs)
                                    wrapMode: Text.Wrap
                                }
                            }
                            Tag {
                                text: unitRow.modelData.scope === "user" ? qsTr("user") : qsTr("system")
                                tone: UI.Theme.muted
                                fs: healthTab.fs
                            }
                            Tag {
                                visible: unitRow.modelData.result !== ""
                                text: unitRow.modelData.result
                                tone: UI.Theme.negative
                                fs: healthTab.fs
                            }
                            UI.ActionButton {
                                glyph: Qt.resolvedUrl("assets/ic_copy.svg")
                                flatStyle: true
                                implicitHeight: 23
                                tip: qsTr("Copy: %1").arg(unitRow.modelData.command)
                                onClicked: healthTab.copyToClipboard(unitRow.modelData.command)
                            }
                        }
                    }
                }
            }
        }
    }
}
