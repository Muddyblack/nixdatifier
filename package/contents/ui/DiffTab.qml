import QtQuick
import QtQuick.Layouts
import "shared" as UI
import "components"

Item {
    id: root
    property bool enableGlow: true
    required property color accentColor
    required property color textColor
    required property real fs
    required property var generations
    required property var detailsCache
    required property var pairDiffCache
    required property bool isLoadingPairDiff
    required property string diffViewMode
    required property var iconCache
    required property var metaCache
    required property bool showPackageIcons
    required property string activeViewMode
    property var storePathCache: ({})
    signal storePathRequested(var pkg)
    signal compareRequested(int genA, int genB)
    signal copyToClipboard(string text)
    signal diffViewModePicked(string mode)
    readonly property int genA: target.currentValue || -1
    readonly property int genB: source.currentValue || -1
    readonly property var result: pairDiffCache[genA + "_" + genB]
    function selectPair(a, b) {
        target.currentIndex = generations.findIndex(g => g.number === a);
        source.currentIndex = generations.findIndex(g => g.number === b);
    }
    anchors.fill: parent
    visible: activeViewMode === "diff"
    UI.ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 12
            Text {
                text: qsTr("Compare generations")
                color: root.textColor
                font.pixelSize: 12 * root.fs
                font.weight: Font.Medium
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    Text {
                        text: qsTr("From")
                        color: UI.Theme.muted
                        font.pixelSize: 9 * root.fs
                    }
                    UI.GenerationPicker {
                        id: source
                        objectName: "compare-source"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        model: root.generations
                        textColor: root.textColor
                        accentColor: root.accentColor
                        fs: root.fs
                        Accessible.name: qsTr("From generation")
                        currentIndex: root.generations.length > 1 ? 1 : 0
                    }
                }
                Text {
                    text: "→"
                    color: root.accentColor
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    Text {
                        text: qsTr("To")
                        color: UI.Theme.muted
                        font.pixelSize: 9 * root.fs
                    }
                    UI.GenerationPicker {
                        id: target
                        objectName: "compare-target"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        model: root.generations
                        textColor: root.textColor
                        accentColor: root.accentColor
                        fs: root.fs
                        Accessible.name: qsTr("To generation")
                    }
                }
                UI.ActionButton {
                    text: qsTr("Compare")
                    Layout.alignment: Qt.AlignBottom
                    primary: true
                    enabled: !root.isLoadingPairDiff && root.genA > 0 && root.genB > 0
                    onClicked: root.compareRequested(root.genA, root.genB)
                }
            }
            PackageList {
                objectName: "comparePackages"
                searchPlaceholder: qsTr("Search apps / packages…")
                Layout.fillWidth: true
                visible: root.genA === root.genB || !!root.result
                packages: root.result && root.genA !== root.genB ? root.result.diff || [] : []
                maximumHeight: Math.max(120, root.height - 160)
                viewMode: root.diffViewMode
                textColor: root.textColor
                accentColor: root.accentColor
                fs: root.fs
                iconCache: root.iconCache
                metaCache: root.metaCache
                showPackageIcons: root.showPackageIcons
                enableGlow: root.enableGlow
                storePathCache: root.storePathCache
                onStorePathRequested: pkg => root.storePathRequested(pkg)
                onCopyToClipboard: text => root.copyToClipboard(text)
            }
            Text {
                visible: !root.result && root.genA !== root.genB
                Layout.fillWidth: true
                text: root.isLoadingPairDiff ? qsTr("Loading package changes…") : qsTr("Choose two generations and compare their package closures.")
                wrapMode: Text.WordWrap
                color: UI.Theme.muted
                font.pixelSize: 10 * root.fs
            }
        }
    }
}
