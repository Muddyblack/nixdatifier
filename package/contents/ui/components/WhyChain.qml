import QtQuick
import QtQuick.Layouts
import "../shared" as UI

// "Why is this package here?": the dependency chain from the system down to
// the package (Engine.loadWhy, tools/sh/why) as a compact vertical chain. Each
// node opens its store path, size and homepage. "Show all" lists one chain per
// thing that pulls the package in; picking one shows its chain.
ColumnLayout {
    id: why
    property var entry: null      // shortest chain
    property var allEntry: null   // one chain per origin, once asked for
    property var metaCache: ({})
    property real fs: 1
    property color textColor: "white"
    property color accentColor: UI.Theme.highlightColor
    property int chosen: -1       // index into allEntry.chains; -1 = the shortest chain
    property int openNode: -1
    readonly property int shownOrigins: 50
    readonly property var chain: chosen >= 0 && allEntry && allEntry.chains && allEntry.chains[chosen] ? allEntry.chains[chosen] : entry && entry.chains && entry.chains.length ? entry.chains[0] : null
    readonly property bool allReady: !!allEntry && allEntry.status === "ok"
    signal showAllRequested
    signal copyRequested(string text)
    spacing: 5
    onChainChanged: openNode = -1

    function kindLabel(kind) {
        return {
            "package": qsTr("systemPackages"),
            "service": qsTr("service"),
            "home-manager": qsTr("Home Manager"),
            "etc": qsTr("/etc"),
            "system": qsTr("system"),
            "root": qsTr("system")
        }[kind] || kind;
    }
    function kindTone(kind) {
        return kind === "package" ? UI.Theme.positive : kind === "home-manager" ? "#c4a7ff" : kind === "service" ? UI.Theme.changed : "#9ba8bc";
    }
    // "rsync-3.5.0" → "rsync", for the homepage lookup
    function pname(name) {
        return (name || "").replace(/-[0-9][^-]*(-[a-z]+)?$/, "");
    }
    function homepage(name) {
        const meta = why.metaCache ? why.metaCache[why.pname(name)] : undefined;
        const url = meta && meta.url ? meta.url : "";
        return /^https?:\/\//i.test(url) ? url : "https://search.nixos.org/packages?query=" + encodeURIComponent(why.pname(name));
    }

    Text {
        visible: !!why.entry && why.entry.status === "loading"
        text: qsTr("Tracing dependencies…")
        color: why.accentColor
        font.pixelSize: 9 * why.fs
    }
    Text {
        visible: !!why.entry && why.entry.status !== "loading" && !why.chain
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: why.entry ? why.entry.message || "" : ""
        textFormat: Text.PlainText
        color: why.entry && why.entry.status === "error" ? UI.Theme.negative : "#91a4bd"
        font.pixelSize: 9 * why.fs
    }

    // Who pulls it in
    RowLayout {
        visible: !!why.chain
        Layout.fillWidth: true
        spacing: 6
        Tag {
            text: why.chain ? why.kindLabel(why.chain.kind) : ""
            tone: why.chain ? why.kindTone(why.chain.kind) : "#9ba8bc"
            fs: why.fs
        }
        Text {
            objectName: "whyOrigin"
            Layout.fillWidth: true
            text: !why.chain ? "" : why.chain.path.length && why.chain.origin === why.chain.path[why.chain.path.length - 1].path ? qsTr("Pulled in directly") : qsTr("Pulled in by %1").arg(why.chain.originName)
            textFormat: Text.PlainText
            color: why.textColor
            opacity: 0.85
            font.pixelSize: 9 * why.fs
            elide: Text.ElideRight
        }
    }

    // The chain, root first
    Repeater {
        model: why.chain ? why.chain.path : []
        ColumnLayout {
            id: node
            required property var modelData
            required property int index
            readonly property bool last: why.chain && index === why.chain.path.length - 1
            readonly property bool open: why.openNode === index
            Layout.fillWidth: true
            Layout.leftMargin: Math.min(index, 8) * 10
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                Text {
                    text: node.index > 0 ? "└" : "●"
                    color: why.accentColor
                    opacity: 0.6
                    font.pixelSize: 9 * why.fs
                }
                Text {
                    objectName: "whyNode"
                    Layout.fillWidth: true
                    text: node.modelData.name
                    textFormat: Text.PlainText
                    color: node.last ? why.accentColor : why.textColor
                    font.pixelSize: 9 * why.fs
                    font.family: UI.Theme.fixedWidthFont.family
                    font.bold: node.last
                    elide: Text.ElideMiddle
                }
                Text {
                    text: node.modelData.sizeBytes > 0 ? UI.Theme.formatBytes(node.modelData.sizeBytes) : ""
                    color: why.textColor
                    opacity: 0.5
                    font.pixelSize: 8 * why.fs
                    font.family: UI.Theme.fixedWidthFont.family
                }
            }
            // Details of one node: store path (copy), homepage
            RowLayout {
                visible: node.open
                Layout.fillWidth: true
                Layout.leftMargin: 14
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: node.modelData.path
                    textFormat: Text.PlainText
                    color: why.textColor
                    opacity: 0.7
                    font.pixelSize: 8 * why.fs
                    font.family: UI.Theme.fixedWidthFont.family
                    elide: Text.ElideMiddle
                }
                UI.ActionButton {
                    glyph: "edit-copy"
                    flatStyle: true
                    implicitHeight: 20 * why.fs
                    tip: qsTr("Copy store path")
                    onClicked: why.copyRequested(node.modelData.path)
                }
                UI.ActionButton {
                    visible: node.index > 0
                    glyph: "go-up-right"
                    flatStyle: true
                    implicitHeight: 20 * why.fs
                    tip: qsTr("Homepage or nixpkgs search for %1").arg(why.pname(node.modelData.name))
                    onClicked: Qt.openUrlExternally(why.homepage(node.modelData.name))
                }
            }
            TapHandler {
                onTapped: why.openNode = node.open ? -1 : node.index
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    // Everything that pulls it in
    UI.ActionButton {
        objectName: "whyShowAll"
        visible: !!why.chain && !why.allEntry
        text: qsTr("Show all that pulls it in")
        flatStyle: true
        implicitHeight: 22 * why.fs
        font.pixelSize: 9 * why.fs
        onClicked: why.showAllRequested()
    }
    Text {
        visible: !!why.allEntry && why.allEntry.status === "loading"
        text: qsTr("Tracing every chain…")
        color: why.accentColor
        font.pixelSize: 9 * why.fs
    }
    Text {
        visible: why.allReady
        Layout.fillWidth: true
        Layout.topMargin: 4
        wrapMode: Text.Wrap
        text: !why.allReady ? "" : why.allEntry.total === 1 ? qsTr("Pulled in by 1 thing") : qsTr("Pulled in by %1 things, closest first. Pick one to see its chain.").arg(why.allEntry.total)
        color: why.textColor
        opacity: 0.65
        font.pixelSize: 8 * why.fs
    }
    Repeater {
        model: why.allReady ? why.allEntry.chains.slice(0, why.shownOrigins) : []
        Rectangle {
            id: originRow
            required property var modelData
            required property int index
            readonly property bool picked: why.chosen === index
            objectName: "whyOriginRow"
            Layout.fillWidth: true
            implicitHeight: originLine.implicitHeight + 6
            radius: 4
            color: picked ? UI.Theme.wash(why.accentColor, .12) : originHover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
            RowLayout {
                id: originLine
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 6
                Tag {
                    text: why.kindLabel(originRow.modelData.kind)
                    tone: why.kindTone(originRow.modelData.kind)
                    fs: why.fs
                }
                Text {
                    Layout.fillWidth: true
                    text: originRow.modelData.originName
                    textFormat: Text.PlainText
                    color: why.textColor
                    font.pixelSize: 9 * why.fs
                    elide: Text.ElideRight
                }
                Text {
                    text: originRow.modelData.path.length === 2 ? qsTr("1 step") : qsTr("%1 steps").arg(originRow.modelData.path.length - 1)
                    color: why.textColor
                    opacity: 0.5
                    font.pixelSize: 8 * why.fs
                }
            }
            HoverHandler {
                id: originHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: why.chosen = originRow.picked ? -1 : originRow.index
            }
        }
    }
    Text {
        visible: why.allReady && why.allEntry.total > why.shownOrigins
        text: qsTr("… and %1 more: nixdatifier why %2 --all").arg(why.allEntry ? why.allEntry.total - why.shownOrigins : 0).arg(why.allEntry ? why.allEntry.target : "")
        textFormat: Text.PlainText
        color: why.textColor
        opacity: 0.5
        font.pixelSize: 8 * why.fs
        elide: Text.ElideMiddle
        Layout.fillWidth: true
    }
}
