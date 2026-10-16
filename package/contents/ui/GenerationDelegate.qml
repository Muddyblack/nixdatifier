import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "shared" as UI
import "components"

Item {
    id: genDelegate
    property var storePathCache: ({})
    property var changeCounts: null
    property date referenceDate: new Date()
    signal storePathRequested(var pkg)

    property var gen: ({})
    // See FullView.uiActive — false while the popup is closed.
    property bool uiActive: true
    property color accentColor: "transparent"
    property color timelineColor: "transparent"
    property color textColor: "white"
    property real fs: 1.0
    property int selectedGenNum: -1
    property bool isLoadingDetails: false
    property bool isBusy: false
    property var detailsCache: ({})
    property string diffMode: "booted"
    property bool showDeleteButton: false
    property bool diffFilterEnabled: true
    property int bootedGenNum: -1
    property var iconCache: ({})
    property var metaCache: ({})
    property bool showPackageIcons: true
    property string iconStyle: "colored"
    property bool enableLiveSwitch: true
    property bool enableGlow: true
    property bool enableMotion: true
    property string diffViewMode: "compact"
    signal geometryChanged
    // Full generations list, used to populate the right-click "Compare with…" menu.
    property var allGenerations: []
    property var configDiffCache: ({})

    signal selectGen(int genNum)
    signal collapseGen
    signal requestAction(int genNum, string action)
    signal diffModeToggle(int genNum)
    signal copyToClipboard(string text)
    signal compareWithRequested(int genA, int genB)

    function svg(name) {
        return Qt.resolvedUrl("assets/" + name + ".svg");
    }

    function fpx(n) {
        return UI.Theme.fontPx(n, fs);
    }

    function friendlyTimestamp(value, now) {
        const m = String(value || "").match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/);
        if (!m)
            return value || "";
        const date = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]));
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const yesterday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1);
        const time = Qt.formatTime(date, "hh:mm");
        if (date >= today && date < new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1))
            return qsTr("Today, %1").arg(time);
        if (date >= yesterday && date < today)
            return qsTr("Yesterday, %1").arg(time);
        return Qt.formatDateTime(date, date.getFullYear() === now.getFullYear() ? "dd MMM, hh:mm" : "dd MMM yyyy, hh:mm");
    }

    readonly property bool isExpanded: gen.number === selectedGenNum
    readonly property var details: detailsCache[gen.number] || ({})
    // Parse a size string like "+45.6 MiB" or "-12 KiB" into bytes.
    function parseSizeStr(s) {
        if (!s)
            return 0;
        const m = s.trim().match(/^([+-]?\d[\d.,]*)\s*(B|KB?|KiB|MB?|MiB|GB?|GiB|TB?|TiB)?$/i);
        if (!m)
            return 0;
        const num = parseFloat(m[1].replace(/,/g, ""));
        const unit = (m[2] || "B").toUpperCase();
        const mult = ({
                "B": 1,
                "K": 1024,
                "KB": 1024,
                "KIB": 1024,
                "M": 1048576,
                "MB": 1048576,
                "MIB": 1048576,
                "G": 1073741824,
                "GB": 1073741824,
                "GIB": 1073741824,
                "T": 1099511627776,
                "TB": 1099511627776,
                "TIB": 1099511627776
            });
        return Math.round(num * (mult[unit] || 1));
    }

    readonly property var changeSummary: {
        if (changeCounts && changeCounts.status === "ok")
            return changeCounts;
        if (details.partial || !Array.isArray(details.diff) || (details.diffMode === "booted" && !gen.booted))
            return null;
        const added = details.diff.filter(p => p.type === "added");
        const removed = details.diff.filter(p => p.type === "removed");
        const addedBytes = added.reduce((acc, p) => acc + Math.max(0, parseSizeStr(p.size)), 0);
        const removedBytes = removed.reduce((acc, p) => acc + Math.max(0, -parseSizeStr(p.size)), 0);
        return {
            added: added.length,
            removed: removed.length,
            changed: details.diff.filter(p => p.type !== "added" && p.type !== "removed").length,
            addedBytes: addedBytes,
            removedBytes: removedBytes
        };
    }

    readonly property var changeBadgeModel: {
        if (!changeSummary)
            return [];
        const s = changeSummary;
        const hasBytes = s.addedBytes > 0 || s.removedBytes > 0;
        return [
            {
                text: "+" + (hasBytes && s.addedBytes > 0 ? UI.Theme.formatBytes(s.addedBytes) : s.added),
                color: UI.Theme.positive
            },
            {
                text: "−" + (hasBytes && s.removedBytes > 0 ? UI.Theme.formatBytes(s.removedBytes) : s.removed),
                color: UI.Theme.negative
            },
            {
                text: "~" + s.changed,
                color: UI.Theme.changed
            }
        ];
    }

    readonly property string changeTip: {
        if (!changeSummary)
            return qsTr("Package counts are not available yet");
        const s = changeSummary;
        const hasBytes = s.addedBytes > 0 || s.removedBytes > 0;
        let tip = qsTr("Changes from the previous generation: %1 added, %2 removed, %3 changed").arg(s.added).arg(s.removed).arg(s.changed);
        if (hasBytes)
            tip += "\n" + qsTr("+%1 / −%2 store size").arg(UI.Theme.formatBytes(s.addedBytes) || "0 B").arg(UI.Theme.formatBytes(s.removedBytes) || "0 B");
        return tip;
    }

    readonly property var configDiff: configDiffCache[gen.number] || ({})
    readonly property real headerH: Math.max(80 * fs, headerContents.implicitHeight + 16 * fs)
    readonly property bool compactActions: generationHeader.width < 420 * fs
    readonly property real nodeX: 14
    readonly property real nodeY: 8 * fs + headerTopRow.height / 2
    readonly property string kernelLabel: {
        const value = details.kernelVer || "";
        if (!value)
            return "";
        const version = value.match(/(\d+\.\d+(?:\.\d+)?(?:[-+][^\s]*)?)$/);
        if (/cachyos/i.test(value))
            return "CachyOS" + (version ? " " + version[1] : "");
        return version ? "Linux " + version[1] : value;
    }
    readonly property string releaseLabel: {
        const value = details.nixosVer || "";
        if (!value)
            return "";
        const release = value.match(/^\d{2}\.\d{2}/);
        const date = value.match(/(\d{4})-?(\d{2})-?(\d{2})/);
        const day = date ? Qt.formatDate(new Date(Number(date[1]), Number(date[2]) - 1, Number(date[3])), "dd MMM") : "";
        return "NixOS " + (release ? release[0] : value) + (release && day ? " · " + day : "");
    }
    readonly property color statusColor: gen.booted ? UI.Theme.positive : gen.active ? UI.Theme.changed : timelineColor
    implicitHeight: detailWindow.visible ? headerH : generationContent.implicitHeight
    height: implicitHeight
    onHeightChanged: geometryChanged()
    onYChanged: geometryChanged()
    Item {
        id: generationContent
        width: genDelegate.width
        implicitHeight: genDelegate.headerH + (genDelegate.isExpanded ? expandedColumn.implicitHeight + 20 : 0)
        height: implicitHeight
        Rectangle {
            x: genDelegate.nodeX - 4
            y: genDelegate.nodeY - 4
            width: 8
            height: 8
            radius: 4
            color: genDelegate.statusColor
            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 9
                color: "transparent"
                border.color: UI.Theme.wash(genDelegate.statusColor, .65)
                visible: genDelegate.gen.booted && genDelegate.enableGlow
            }
        }
        Rectangle {
            x: 30
            width: Math.max(0, parent.width - 36)
            height: parent.height - 4
            radius: 10
            color: genDelegate.isExpanded ? UI.Theme.wash(genDelegate.accentColor, .055) : hover.hovered ? "#08ffffff" : "transparent"
            border.color: genDelegate.isExpanded ? UI.Theme.wash(genDelegate.accentColor, .2) : "transparent"
        }
        HoverHandler {
            id: hover
        }
        Item {
            id: generationHeader
            x: 39
            width: Math.max(0, parent.width - 50)
            height: genDelegate.headerH
            // Under the content so action buttons get their own clicks.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        generationMenu.popup();
                        return;
                    }
                    const p = mapToItem(headerActions, mouse.x, mouse.y);
                    if (headerActions.visible && p.x >= 0 && p.x <= headerActions.width && p.y >= 0 && p.y <= headerActions.height)
                        return;
                    if (genDelegate.isExpanded)
                        genDelegate.collapseGen();
                    else
                        genDelegate.selectGen(genDelegate.gen.number);
                }
            }
            ColumnLayout {
                id: headerContents
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 8 * genDelegate.fs
                spacing: 5 * genDelegate.fs
                RowLayout {
                    id: headerTopRow
                    Layout.fillWidth: true
                    spacing: 7
                    Text {
                        text: "#" + genDelegate.gen.number
                        color: genDelegate.gen.booted || genDelegate.gen.active ? genDelegate.statusColor : genDelegate.textColor
                        font.pixelSize: 12 * genDelegate.fs
                        font.weight: Font.Medium
                    }
                    Rectangle {
                        visible: genDelegate.gen.booted || genDelegate.gen.active
                        implicitWidth: statusLabel.implicitWidth + 12
                        implicitHeight: statusLabel.implicitHeight + 6
                        radius: 4
                        color: UI.Theme.wash(genDelegate.statusColor, .1)
                        Text {
                            id: statusLabel
                            anchors.centerIn: parent
                            text: genDelegate.gen.booted ? qsTr("Booted") : qsTr("Next boot")
                            color: genDelegate.statusColor
                            font.pixelSize: 9 * genDelegate.fs
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        id: headerActions
                        visible: genDelegate.isExpanded
                        spacing: 5
                        UI.ActionButton {
                            objectName: "activate-" + genDelegate.gen.number
                            visible: genDelegate.enableLiveSwitch
                            text: genDelegate.compactActions ? "" : qsTr("Activate")
                            glyph: genDelegate.svg("ic_activate")
                            tip: qsTr("Activate generation #%1 now").arg(genDelegate.gen.number)
                            primary: true
                            accent: genDelegate.accentColor
                            implicitHeight: 25 * genDelegate.fs
                            font.pixelSize: 9 * genDelegate.fs
                            enabled: !genDelegate.isBusy
                            onClicked: genDelegate.requestAction(genDelegate.gen.number, "switch")
                        }
                        UI.ActionButton {
                            objectName: "setBoot-" + genDelegate.gen.number
                            text: genDelegate.compactActions ? "" : qsTr("Set boot")
                            glyph: genDelegate.svg("ic_nextboot")
                            tip: qsTr("Use generation #%1 on next boot").arg(genDelegate.gen.number)
                            primary: true
                            accent: UI.Theme.changed
                            implicitHeight: 25 * genDelegate.fs
                            font.pixelSize: 9 * genDelegate.fs
                            enabled: !genDelegate.isBusy
                            onClicked: genDelegate.requestAction(genDelegate.gen.number, "rollback")
                        }
                        UI.ActionButton {
                            objectName: "delete-" + genDelegate.gen.number
                            visible: genDelegate.showDeleteButton
                            text: genDelegate.compactActions ? "" : qsTr("Delete")
                            glyph: genDelegate.svg("ic_delete")
                            tip: genDelegate.gen.active || genDelegate.gen.booted ? qsTr("The booted and next-boot generations are protected") : qsTr("Delete generation #%1").arg(genDelegate.gen.number)
                            primary: true
                            accent: UI.Theme.negative
                            implicitHeight: 25 * genDelegate.fs
                            font.pixelSize: 9 * genDelegate.fs
                            enabled: !genDelegate.isBusy && !genDelegate.gen.active && !genDelegate.gen.booted
                            onClicked: genDelegate.requestAction(genDelegate.gen.number, "delete")
                        }
                    }
                    Row {
                        objectName: "generationChanges-" + genDelegate.gen.number
                        visible: !genDelegate.isExpanded || generationHeader.width > 480 * genDelegate.fs
                        spacing: 6
                        Text {
                            visible: !genDelegate.changeSummary
                            text: genDelegate.changeCounts && genDelegate.changeCounts.status === "loading" ? "…" : "—"
                            color: UI.Theme.muted
                            font.pixelSize: 10 * genDelegate.fs
                        }
                        Repeater {
                            model: genDelegate.changeBadgeModel
                            Text {
                                required property var modelData
                                text: modelData.text
                                color: modelData.color
                                font.pixelSize: 9 * genDelegate.fs
                            }
                        }
                        HoverHandler {
                            id: countsHover
                        }
                        ToolTip.visible: countsHover.hovered
                        ToolTip.text: genDelegate.changeTip
                    }

                    UI.ActionButton {
                        objectName: "openGeneration-" + genDelegate.gen.number
                        visible: !detailWindow.visible
                        glyph: genDelegate.svg("ic_external")
                        tip: qsTr("Open in larger window")
                        implicitHeight: 25 * genDelegate.fs
                        onClicked: {
                            if (!genDelegate.isExpanded)
                                genDelegate.selectGen(genDelegate.gen.number);
                            detailWindow.open();
                        }
                    }
                    UI.DisclosureButton {
                        objectName: "toggleGeneration-" + genDelegate.gen.number
                        expanded: genDelegate.isExpanded
                        enableMotion: genDelegate.uiActive && genDelegate.enableMotion
                        implicitHeight: 25 * genDelegate.fs
                        tip: genDelegate.isExpanded ? qsTr("Collapse generation #%1").arg(genDelegate.gen.number) : qsTr("Expand generation #%1").arg(genDelegate.gen.number)
                        onClicked: genDelegate.isExpanded ? genDelegate.collapseGen() : genDelegate.selectGen(genDelegate.gen.number)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    objectName: "generationDate-" + genDelegate.gen.number
                    text: genDelegate.friendlyTimestamp(genDelegate.gen.timestamp, genDelegate.referenceDate)
                    color: UI.Theme.muted
                    font.pixelSize: 10 * genDelegate.fs
                    elide: Text.ElideRight
                    HoverHandler {
                        id: dateHover
                    }
                    ToolTip.visible: dateHover.hovered
                    ToolTip.text: genDelegate.gen.timestamp || ""
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: [
                            {
                                label: genDelegate.kernelLabel,
                                value: genDelegate.details.kernelVer || "",
                                kind: "kernel"
                            },
                            {
                                label: genDelegate.releaseLabel,
                                value: genDelegate.details.nixosVer || "",
                                kind: "nixos"
                            }
                        ]
                        Rectangle {
                            id: spec
                            required property var modelData
                            objectName: modelData.kind + "Badge-" + genDelegate.gen.number
                            visible: modelData.value !== ""
                            width: Math.min(generationHeader.width, specLabel.implicitWidth + 16)
                            height: 23 * genDelegate.fs
                            color: "#0991bcff"
                            border.color: "#1491bcff"
                            radius: 5
                            Text {
                                id: specLabel
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                text: spec.modelData.label
                                textFormat: Text.PlainText
                                color: "#c7d6e8"
                                font.pixelSize: 10 * genDelegate.fs
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            Accessible.role: Accessible.StaticText
                            Accessible.name: modelData.kind === "kernel" ? qsTr("Kernel: %1").arg(modelData.value) : "NixOS " + modelData.value
                            HoverHandler {
                                id: specHover
                            }
                            ToolTip.visible: specHover.hovered
                            ToolTip.text: modelData.value
                            ToolTip.delay: 450
                        }
                    }
                }
            }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Generation %1").arg(genDelegate.gen.number)
            Accessible.onPressAction: genDelegate.isExpanded ? genDelegate.collapseGen() : genDelegate.selectGen(genDelegate.gen.number)
        }
        ColumnLayout {
            id: expandedColumn
            x: 40
            y: genDelegate.headerH
            width: Math.max(0, parent.width - 52)
            visible: genDelegate.isExpanded
            spacing: 10
            Text {
                visible: genDelegate.isLoadingDetails && (!genDelegate.details.diff || !!genDelegate.details.partial)
                text: qsTr("Loading generation details…")
                color: genDelegate.accentColor
                font.pixelSize: genDelegate.fpx(9)
            }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: genDelegate.details.closureBytes ? qsTr("Closure size: %1").arg(UI.Theme.formatBytes(genDelegate.details.closureBytes)) : ""
                    color: UI.Theme.muted
                    font.pixelSize: genDelegate.fpx(8)
                }
                UI.ActionButton {
                    text: genDelegate.diffMode === "prev" ? qsTr("vs. previous") : qsTr("vs. booted")
                    tip: qsTr("Change comparison baseline")
                    onClicked: genDelegate.diffModeToggle(genDelegate.gen.number)
                }
            }
            PackageList {
                storePathCache: genDelegate.storePathCache
                onStorePathRequested: pkg => genDelegate.storePathRequested(pkg)
                Layout.fillWidth: true
                packages: genDelegate.details.diff || []
                iconCache: genDelegate.iconCache
                metaCache: genDelegate.metaCache
                showPackageIcons: genDelegate.showPackageIcons
                enableGlow: genDelegate.enableGlow
                filterEnabled: genDelegate.diffFilterEnabled
                textColor: genDelegate.textColor
                accentColor: genDelegate.accentColor
                fs: genDelegate.fs
                viewMode: genDelegate.diffViewMode
                onCopyToClipboard: text => genDelegate.copyToClipboard(text)
            }
            Disclosure {
                Layout.fillWidth: true
                visible: !!genDelegate.configDiff.status && genDelegate.configDiff.status !== "missing"
                title: qsTr("Configuration changes")
                TextEdit {
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.NoWrap
                    text: genDelegate.configDiff.diff || genDelegate.configDiff.message || qsTr("No configuration changes")
                    color: genDelegate.textColor
                    font.family: UI.Theme.fixedWidthFont.family
                    font.pixelSize: genDelegate.fpx(8)
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                UI.ActionButton {
                    text: qsTr("Compare with…")
                    glyph: genDelegate.svg("ic_diff")
                    primary: true
                    onClicked: compareMenu.popup()
                }
            }
        }
    }
    UI.DetailWindow {
        id: detailWindow
        objectName: "generationWindow-" + genDelegate.gen.number
        title: qsTr("Generation #%1 — Nixdatifier").arg(genDelegate.gen.number)
        detailItem: generationContent
    }
    Menu {
        id: generationMenu
        MenuItem {
            text: qsTr("Open in larger window")
            onTriggered: {
                genDelegate.selectGen(genDelegate.gen.number);
                detailWindow.open();
            }
        }
        MenuItem {
            text: qsTr("Activate now")
            visible: genDelegate.enableLiveSwitch
            height: visible ? implicitHeight : 0
            enabled: !genDelegate.isBusy
            onTriggered: genDelegate.requestAction(genDelegate.gen.number, "switch")
        }
        MenuItem {
            text: qsTr("Use on next boot")
            enabled: !genDelegate.isBusy
            onTriggered: genDelegate.requestAction(genDelegate.gen.number, "rollback")
        }
        MenuItem {
            text: qsTr("Delete generation")
            visible: genDelegate.showDeleteButton
            height: visible ? implicitHeight : 0
            enabled: !genDelegate.isBusy && !genDelegate.gen.active && !genDelegate.gen.booted
            onTriggered: genDelegate.requestAction(genDelegate.gen.number, "delete")
        }
        MenuItem {
            text: qsTr("Compare with…")
            onTriggered: compareMenu.popup()
        }
    }
    Menu {
        id: compareMenu
        Instantiator {
            model: genDelegate.allGenerations
            delegate: MenuItem {
                required property var modelData
                text: "#" + modelData.number
                enabled: modelData.number !== genDelegate.gen.number
                onTriggered: genDelegate.compareWithRequested(genDelegate.gen.number, modelData.number)
            }
            onObjectAdded: (index, object) => compareMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => compareMenu.removeItem(object)
        }
    }
}
