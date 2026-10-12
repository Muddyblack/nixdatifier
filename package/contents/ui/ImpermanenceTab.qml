pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "shared" as UI
import "components"

// Folders that survive a reboot on a system whose root is wiped on every boot.
// Everything else is gone after a restart, so these are the places where old
// data piles up and where malware would have to live to come back.
Item {
    id: tab
    objectName: "impermanenceTab"

    required property color accentColor
    required property color textColor
    required property real fs
    required property string activeViewMode
    required property var impermanence
    property var listing: null
    property var scan: null
    property var cleanup: null
    property bool isListing: false
    property bool isScanning: false
    property bool isAnalyzing: false
    property bool isRemoving: false
    property int staleDays: 180

    property string lens: "browse"   // "browse" | "security" | "cleanup"
    property string filter: "all"    // "all" | "stale" | "risky" | "hidden"
    property bool showMinor: false
    property string pendingPath: ""

    signal listRequested(string path, bool force)
    signal scanRequested(bool force)
    signal analyzeRequested(bool force)
    signal removeRequested(string path, string name)
    signal openRequested(string path)
    signal clamScanRequested
    signal copyToClipboard(string text)

    anchors.fill: parent
    visible: activeViewMode === "impermanence"

    readonly property var tints: ["#91bcff", "#6ee7b7", "#f2cc70", "#fb858f", "#c4a7ff", "#7dd3fc", "#fdba74"]
    readonly property var severityRank: ({
            "high": 0,
            "medium": 1,
            "low": 2,
            "info": 3
        })
    readonly property bool listingOk: !!listing && !listing.isError
    readonly property bool scanOk: !!scan && !scan.isError
    readonly property bool cleanupOk: !!cleanup && !cleanup.isError

    // Control characters in names come through as \xHH; show the character.
    function plain(text) {
        return String(text || "").replace(/\\(\\|x[0-9a-fA-F]{2})/g, (m, g) => g === "\\" ? "\\" : String.fromCharCode(parseInt(g.slice(1), 16)));
    }
    // Last component of an escaped path; names with control characters stay visible as \xHH.
    function baseName(path) {
        const parts = String(path || "").split("/").filter(p => p !== "");
        return parts.length ? parts[parts.length - 1] : String(path || "");
    }
    function ageDays(ts) {
        return (Date.now() / 1000 - ts) / 86400;
    }
    function ago(ts) {
        if (!ts)
            return "—";
        const days = Math.floor(ageDays(ts));
        if (days < 1)
            return qsTr("today");
        if (days < 60)
            return days === 1 ? qsTr("yesterday") : qsTr("%1 days ago").arg(days);
        if (days < 730)
            return qsTr("%1 months ago").arg(Math.floor(days / 30));
        return qsTr("%1 years ago").arg(Math.floor(days / 365));
    }
    function itemCount(n) {
        return n === 1 ? qsTr("1 item") : qsTr("%1 items").arg(n);
    }
    function severityTone(severity) {
        return severity === "high" ? UI.Theme.negative : severity === "medium" ? UI.Theme.changed : "#93a5be";
    }
    function severityLabel(severity) {
        return severity === "high" ? qsTr("Check now") : severity === "medium" ? qsTr("Review") : severity === "low" ? qsTr("Note") : qsTr("Info");
    }
    function isBound(item) {
        const path = plain(item.path);
        return impermanence.entries.some(e => e.source === path);
    }
    function browse(path) {
        lens = "browse";
        pendingPath = "";
        listRequested(path, false);
    }
    function setLens(next) {
        lens = next;
        pendingPath = "";
        if (next === "security" && !scan && !isScanning)
            scanRequested(false);
        if (next === "cleanup" && !cleanup && !isAnalyzing)
            analyzeRequested(false);
    }
    onVisibleChanged: {
        if (visible && !listing && !isListing)
            listRequested("", false);
    }

    // Path from the area root down to the folder being shown.
    readonly property var crumbs: {
        if (!listingOk || !listing.dir)
            return [];
        const base = listing.area;
        const rel = listing.dir.length > base.length ? listing.dir.slice(base.length + 1) : "";
        const out = [
            {
                label: plain(base),
                path: base
            }
        ];
        let acc = base;
        for (const seg of rel.split("/").filter(s => s !== "")) {
            acc = acc + "/" + seg;
            out.push({
                label: plain(seg),
                path: acc
            });
        }
        return out;
    }

    // Proportions of the folder on show: the largest children, then the rest.
    readonly property var strip: {
        if (!listingOk || listing.total <= 0)
            return [];
        const out = [];
        let rest = 0;
        listing.items.forEach(function (item, i) {
            if (i < tints.length && item.size / listing.total >= 0.01)
                out.push({
                    name: item.label,
                    size: item.size,
                    color: tints[i]
                });
            else
                rest += item.size;
        });
        if (rest > 0)
            out.push({
                name: qsTr("Everything else"),
                size: rest,
                color: "#4a5568"
            });
        return out;
    }

    readonly property var shownItems: {
        if (!listingOk)
            return [];
        return listing.items.filter(function (item) {
            if (filter === "stale")
                return ageDays(item.newest) > staleDays;
            if (filter === "risky")
                return /[xswc]/.test(item.flags);
            if (filter === "hidden")
                return item.flags.indexOf("h") >= 0;
            return true;
        });
    }
    readonly property real largest: listingOk && listing.items.length ? listing.items[0].size : 1

    readonly property var findings: {
        if (!scanOk)
            return [];
        return scan.findings.map((f, i) => Object.assign({
                order: i
            }, f)).filter(f => f.severity !== "meta").sort((a, b) => (severityRank[a.severity] - severityRank[b.severity]) || (a.order - b.order));
    }
    function countOf(severity) {
        return findings.filter(f => f.severity === severity).length;
    }
    readonly property var shownFindings: showMinor ? findings : findings.filter(f => severityRank[f.severity] <= 1)
    readonly property int minorCount: findings.length - findings.filter(f => severityRank[f.severity] <= 1).length

    function tagsFor(item) {
        const tags = [];
        if (isBound(item))
            tags.push({
                text: qsTr("In your config"),
                tone: UI.Theme.positive
            });
        if (item.kind === "l")
            tags.push(item.link.indexOf("/nix/store/") === 0 ? {
                text: qsTr("Nix-managed"),
                tone: UI.Theme.positive
            } : {
                text: qsTr("Link"),
                tone: "#93a5be"
            });
        if (item.flags.indexOf("s") >= 0)
            tags.push({
                text: qsTr("Setuid"),
                tone: UI.Theme.negative
            });
        if (item.flags.indexOf("c") >= 0)
            tags.push({
                text: qsTr("Odd name"),
                tone: UI.Theme.negative
            });
        if (item.flags.indexOf("x") >= 0)
            tags.push({
                text: qsTr("Program"),
                tone: UI.Theme.changed
            });
        if (item.flags.indexOf("w") >= 0)
            tags.push({
                text: qsTr("Anyone can write"),
                tone: UI.Theme.changed
            });
        if (ageDays(item.newest) > staleDays)
            tags.push({
                text: qsTr("Untouched"),
                tone: UI.Theme.changed
            });
        return tags.slice(0, 3);
    }
    function isRisky(item) {
        return /[sc]/.test(item.flags);
    }

    // Open / copy / delete for a path, with the delete confirmed in place.
    component PathActions: RowLayout {
        id: actions
        property string path: ""
        property string name: ""
        property string pending: ""
        property bool canDelete: true
        property bool busy: false
        readonly property bool confirming: path !== "" && pending === path
        signal openClicked
        signal copyClicked
        signal deleteAsked
        signal deleteConfirmed
        signal deleteCancelled
        spacing: 2
        UI.ActionButton {
            visible: !actions.confirming
            glyph: Qt.resolvedUrl("assets/ic_external.svg")
            flatStyle: true
            implicitHeight: 23
            tip: qsTr("Show in file manager")
            onClicked: actions.openClicked()
        }
        UI.ActionButton {
            visible: !actions.confirming
            glyph: Qt.resolvedUrl("assets/ic_copy.svg")
            flatStyle: true
            implicitHeight: 23
            tip: qsTr("Copy path")
            onClicked: actions.copyClicked()
        }
        UI.ActionButton {
            visible: !actions.confirming && actions.canDelete
            enabled: !actions.busy
            glyph: Qt.resolvedUrl("assets/ic_delete.svg")
            flatStyle: true
            implicitHeight: 23
            tip: qsTr("Delete…")
            onClicked: actions.deleteAsked()
        }
        UI.ActionButton {
            visible: actions.confirming
            text: qsTr("Delete for good")
            primary: true
            accent: UI.Theme.negative
            implicitHeight: 25
            font.pixelSize: 10
            enabled: !actions.busy
            onClicked: actions.deleteConfirmed()
        }
        UI.ActionButton {
            visible: actions.confirming
            text: qsTr("Cancel")
            flatStyle: true
            implicitHeight: 25
            font.pixelSize: 10
            onClicked: actions.deleteCancelled()
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 9

            // ── What survives a reboot ────────────────────────────────
            SectionIntro {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                title: qsTr("What survives a reboot")
                subtitle: tab.impermanence.volatile ? (tab.impermanence.volatileWhy === "tmpfs" ? qsTr("Your root lives in memory and starts empty on every boot. Only the folders below keep their files.") : qsTr("Your root is recreated on every boot. Only the folders below keep their files.")) : qsTr("These folders are kept across reboots.")
                textColor: tab.textColor
                fs: tab.fs
                Tag {
                    text: qsTr("%n place(s)", "", tab.impermanence.areas.length)
                    tone: UI.Theme.positive
                    fs: tab.fs
                }
            }
            Repeater {
                model: tab.impermanence.areas
                Rectangle {
                    id: area
                    required property var modelData
                    readonly property real usedShare: modelData.total > 0 ? modelData.used / modelData.total : 0
                    Layout.fillWidth: true
                    implicitHeight: areaColumn.implicitHeight + 20
                    radius: 9
                    color: "#03ffffff"
                    border.color: "#0effffff"
                    ColumnLayout {
                        id: areaColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 7
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            UI.Icon {
                                source: Qt.resolvedUrl("assets/ic_disk.svg")
                                isMask: true
                                color: area.modelData.kind === "persist" ? tab.accentColor : "#93a5be"
                                implicitWidth: 15
                                implicitHeight: 15
                            }
                            Text {
                                Layout.fillWidth: true
                                text: area.modelData.path
                                textFormat: Text.PlainText
                                color: tab.textColor
                                font.family: UI.Theme.fixedWidthFont.family
                                font.pixelSize: UI.Theme.fontPx(10, tab.fs)
                                elide: Text.ElideMiddle
                            }
                            Tag {
                                text: area.modelData.kind === "persist" ? (area.modelData.binds > 0 ? qsTr("%n entry(ies) from your config", "", area.modelData.binds) : qsTr("Persistent storage")) : qsTr("Separate disk")
                                tone: area.modelData.kind === "persist" ? tab.accentColor : "#93a5be"
                                fs: tab.fs
                            }
                            UI.ActionButton {
                                text: qsTr("Browse")
                                flatStyle: true
                                implicitHeight: 23
                                font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                                onClicked: tab.browse(area.modelData.path)
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            visible: area.modelData.total > 0
                            implicitHeight: 4
                            radius: 2
                            color: "#10ffffff"
                            Rectangle {
                                width: parent.width * Math.min(1, area.usedShare)
                                height: parent.height
                                radius: 2
                                color: area.usedShare > 0.9 ? UI.Theme.negative : area.usedShare > 0.75 ? UI.Theme.changed : tab.accentColor
                            }
                        }
                        Text {
                            visible: area.modelData.total > 0
                            text: qsTr("%1 of %2 used · %3 free · %4").arg(UI.Theme.formatBytes(area.modelData.used)).arg(UI.Theme.formatBytes(area.modelData.total)).arg(UI.Theme.formatBytes(area.modelData.avail)).arg(area.modelData.fsType)
                            textFormat: Text.PlainText
                            color: "#8293ab"
                            font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                        }
                    }
                }
            }

            // ── View switch ───────────────────────────────────────────
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 5
                Repeater {
                    model: [
                        {
                            id: "browse",
                            label: qsTr("Browse"),
                            tip: qsTr("Walk through the folders that are kept")
                        },
                        {
                            id: "security",
                            label: qsTr("Security"),
                            tip: qsTr("Autostart hooks and unusual files")
                        },
                        {
                            id: "cleanup",
                            label: qsTr("Cleanup"),
                            tip: qsTr("Caches, leftovers and forgotten folders")
                        }
                    ]
                    UI.ActionButton {
                        required property var modelData
                        objectName: "impermanenceLens-" + modelData.id
                        text: modelData.label
                        tip: modelData.tip
                        accent: tab.accentColor
                        primary: tab.lens === modelData.id
                        flatStyle: tab.lens !== modelData.id
                        implicitHeight: 25 * tab.fs
                        font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                        onClicked: tab.setLens(modelData.id)
                    }
                }
            }

            // ── Browse ────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: tab.lens === "browse"
                spacing: 9

                Flow {
                    Layout.fillWidth: true
                    visible: tab.crumbs.length > 0
                    spacing: 2
                    Repeater {
                        model: tab.crumbs
                        RowLayout {
                            id: crumb
                            required property var modelData
                            required property int index
                            spacing: 2
                            Text {
                                visible: crumb.index > 0
                                text: "›"
                                color: "#6f7f96"
                                font.pixelSize: UI.Theme.fontPx(11, tab.fs)
                            }
                            UI.ActionButton {
                                text: crumb.modelData.label
                                flatStyle: crumb.index < tab.crumbs.length - 1
                                primary: crumb.index === tab.crumbs.length - 1
                                accent: tab.accentColor
                                implicitHeight: 23
                                font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                                onClicked: tab.browse(crumb.modelData.path)
                            }
                        }
                    }
                }

                Notice {
                    Layout.fillWidth: true
                    visible: !!tab.listing && tab.listing.isError
                    glyph: "ic_warning"
                    tone: UI.Theme.negative
                    emphasis: true
                    fs: tab.fs
                    text: tab.listing && tab.listing.isError ? String(tab.listing.value).replace(/^ERROR:\s*/, "") : ""
                }
                Notice {
                    Layout.fillWidth: true
                    visible: tab.isListing && !tab.listing
                    fs: tab.fs
                    text: qsTr("Measuring this folder…")
                }

                // How the folder is made up
                Rectangle {
                    id: stripBox
                    Layout.fillWidth: true
                    visible: tab.strip.length > 0
                    implicitHeight: stripColumn.implicitHeight + 20
                    radius: 9
                    color: "#03ffffff"
                    border.color: "#0effffff"
                    opacity: tab.isListing ? 0.55 : 1
                    ColumnLayout {
                        id: stripColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: tab.listingOk ? qsTr("%1 in %2").arg(UI.Theme.formatBytes(tab.listing.total) || "0 B").arg(tab.listing.files === 1 ? qsTr("1 file") : qsTr("%1 files").arg(tab.listing.files)) : ""
                                textFormat: Text.PlainText
                                color: tab.textColor
                                font.pixelSize: UI.Theme.fontPx(11, tab.fs)
                                font.weight: Font.Medium
                            }
                            Text {
                                text: tab.listingOk ? qsTr("last change %1").arg(tab.ago(tab.listing.newest)) : ""
                                color: "#8293ab"
                                font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                            }
                        }
                        Row {
                            id: stripRow
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            spacing: 2
                            Repeater {
                                model: tab.strip
                                Rectangle {
                                    id: segment
                                    required property var modelData
                                    width: Math.max(3, (stripRow.width - (tab.strip.length - 1) * stripRow.spacing) * modelData.size / tab.listing.total)
                                    height: stripRow.height
                                    radius: 3
                                    color: modelData.color
                                    opacity: segmentHover.hovered ? 1 : 0.85
                                    HoverHandler {
                                        id: segmentHover
                                    }
                                    ToolTip.visible: segmentHover.hovered
                                    ToolTip.text: modelData.name + " · " + UI.Theme.formatBytes(modelData.size)
                                    ToolTip.delay: 200
                                }
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 12
                            Repeater {
                                model: tab.strip.slice(0, 5)
                                RowLayout {
                                    id: legend
                                    required property var modelData
                                    spacing: 5
                                    Rectangle {
                                        implicitWidth: 7
                                        implicitHeight: 7
                                        radius: 4
                                        color: legend.modelData.color
                                    }
                                    Text {
                                        text: legend.modelData.name + "  " + UI.Theme.formatBytes(legend.modelData.size)
                                        textFormat: Text.PlainText
                                        color: "#9aa9bf"
                                        font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                                    }
                                }
                            }
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    visible: tab.listingOk && tab.listing.items.length > 0
                    spacing: 5
                    Repeater {
                        model: [
                            {
                                id: "all",
                                label: qsTr("Everything")
                            },
                            {
                                id: "stale",
                                label: qsTr("Untouched for %n day(s)", "", tab.staleDays)
                            },
                            {
                                id: "risky",
                                label: qsTr("Looks risky")
                            },
                            {
                                id: "hidden",
                                label: qsTr("Hidden")
                            }
                        ]
                        UI.ActionButton {
                            required property var modelData
                            objectName: "impermanenceFilter-" + modelData.id
                            text: modelData.label
                            accent: tab.accentColor
                            primary: tab.filter === modelData.id
                            flatStyle: tab.filter !== modelData.id
                            implicitHeight: 23
                            font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                            onClicked: tab.filter = modelData.id
                        }
                    }
                }

                Repeater {
                    model: tab.shownItems
                    Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool isDir: modelData.kind === "d"
                        readonly property bool bound: tab.isBound(modelData)
                        readonly property bool stale: tab.ageDays(modelData.newest) > tab.staleDays
                        Layout.fillWidth: true
                        implicitHeight: rowContent.implicitHeight + 20
                        radius: 9
                        color: rowMouse.containsMouse && isDir ? "#07ffffff" : "#03ffffff"
                        border.color: tab.pendingPath === modelData.path ? Qt.alpha(UI.Theme.negative, 0.5) : "#0effffff"
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            enabled: row.isDir
                            hoverEnabled: true
                            cursorShape: row.isDir ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: tab.browse(row.modelData.path)
                        }
                        RowLayout {
                            id: rowContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 10
                            Rectangle {
                                implicitWidth: 31
                                implicitHeight: 31
                                radius: 8
                                color: "#04ffffff"
                                border.color: "#0effffff"
                                UI.Icon {
                                    anchors.centerIn: parent
                                    width: 15
                                    height: 15
                                    source: Qt.resolvedUrl("assets/" + (row.isDir ? "ic_folder" : "ic_outline_box") + ".svg")
                                    isMask: true
                                    color: tab.isRisky(row.modelData) ? UI.Theme.negative : row.stale ? UI.Theme.changed : row.isDir ? tab.accentColor : "#93a5be"
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.label
                                        textFormat: Text.PlainText
                                        color: tab.textColor
                                        font.pixelSize: UI.Theme.fontPx(11, tab.fs)
                                        font.weight: Font.Medium
                                        elide: Text.ElideMiddle
                                    }
                                    Repeater {
                                        model: tab.tagsFor(row.modelData)
                                        Tag {
                                            required property var modelData
                                            text: modelData.text
                                            tone: modelData.tone
                                            fs: tab.fs
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: (row.isDir ? tab.itemCount(row.modelData.count) + " · " : "") + qsTr("changed %1").arg(tab.ago(row.modelData.newest)) + " · " + row.modelData.owner + (row.modelData.link ? " · → " + row.modelData.link : "")
                                    textFormat: Text.PlainText
                                    color: row.stale ? UI.Theme.changed : "#8293ab"
                                    font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                                    elide: Text.ElideMiddle
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 3
                                    radius: 2
                                    color: "#0cffffff"
                                    Rectangle {
                                        width: Math.max(2, parent.width * row.modelData.size / tab.largest)
                                        height: parent.height
                                        radius: 2
                                        color: row.stale ? UI.Theme.changed : tab.accentColor
                                        opacity: 0.6
                                    }
                                }
                            }
                            Text {
                                Layout.alignment: Qt.AlignTop
                                text: UI.Theme.formatBytes(row.modelData.size) || "—"
                                color: tab.textColor
                                font.pixelSize: UI.Theme.fontPx(10, tab.fs)
                            }
                            PathActions {
                                Layout.alignment: Qt.AlignTop
                                path: row.modelData.path
                                name: row.modelData.name
                                pending: tab.pendingPath
                                canDelete: !row.bound
                                busy: tab.isRemoving
                                onOpenClicked: tab.openRequested(path)
                                onCopyClicked: tab.copyToClipboard(tab.plain(path))
                                onDeleteAsked: tab.pendingPath = path
                                onDeleteConfirmed: {
                                    tab.pendingPath = "";
                                    tab.removeRequested(path, name);
                                }
                                onDeleteCancelled: tab.pendingPath = ""
                            }
                        }
                    }
                }
                Notice {
                    Layout.fillWidth: true
                    visible: tab.listingOk && tab.shownItems.length === 0
                    fs: tab.fs
                    text: tab.listing && tab.listing.items.length === 0 ? qsTr("This folder is empty.") : qsTr("Nothing in this folder matches the filter.")
                }
                Notice {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    fs: tab.fs
                    text: qsTr("Sizes are what the files take on disk. Entries marked “In your config” are bound into the running system by your configuration and cannot be deleted here; delete what is inside them instead.")
                }
            }

            // ── Security ──────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: tab.lens === "security"
                spacing: 9

                Text {
                    Layout.fillWidth: true
                    text: qsTr("A reboot wipes everything outside these folders, so anything planted by malware has to live here to come back. This looks for what starts by itself, files that should not be programs, and names made to hide. It is a quick check, not an antivirus.")
                    color: "#9bacc4"
                    font.pixelSize: UI.Theme.fontPx(10, tab.fs)
                    wrapMode: Text.Wrap
                    lineHeight: 1.5
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Tag {
                        visible: tab.scanOk
                        text: qsTr("%n to check", "", tab.countOf("high"))
                        tone: tab.countOf("high") > 0 ? UI.Theme.negative : UI.Theme.positive
                        fs: tab.fs
                    }
                    Tag {
                        visible: tab.scanOk && tab.countOf("medium") > 0
                        text: qsTr("%n to review", "", tab.countOf("medium"))
                        tone: UI.Theme.changed
                        fs: tab.fs
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    UI.ActionButton {
                        objectName: "impermanenceRescan"
                        text: tab.isScanning ? qsTr("Scanning…") : qsTr("Scan again")
                        glyph: Qt.resolvedUrl("assets/ic_refresh.svg")
                        flatStyle: true
                        implicitHeight: 25
                        font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                        enabled: !tab.isScanning
                        onClicked: tab.scanRequested(true)
                    }
                    UI.ActionButton {
                        visible: tab.scanOk && !!tab.scan && tab.scan.clamav
                        text: qsTr("Deep scan with ClamAV")
                        glyph: Qt.resolvedUrl("assets/ic_terminal.svg")
                        primary: true
                        accent: tab.accentColor
                        implicitHeight: 25
                        font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                        onClicked: tab.clamScanRequested()
                    }
                }
                Notice {
                    Layout.fillWidth: true
                    visible: !!tab.scan && tab.scan.isError
                    glyph: "ic_warning"
                    tone: UI.Theme.negative
                    emphasis: true
                    fs: tab.fs
                    text: tab.scan && tab.scan.isError ? String(tab.scan.value).replace(/^ERROR:\s*/, "") : ""
                }
                Notice {
                    Layout.fillWidth: true
                    visible: tab.isScanning && !tab.scan
                    fs: tab.fs
                    text: qsTr("Scanning the persistent folders…")
                }
                Notice {
                    Layout.fillWidth: true
                    visible: tab.scanOk && tab.findings.length === 0
                    glyph: "ic_check"
                    tone: UI.Theme.positive
                    emphasis: true
                    fs: tab.fs
                    text: qsTr("Nothing unusual found.")
                }
                Repeater {
                    model: tab.shownFindings
                    ToolRow {
                        id: finding
                        required property var modelData
                        Layout.fillWidth: true
                        expanded: true
                        glyph: modelData.severity === "high" || modelData.severity === "medium" ? "ic_warning" : "ic_info"
                        iconColor: tab.severityTone(modelData.severity)
                        title: modelData.category
                        detail: modelData.path
                        textColor: tab.textColor
                        fs: tab.fs
                        Tag {
                            text: tab.severityLabel(finding.modelData.severity)
                            tone: tab.severityTone(finding.modelData.severity)
                            fs: tab.fs
                        }
                        details: [
                            Text {
                                Layout.fillWidth: true
                                text: finding.modelData.detail
                                textFormat: Text.PlainText
                                color: "#9bacc4"
                                font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                                wrapMode: Text.Wrap
                                lineHeight: 1.4
                            },
                            PathActions {
                                visible: finding.modelData.path !== ""
                                path: finding.modelData.path
                                name: tab.baseName(finding.modelData.path)
                                pending: tab.pendingPath
                                busy: tab.isRemoving
                                onOpenClicked: tab.openRequested(path)
                                onCopyClicked: tab.copyToClipboard(tab.plain(path))
                                onDeleteAsked: tab.pendingPath = path
                                onDeleteConfirmed: {
                                    tab.pendingPath = "";
                                    tab.removeRequested(path, name);
                                }
                                onDeleteCancelled: tab.pendingPath = ""
                            }
                        ]
                    }
                }
                UI.ActionButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: tab.minorCount > 0
                    text: tab.showMinor ? qsTr("Hide notes") : qsTr("Show %n more note(s)", "", tab.minorCount)
                    flatStyle: true
                    implicitHeight: 25
                    font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                    onClicked: tab.showMinor = !tab.showMinor
                }
                Notice {
                    Layout.fillWidth: true
                    visible: tab.scanOk && !!tab.scan && !tab.scan.clamav
                    fs: tab.fs
                    text: qsTr("For signature-based scanning, install ClamAV (for example pkgs.clamav) and update its database with freshclam. A deep-scan button appears here once it is available.")
                }
                Notice {
                    Layout.fillWidth: true
                    visible: tab.scanOk
                    fs: tab.fs
                    text: qsTr("Files that link into the Nix store come from your configuration and are skipped. Container images, game libraries and caches are not inspected. Key material is never read.")
                }
            }

            // ── Cleanup ───────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: tab.lens === "cleanup"
                spacing: 9

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Nothing here is wiped on its own. Caches and leftovers can be rebuilt; forgotten folders are only a suggestion, so look before you delete.")
                    color: "#9bacc4"
                    font.pixelSize: UI.Theme.fontPx(10, tab.fs)
                    wrapMode: Text.Wrap
                    lineHeight: 1.5
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Tag {
                        visible: tab.cleanupOk
                        text: qsTr("%1 regenerable").arg(UI.Theme.formatBytes((tab.cleanup && tab.cleanup.temp ? tab.cleanup.temp : []).reduce((sum, t) => sum + t.size, 0)) || "0 B")
                        tone: UI.Theme.positive
                        fs: tab.fs
                    }
                    Tag {
                        visible: tab.cleanupOk
                        text: qsTr("%1 untouched").arg(UI.Theme.formatBytes((tab.cleanup && tab.cleanup.stale ? tab.cleanup.stale : []).reduce((sum, t) => sum + t.size, 0)) || "0 B")
                        tone: UI.Theme.changed
                        fs: tab.fs
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    UI.ActionButton {
                        objectName: "impermanenceReanalyze"
                        text: tab.isAnalyzing ? qsTr("Analyzing…") : qsTr("Analyze again")
                        glyph: Qt.resolvedUrl("assets/ic_refresh.svg")
                        flatStyle: true
                        implicitHeight: 25
                        font.pixelSize: UI.Theme.fontPx(9, tab.fs)
                        enabled: !tab.isAnalyzing
                        onClicked: tab.analyzeRequested(true)
                    }
                }
                Notice {
                    Layout.fillWidth: true
                    visible: !!tab.cleanup && tab.cleanup.isError
                    glyph: "ic_warning"
                    tone: UI.Theme.negative
                    emphasis: true
                    fs: tab.fs
                    text: tab.cleanup && tab.cleanup.isError ? String(tab.cleanup.value).replace(/^ERROR:\s*/, "") : ""
                }
                Notice {
                    Layout.fillWidth: true
                    visible: tab.isAnalyzing && !tab.cleanup
                    fs: tab.fs
                    text: qsTr("Measuring the persistent folders. This can take a while on large disks.")
                }

                Subheading {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    visible: tab.cleanupOk && !!tab.cleanup && !!tab.cleanup.temp && tab.cleanup.temp.length > 0
                    text: qsTr("Caches and leftovers")
                    detail: tab.cleanupOk && !!tab.cleanup && !!tab.cleanup.temp ? String(tab.cleanup.temp.length) : ""
                    fs: tab.fs
                }
                Repeater {
                    model: tab.cleanupOk && !!tab.cleanup && !!tab.cleanup.temp ? tab.cleanup.temp.slice(0, 60) : []
                    ToolRow {
                        id: tempRow
                        required property var modelData
                        Layout.fillWidth: true
                        glyph: "ic_clock"
                        iconColor: UI.Theme.positive
                        title: tab.baseName(modelData.path)
                        detail: modelData.path
                        textColor: tab.textColor
                        fs: tab.fs
                        Tag {
                            text: tempRow.modelData.label
                            tone: "#93a5be"
                            fs: tab.fs
                        }
                        Text {
                            text: UI.Theme.formatBytes(tempRow.modelData.size) || "—"
                            color: tab.textColor
                            font.pixelSize: UI.Theme.fontPx(10, tab.fs)
                        }
                        PathActions {
                            path: tempRow.modelData.path
                            name: tab.baseName(tempRow.modelData.path)
                            pending: tab.pendingPath
                            busy: tab.isRemoving
                            onOpenClicked: tab.openRequested(path)
                            onCopyClicked: tab.copyToClipboard(tab.plain(path))
                            onDeleteAsked: tab.pendingPath = path
                            onDeleteConfirmed: {
                                tab.pendingPath = "";
                                tab.removeRequested(path, name);
                            }
                            onDeleteCancelled: tab.pendingPath = ""
                        }
                    }
                }

                Subheading {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    visible: tab.cleanupOk && !!tab.cleanup && !!tab.cleanup.stale && tab.cleanup.stale.length > 0
                    text: qsTr("Untouched for %n day(s)", "", tab.staleDays)
                    detail: tab.cleanupOk && !!tab.cleanup && !!tab.cleanup.stale ? String(tab.cleanup.stale.length) : ""
                    fs: tab.fs
                }
                Repeater {
                    model: tab.cleanupOk && !!tab.cleanup && !!tab.cleanup.stale ? tab.cleanup.stale.slice(0, 60) : []
                    ToolRow {
                        id: staleRow
                        required property var modelData
                        Layout.fillWidth: true
                        glyph: staleRow.modelData.kind === "d" ? "ic_folder" : "ic_outline_box"
                        iconColor: UI.Theme.changed
                        title: tab.baseName(modelData.path)
                        detail: modelData.path
                        textColor: tab.textColor
                        fs: tab.fs
                        Tag {
                            text: tab.ago(staleRow.modelData.newest)
                            tone: UI.Theme.changed
                            fs: tab.fs
                        }
                        Text {
                            text: UI.Theme.formatBytes(staleRow.modelData.size) || "—"
                            color: tab.textColor
                            font.pixelSize: UI.Theme.fontPx(10, tab.fs)
                        }
                        PathActions {
                            path: staleRow.modelData.path
                            name: tab.baseName(staleRow.modelData.path)
                            pending: tab.pendingPath
                            busy: tab.isRemoving
                            onOpenClicked: tab.openRequested(path)
                            onCopyClicked: tab.copyToClipboard(tab.plain(path))
                            onDeleteAsked: tab.pendingPath = path
                            onDeleteConfirmed: {
                                tab.pendingPath = "";
                                tab.removeRequested(path, name);
                            }
                            onDeleteCancelled: tab.pendingPath = ""
                        }
                    }
                }
                Notice {
                    Layout.fillWidth: true
                    visible: tab.cleanupOk && !!tab.cleanup && !!tab.cleanup.temp && !!tab.cleanup.stale && tab.cleanup.temp.length === 0 && tab.cleanup.stale.length === 0
                    glyph: "ic_check"
                    tone: UI.Theme.positive
                    emphasis: true
                    fs: tab.fs
                    text: qsTr("Nothing to clean up.")
                }
                Notice {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    visible: tab.cleanupOk
                    fs: tab.fs
                    text: qsTr("Folders count as untouched when no file inside changed for %n day(s). Keys, the SSH and GnuPG folders and anything your configuration binds into the system are never offered.", "", tab.staleDays)
                }
            }
        }
    }
}
