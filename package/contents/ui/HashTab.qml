import QtQuick
import QtQuick.Layouts
import "shared" as UI
import "components"

Item {
    id: hashTab

    required property color accentColor
    required property color textColor
    required property real fs
    required property var hashResult
    required property string activeViewMode
    property bool isProbingHash: false

    property string mode: "url"
    // Result of the last run: the hash as the tool reports it, its SRI form
    // (sha256-…) as converted by Nix, and the input it was computed for.
    property string value: ""
    property string sri: ""
    property bool isError: false
    property string lastInput: ""

    readonly property var modes: [
        {
            id: "url",
            label: qsTr("URL"),
            tip: qsTr("Hash of a remote file, for fetchurl"),
            field: qsTr("File URL"),
            placeholder: "https://example.com/source.tar.gz"
        },
        {
            id: "zip",
            label: qsTr("Archive"),
            tip: qsTr("Hash of an unpacked archive, for fetchzip"),
            field: qsTr("Archive URL"),
            placeholder: "https://example.com/archive.zip"
        },
        {
            id: "github",
            label: qsTr("GitHub"),
            tip: qsTr("Hash of a repository revision, for fetchFromGitHub"),
            field: qsTr("Repository and revision"),
            placeholder: "owner/repo/v1.2.3"
        },
        {
            id: "file",
            label: qsTr("File"),
            tip: qsTr("sha256 of a local file"),
            field: qsTr("Local file"),
            placeholder: "/path/to/file"
        },
        {
            id: "store",
            label: qsTr("Store path"),
            tip: qsTr("NAR hash of a /nix/store path"),
            field: qsTr("Store path"),
            placeholder: "/nix/store/…-package"
        }
    ]
    readonly property var currentMode: modes.find(m => m.id === mode) || modes[0]

    readonly property string snippet: {
        if (value === "" || isError)
            return "";
        // Current nixpkgs prefers `hash = "sha256-…"`; keep the legacy
        // attribute only when Nix could not convert.
        const attr = sri ? '  hash = "' + sri + '";' : '  sha256 = "' + value + '";';
        switch (mode) {
        case "url":
            return 'fetchurl {\n  url = "' + lastInput + '";\n' + attr + '\n}';
        case "zip":
            return 'fetchzip {\n  url = "' + lastInput + '";\n' + attr + '\n}';
        case "github":
            {
                const parts = lastInput.split("/");
                return 'fetchFromGitHub {\n  owner = "' + (parts[0] || "") + '";\n  repo = "' + (parts[1] || "") + '";\n  rev = "' + parts.slice(2).join("/") + '";\n' + attr + '\n}';
            }
        default:
            return "";
        }
    }

    signal hashRequested(string mode, string input)
    signal copyToClipboard(string text)

    anchors.fill: parent
    visible: activeViewMode === "hash"

    function clearResult() {
        value = "";
        sri = "";
        isError = false;
    }
    function run() {
        const input = inputField.text.trim();
        if (input === "" || isProbingHash)
            return;
        clearResult();
        lastInput = input;
        hashRequested(mode, input);
    }
    onHashResultChanged: {
        const r = hashResult;
        if (r === null)
            return;
        isError = r.isError;
        value = r.isError ? String(r.value).replace(/^ERROR:\s*/, "") : r.value;
        sri = r.sri || "";
    }

    UI.ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 0

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 14
                text: qsTr("Calculate a Nix hash for a source, ready to paste into a fetcher.")
                color: "#9bacc4"
                font.pixelSize: UI.Theme.fontPx(11, hashTab.fs)
                wrapMode: Text.Wrap
                lineHeight: 1.5
            }
            Flow {
                Layout.fillWidth: true
                Layout.bottomMargin: 16
                spacing: 5
                Repeater {
                    model: hashTab.modes
                    UI.ActionButton {
                        required property var modelData
                        objectName: "hashMode-" + modelData.id
                        text: modelData.label
                        tip: modelData.tip
                        accent: hashTab.accentColor
                        primary: hashTab.mode === modelData.id
                        flatStyle: hashTab.mode !== modelData.id
                        implicitHeight: 25 * hashTab.fs
                        font.pixelSize: UI.Theme.fontPx(9, hashTab.fs)
                        onClicked: {
                            if (hashTab.mode === modelData.id)
                                return;
                            hashTab.mode = modelData.id;
                            inputField.text = "";
                            hashTab.clearResult();
                        }
                    }
                }
            }
            Text {
                Layout.bottomMargin: 7
                text: hashTab.currentMode.field
                color: "#a3b2c9"
                font.pixelSize: UI.Theme.fontPx(10, hashTab.fs)
            }
            FieldInput {
                id: inputField
                objectName: "hashInput"
                Layout.fillWidth: true
                mono: true
                placeholderText: hashTab.currentMode.placeholder
                accent: hashTab.accentColor
                textColor: hashTab.textColor
                fs: hashTab.fs
                onAccepted: hashTab.run()
            }
            UI.ActionButton {
                objectName: "hashRun"
                Layout.topMargin: 13
                text: hashTab.isProbingHash ? qsTr("Calculating…") : qsTr("Calculate hash")
                glyph: Qt.resolvedUrl("assets/ic_hash.svg")
                primary: true
                accent: hashTab.accentColor
                font.pixelSize: UI.Theme.fontPx(10, hashTab.fs)
                enabled: inputField.text.trim() !== "" && !hashTab.isProbingHash
                onClicked: hashTab.run()
            }

            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 18
                visible: hashTab.isError && hashTab.value !== ""
                glyph: "ic_warning"
                tone: UI.Theme.negative
                emphasis: true
                fs: hashTab.fs
                text: hashTab.value
            }
            CodeBlock {
                objectName: "hashValue"
                Layout.fillWidth: true
                Layout.topMargin: 18
                visible: !hashTab.isError && hashTab.value !== ""
                label: hashTab.mode === "store" ? qsTr("NAR hash") : qsTr("Hash")
                text: hashTab.value
                textColor: hashTab.textColor
                accent: hashTab.accentColor
                fs: hashTab.fs
                copyTip: qsTr("Copy hash")
                onCopyRequested: t => hashTab.copyToClipboard(t)
            }
            CodeBlock {
                objectName: "hashSri"
                Layout.fillWidth: true
                Layout.topMargin: 13
                visible: !hashTab.isError && hashTab.sri !== "" && hashTab.sri !== hashTab.value
                label: qsTr("SRI hash")
                text: hashTab.sri
                textColor: hashTab.textColor
                accent: hashTab.accentColor
                fs: hashTab.fs
                copyTip: qsTr("Copy SRI hash")
                onCopyRequested: t => hashTab.copyToClipboard(t)
            }
            CodeBlock {
                objectName: "hashSnippet"
                Layout.fillWidth: true
                Layout.topMargin: 13
                visible: hashTab.snippet !== ""
                label: qsTr("Nix snippet")
                text: hashTab.snippet
                textColor: hashTab.textColor
                accent: hashTab.accentColor
                fs: hashTab.fs
                copyTip: qsTr("Copy snippet")
                onCopyRequested: t => hashTab.copyToClipboard(t)
            }
            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 18
                fs: hashTab.fs
                text: qsTr("URLs, archives, and GitHub revisions are downloaded with nix-prefetch-url. GitHub mode hashes the source tarball of that revision.")
            }
        }
    }
}
