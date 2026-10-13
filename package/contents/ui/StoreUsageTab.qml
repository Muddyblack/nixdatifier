import QtQuick
import QtQuick.Layouts
import "shared" as UI
import "components"

Item {
    id: storeUsageTab

    required property color accentColor
    required property color textColor
    required property real fs
    required property var storeUsageResult
    property bool isProbingStoreUsage: false
    required property string activeViewMode

    readonly property var result: storeUsageResult
    readonly property bool found: !!result && !result.isError && result.exists

    signal storeUsageRequested(string path)
    signal copyToClipboard(string text)

    anchors.fill: parent
    visible: activeViewMode === "storeusage"

    function inspect() {
        const path = pathField.text.trim();
        if (path !== "" && !isProbingStoreUsage)
            storeUsageRequested(path);
    }

    // A list of store paths under a counted heading, with a copy-all action.
    component PathSection: ColumnLayout {
        id: section
        property string heading: ""
        property var paths: []
        property string copyTip: ""
        property color textColor
        property real fs: 1
        signal copyRequested(string text)
        spacing: 9
        Subheading {
            Layout.fillWidth: true
            text: section.heading
            detail: String(section.paths.length)
            fs: section.fs
            UI.ActionButton {
                glyph: Qt.resolvedUrl("assets/ic_copy.svg")
                flatStyle: true
                implicitHeight: 23
                tip: section.copyTip
                onClicked: section.copyRequested(section.paths.join("\n"))
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: list.implicitHeight + 12
            radius: 9
            color: "#03ffffff"
            border.color: "#0effffff"
            ColumnLayout {
                id: list
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0
                Repeater {
                    model: section.paths
                    Text {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        topPadding: 6
                        bottomPadding: 6
                        text: modelData
                        textFormat: Text.PlainText
                        color: section.textColor
                        opacity: .85
                        font.family: UI.Theme.fixedWidthFont.family
                        font.pixelSize: UI.Theme.fontPx(9, section.fs)
                        wrapMode: Text.WrapAnywhere
                        Rectangle {
                            visible: index > 0
                            width: parent.width
                            height: 1
                            color: "#0bffffff"
                        }
                    }
                }
            }
        }
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
                text: qsTr("Find out what keeps a store path from being garbage-collected.")
                color: "#9bacc4"
                font.pixelSize: UI.Theme.fontPx(11, storeUsageTab.fs)
                wrapMode: Text.Wrap
                lineHeight: 1.5
            }
            Text {
                Layout.bottomMargin: 7
                text: qsTr("Store path")
                color: "#a3b2c9"
                font.pixelSize: UI.Theme.fontPx(10, storeUsageTab.fs)
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                FieldInput {
                    id: pathField
                    objectName: "storePathInput"
                    Layout.fillWidth: true
                    mono: true
                    placeholderText: "/nix/store/…-package-1.0"
                    accent: storeUsageTab.accentColor
                    textColor: storeUsageTab.textColor
                    fs: storeUsageTab.fs
                    onAccepted: storeUsageTab.inspect()
                }
                UI.ActionButton {
                    objectName: "storePathInspect"
                    implicitHeight: pathField.implicitHeight
                    text: storeUsageTab.isProbingStoreUsage ? qsTr("Inspecting…") : qsTr("Inspect")
                    glyph: Qt.resolvedUrl("assets/ic_search.svg")
                    primary: true
                    accent: storeUsageTab.accentColor
                    font.pixelSize: UI.Theme.fontPx(10, storeUsageTab.fs)
                    enabled: pathField.text.trim() !== "" && !storeUsageTab.isProbingStoreUsage
                    onClicked: storeUsageTab.inspect()
                }
            }

            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 18
                visible: !!storeUsageTab.result && storeUsageTab.result.isError
                glyph: "ic_warning"
                tone: UI.Theme.negative
                emphasis: true
                fs: storeUsageTab.fs
                text: storeUsageTab.result && storeUsageTab.result.isError ? storeUsageTab.result.value : ""
            }
            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 18
                visible: !!storeUsageTab.result && !storeUsageTab.result.isError && !storeUsageTab.result.exists
                glyph: "ic_info"
                tone: UI.Theme.changed
                emphasis: true
                fs: storeUsageTab.fs
                text: qsTr("This store path is not present on disk.")
            }
            InfoRows {
                Layout.fillWidth: true
                Layout.topMargin: 18
                visible: storeUsageTab.found
                textColor: storeUsageTab.textColor
                fs: storeUsageTab.fs
                rows: storeUsageTab.found ? [
                    {
                        label: qsTr("Status"),
                        value: storeUsageTab.result.roots.length ? qsTr("Kept alive") : qsTr("No roots reported"),
                        tone: storeUsageTab.result.roots.length ? UI.Theme.changed : UI.Theme.positive
                    },
                    {
                        label: qsTr("Closure size (NAR)"),
                        value: UI.Theme.formatBytes(storeUsageTab.result.closureBytes) || "—"
                    }
                ] : []
            }
            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 9
                visible: storeUsageTab.found && storeUsageTab.result.roots.length === 0
                glyph: "ic_check"
                tone: UI.Theme.positive
                emphasis: true
                fs: storeUsageTab.fs
                text: qsTr("No GC roots were reported. Temporary roots and Nix retention settings can still prevent collection.")
            }
            PathSection {
                Layout.fillWidth: true
                Layout.topMargin: 18
                visible: storeUsageTab.found && storeUsageTab.result.roots.length > 0
                heading: qsTr("Kept alive by")
                paths: storeUsageTab.found ? storeUsageTab.result.roots : []
                copyTip: qsTr("Copy GC roots")
                textColor: storeUsageTab.textColor
                fs: storeUsageTab.fs
                onCopyRequested: t => storeUsageTab.copyToClipboard(t)
            }
            PathSection {
                Layout.fillWidth: true
                Layout.topMargin: 18
                visible: storeUsageTab.found && storeUsageTab.result.referrers.length > 0
                heading: qsTr("Referenced by")
                paths: storeUsageTab.found ? storeUsageTab.result.referrers : []
                copyTip: qsTr("Copy referrers")
                textColor: storeUsageTab.textColor
                fs: storeUsageTab.fs
                onCopyRequested: t => storeUsageTab.copyToClipboard(t)
            }
        }
    }
}
