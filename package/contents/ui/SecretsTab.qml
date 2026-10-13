import QtQuick
import QtQuick.Layouts
import "shared" as UI
import "components"

Item {
    id: secretsTab

    required property color textColor
    required property real fs
    required property var deployedSecrets
    required property var sourceSecrets
    required property string activeViewMode

    anchors.fill: parent
    visible: activeViewMode === "secrets"

    readonly property var deployed: deployedSecrets
    readonly property var source: sourceSecrets
    readonly property bool sourcePlaintext: source.exists && source.encKind === "plain"

    function countLabel(n) {
        return n === 1 ? qsTr("1 secret") : qsTr("%1 secrets").arg(n);
    }
    function encLabel(s) {
        const t = s.encType === "age" ? "age" : s.encType === "pgp" ? "PGP" : s.encType === "mixed" ? "age + PGP" : "";
        if (s.encKind === "encrypted")
            return "SOPS" + (t ? " · " + t : "");
        if (s.encKind === "plain")
            return qsTr("Plain text");
        if (s.encKind === "directory")
            return qsTr("Directory");
        return s.encKind || "—";
    }

    UI.ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 9

            // ── Deployed ──────────────────────────────────────────────
            SectionIntro {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                title: qsTr("Deployed secrets")
                subtitle: secretsTab.deployed.path || qsTr("Nothing found at /run/secrets or /run/agenix.d.")
                textColor: secretsTab.textColor
                fs: secretsTab.fs
                Tag {
                    text: secretsTab.deployed.exists ? secretsTab.countLabel(secretsTab.deployed.fileCount) : qsTr("Missing")
                    tone: secretsTab.deployed.exists ? UI.Theme.positive : UI.Theme.negative
                    fs: secretsTab.fs
                }
            }
            InfoRows {
                Layout.fillWidth: true
                visible: secretsTab.deployed.exists
                textColor: secretsTab.textColor
                fs: secretsTab.fs
                rows: [
                    {
                        label: qsTr("Last modified"),
                        value: secretsTab.deployed.lastModified || "—"
                    },
                    {
                        label: qsTr("Freshness"),
                        value: secretsTab.deployed.freshness === "fresh" ? qsTr("Deployed with the running system") : qsTr("Older than the running system"),
                        tone: secretsTab.deployed.freshness === "fresh" ? UI.Theme.positive : UI.Theme.changed
                    }
                ]
            }
            Repeater {
                model: secretsTab.deployed.exists ? secretsTab.deployed.names : []
                ToolRow {
                    required property string modelData
                    Layout.fillWidth: true
                    glyph: "ic_secrets"
                    iconColor: UI.Theme.positive
                    title: modelData
                    detail: secretsTab.deployed.path.endsWith("/" + modelData) ? secretsTab.deployed.path : secretsTab.deployed.path + "/" + modelData
                    textColor: secretsTab.textColor
                    fs: secretsTab.fs
                }
            }

            // ── Encrypted source ──────────────────────────────────────
            SectionIntro {
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.bottomMargin: 8
                visible: secretsTab.source.path !== ""
                title: qsTr("Encrypted source")
                subtitle: secretsTab.source.path
                textColor: secretsTab.textColor
                fs: secretsTab.fs
                Tag {
                    text: !secretsTab.source.exists ? qsTr("Missing") : secretsTab.sourcePlaintext ? qsTr("Not encrypted") : secretsTab.countLabel(secretsTab.source.names.length)
                    tone: secretsTab.source.exists && !secretsTab.sourcePlaintext ? UI.Theme.positive : UI.Theme.negative
                    fs: secretsTab.fs
                }
            }
            Notice {
                Layout.fillWidth: true
                visible: secretsTab.sourcePlaintext
                glyph: "ic_warning"
                tone: UI.Theme.negative
                emphasis: true
                fs: secretsTab.fs
                text: qsTr("This file is not encrypted. Anyone who can read your flake can read these values.")
            }
            InfoRows {
                Layout.fillWidth: true
                visible: secretsTab.source.exists
                textColor: secretsTab.textColor
                fs: secretsTab.fs
                rows: {
                    const s = secretsTab.source;
                    const rows = [
                        {
                            label: qsTr("Last modified"),
                            value: s.lastModified || "—"
                        },
                        {
                            label: qsTr("Format"),
                            value: secretsTab.encLabel(s),
                            tone: s.encKind === "plain" ? UI.Theme.negative : undefined
                        }
                    ];
                    if (s.sopsVersion)
                        rows.push({
                            label: qsTr("SOPS version"),
                            value: s.sopsVersion
                        });
                    if (s.recipientCount > 0)
                        rows.push({
                            label: qsTr("Recipients"),
                            value: String(s.recipientCount)
                        });
                    return rows;
                }
            }
            Repeater {
                model: secretsTab.source.exists ? secretsTab.source.names : []
                ToolRow {
                    required property string modelData
                    Layout.fillWidth: true
                    glyph: "ic_secrets"
                    iconColor: secretsTab.sourcePlaintext ? UI.Theme.negative : "#93a5be"
                    title: modelData
                    detail: secretsTab.source.path.split("/").pop()
                    textColor: secretsTab.textColor
                    fs: secretsTab.fs
                }
            }
            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: secretsTab.source.path === ""
                fs: secretsTab.fs
                text: qsTr("No encrypted source file found in your flake. Set one in Settings → Behavior → Secrets.")
            }
            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 6
                fs: secretsTab.fs
                text: qsTr("Only names, paths, and metadata are shown. Secret values are never decrypted or displayed.")
            }
        }
    }
}
