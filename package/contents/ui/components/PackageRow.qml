import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../shared" as UI

// Single expandable package diff row.
// Used in both GenerationDelegate (timeline) and the Diff tab.
Item {
    id: root
    objectName: "packageRow-" + pkgName

    property var storePathCache: ({})

    property var whyCache: ({})
    signal storePathRequested(var pkg)
    signal whyRequested(var pkg, bool all)
    readonly property string pathKey: (pkg.storeProfile || "") + "|" + pkgName + "|" + (pkgType === "removed" ? pkgOldVersion : pkgNewVersion)
    readonly property var pathResult: storePathCache[pathKey]
    // Same keys as Engine.whyKey
    readonly property var whyResult: whyCache[pathKey]
    readonly property var whyAllResult: whyCache[pathKey + "|all"]
    onIsOpenChanged: if (isOpen && pkg.storeProfile && !pathResult)
        storePathRequested(pkg)
    property var pkg: ({})     // { name, type, oldVersion, newVersion, size }
    property color accentColor: "transparent"
    property color textColor: "white"
    property real fs: 1.0

    // When true the detail panel is always open (detailed mode);
    // when false the user toggles it by clicking the row (compact mode).
    property bool forceExpanded: false
    property var iconCache: ({})
    property var metaCache: ({})
    property bool showPackageIcons: true
    property bool enableGlow: true

    signal copyRequested(string text)

    function fpx(n) {
        return UI.Theme.fontPx(n, fs);
    }
    property bool alternate: false
    readonly property real rowHeight: 32 * fs

    readonly property string resolvedIcon: {
        if (!showPackageIcons || !pkgName)
            return "";
        const ic = iconCache[pkgName];
        return (ic !== undefined && ic !== "") ? ic : "";
    }

    // ── Internal ──────────────────────────────────────────────────────────────
    property bool _userExpanded: false
    readonly property bool isOpen: forceExpanded || _userExpanded

    // Safe accessors — guard against the brief window where pkg is ({})
    readonly property string pkgName: pkg ? (pkg.name || "") : ""
    readonly property string pkgType: pkg ? (pkg.type || "") : ""
    readonly property string pkgOldVersion: pkg ? (pkg.oldVersion || "") : ""
    readonly property string pkgNewVersion: pkg ? (pkg.newVersion || "") : ""
    readonly property string pkgSize: pkg ? (pkg.size || "").replace(/KiB/g, "KB").replace(/MiB/g, "MB").replace(/GiB/g, "GB") : ""

    function svg(name) {
        return Qt.resolvedUrl("../assets/" + name + ".svg");
    }

    property color sigil: pkg && pkg.type === "added" ? UI.Theme.positive : pkg && pkg.type === "removed" ? UI.Theme.negative : UI.Theme.changed

    height: isOpen ? rowHeight + detailPanel.implicitHeight + 8 : rowHeight
    Behavior on height {
        NumberAnimation {
            duration: 170
            easing.type: Easing.InOutQuad
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.isOpen ? UI.Theme.wash(root.sigil, .045) : root.alternate ? "#03ffffff" : "transparent"
        Rectangle {
            width: 2
            height: parent.height
            color: root.sigil
            visible: root.isOpen
            opacity: .95
            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: parent.height
                color: root.sigil
                opacity: .08
                visible: root.enableGlow
            }
        }
    }

    // ── Compact row ───────────────────────────────────────────────────────────
    Rectangle {
        id: rowBg
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: root.rowHeight
        radius: 3
        color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 80
            }
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 5
                rightMargin: 5
            }
            spacing: 5

            // Sigil +/−/~
            Text {
                text: root.pkgType === "added" ? "+" : (root.pkgType === "removed" ? "−" : "~")
                color: root.sigil
                font.pixelSize: root.fpx(11)
                font.bold: true
                Layout.minimumWidth: 12
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: UI.Theme.wash(root.sigil, .07)
                    visible: root.enableGlow
                }
            }

            // Package icon — system app icon when available, generic fallback
            UI.Icon {
                readonly property bool hasAppIcon: root.showPackageIcons && root.resolvedIcon !== ""
                source: hasAppIcon ? root.resolvedIcon : root.svg("ic_package_added")
                implicitWidth: hasAppIcon ? 16 : 12
                implicitHeight: hasAppIcon ? 16 : 12
                isMask: !hasAppIcon
                color: hasAppIcon ? "transparent" : root.sigil
                opacity: hasAppIcon ? 1.0 : 0.9
                smooth: true
            }

            // Name
            Text {
                text: root.pkgName
                color: root.textColor
                font.pixelSize: 10 * root.fs
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Needs a local build (update previews: no binary cache hit)
            Tag {
                visible: root.pkg && root.pkg.action === "build"
                text: qsTr("build")
                tone: UI.Theme.changed
                fs: root.fs
                ToolTip.visible: buildHover.hovered
                ToolTip.text: qsTr("Not in the binary cache: built on this machine")
                HoverHandler {
                    id: buildHover
                }
            }

            // Version
            Text {
                text: root.pkgType === "added" ? root.pkgNewVersion : root.pkgType === "removed" ? root.pkgOldVersion : root.pkgOldVersion + " → " + root.pkgNewVersion
                color: root.textColor
                opacity: 0.55
                font.pixelSize: root.fpx(8)
                font.family: UI.Theme.fixedWidthFont.family
                elide: Text.ElideRight
                Layout.preferredWidth: Math.min(155, root.width * .3)
                Layout.maximumWidth: 175
                horizontalAlignment: Text.AlignRight
            }

            // Size delta
            Text {
                visible: root.pkgSize !== ""
                text: root.pkgSize
                color: root.sigil
                opacity: 1
                font.pixelSize: 9 * root.fs
                font.family: UI.Theme.fixedWidthFont.family
                Layout.preferredWidth: 62
                Layout.maximumWidth: 72
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

            // Chevron (only in compact mode)
            UI.Icon {
                visible: !root.forceExpanded
                source: root.isOpen ? root.svg("ic_chevron_up") : root.svg("ic_chevron_down")
                implicitWidth: 11
                implicitHeight: 11
                isMask: true
                color: root.textColor
                opacity: rowMa.containsMouse ? 0.65 : 0.20
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !root.forceExpanded
            onClicked: root._userExpanded = !root._userExpanded
        }
    }

    // ── Detail panel ──────────────────────────────────────────────────────────
    Rectangle {
        id: detailPanel
        anchors {
            left: parent.left
            right: parent.right
            top: rowBg.bottom
            topMargin: 2
            leftMargin: 18
        }
        visible: root.isOpen
        implicitHeight: detailCol.implicitHeight + 12
        radius: 5
        color: "transparent"
        border.width: 0

        ColumnLayout {
            id: detailCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 8
            }
            spacing: 5

            Text {
                Layout.fillWidth: true
                text: root.pkgName
                color: root.textColor
                wrapMode: Text.WrapAnywhere
                font.pixelSize: 10 * root.fs
                font.weight: Font.Medium
            }

            // Version row — upgrade
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.pkgType !== "added" && root.pkgType !== "removed" && root.pkgOldVersion !== "" && root.pkgNewVersion !== ""
                Text {
                    text: qsTr("Version")
                    color: root.textColor
                    opacity: 0.65
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    text: root.pkgOldVersion + "  →  " + root.pkgNewVersion
                    color: root.textColor
                    opacity: 0.92
                    font.pixelSize: root.fpx(8.5)
                    font.family: UI.Theme.fixedWidthFont.family
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            // Version row — added
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.pkgType === "added" && root.pkgNewVersion !== ""
                Text {
                    text: qsTr("Version")
                    color: root.textColor
                    opacity: 0.65
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    text: root.pkgNewVersion
                    color: root.sigil
                    opacity: 0.92
                    font.pixelSize: root.fpx(8.5)
                    font.family: UI.Theme.fixedWidthFont.family
                    font.bold: true
                }
            }

            // Version row — removed
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.pkgType === "removed" && root.pkgOldVersion !== ""
                Text {
                    text: qsTr("Version")
                    color: root.textColor
                    opacity: 0.65
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    text: root.pkgOldVersion
                    color: root.sigil
                    opacity: 0.92
                    font.pixelSize: root.fpx(8.5)
                    font.family: UI.Theme.fixedWidthFont.family
                    font.bold: true
                }
            }

            // Size delta
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.pkgSize !== ""
                Text {
                    text: qsTr("Size delta")
                    color: root.textColor
                    opacity: 0.65
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    text: root.pkgSize
                    color: root.sigil
                    opacity: 0.92
                    font.pixelSize: root.fpx(8.5)
                    font.family: UI.Theme.fixedWidthFont.family
                    font.bold: true
                }
            }

            // Store path + copy
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: qsTr("Store path")
                    color: root.textColor
                    opacity: 0.65
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    id: storePath
                    text: root.pathResult ? root.pathResult.path || root.pathResult.message : root.pkg.storeProfile ? qsTr("Resolving store path…") : qsTr("Not built yet")
                    color: root.textColor
                    opacity: 0.8
                    font.pixelSize: 9 * root.fs
                    font.family: UI.Theme.fixedWidthFont.family
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Rectangle {
                    implicitWidth: 20
                    implicitHeight: 17
                    radius: 4
                    color: copyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }
                    UI.Icon {
                        anchors.centerIn: parent
                        source: root.svg("ic_copy")
                        implicitWidth: 10
                        implicitHeight: 10
                        isMask: true
                        color: root.textColor
                        opacity: 0.8
                    }
                    MouseArea {
                        id: copyMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !!root.pathResult && !!root.pathResult.path
                        onClicked: root.copyRequested(root.pathResult.path)
                        ToolTip.text: qsTr("Copy store path")
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 400
                    }
                }
            }

            // Why is this package here? Only for packages in an installed generation.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !!root.pkg.storeProfile
                Text {
                    Layout.alignment: Qt.AlignTop
                    text: qsTr("Why here")
                    color: root.textColor
                    opacity: 0.65
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                UI.ActionButton {
                    objectName: "whyButton"
                    visible: !root.whyResult
                    text: qsTr("Why is this here?")
                    flatStyle: true
                    implicitHeight: 22 * root.fs
                    font.pixelSize: 9 * root.fs
                    tip: qsTr("Show the dependency chain that pulls %1 into this generation").arg(root.pkgName)
                    onClicked: root.whyRequested(root.pkg, false)
                }
                WhyChain {
                    visible: !!root.whyResult
                    Layout.fillWidth: true
                    entry: root.whyResult || null
                    allEntry: root.whyAllResult || null
                    metaCache: root.metaCache
                    fs: root.fs
                    textColor: root.textColor
                    accentColor: root.accentColor
                    onShowAllRequested: root.whyRequested(root.pkg, true)
                    onCopyRequested: text => root.copyRequested(text)
                }
                Item {
                    Layout.fillWidth: true
                    visible: !root.whyResult
                }
            }

            // Upstream / source link.
            // Prefers (in order):
            //   1) meta.homepage from nixpkgs  → real upstream project page
            //   2) Website from a plasmoid metadata.json → user-built widget repo
            //   3) nixpkgs search fallback     → at least lets the user find the derivation
            RowLayout {
                id: sourceRow
                Layout.fillWidth: true
                spacing: 8
                readonly property var metaEntry: root.metaCache && root.pkgName ? root.metaCache[root.pkgName] : undefined
                // The URL ultimately comes from either nixpkgs meta.homepage or a
                // plasmoid metadata.json's Website field — both are upstream-controlled
                // strings. Restrict to http(s) so a malicious entry can't open
                // file:// / javascript: / data: / etc. via Qt.openUrlExternally.
                readonly property string rawUrl: metaEntry && metaEntry.url ? metaEntry.url : ""
                readonly property string metaUrl: /^https?:\/\//i.test(rawUrl) ? rawUrl : ""
                readonly property string metaSource: metaUrl !== "" && metaEntry && metaEntry.source ? metaEntry.source : ""
                readonly property string searchUrl: "https://github.com/NixOS/nixpkgs/search?q=" + encodeURIComponent(root.pkgName)
                readonly property string activeUrl: metaUrl !== "" ? metaUrl : searchUrl

                // Short label that hints at the link's origin
                readonly property string label: {
                    if (metaSource === "plasmoid")
                        return qsTr("upstream");
                    if (metaSource === "nixpkgs")
                        return qsTr("homepage");
                    return "nixpkgs";
                }

                // Pretty-printed host + path for the link text
                readonly property string displayUrl: {
                    const u = activeUrl;
                    const stripped = u.replace(/^https?:\/\//, "").replace(/\/$/, "");
                    return stripped.length > 48 ? stripped.substring(0, 45) + "…" : stripped;
                }

                Text {
                    text: parent.label
                    color: root.textColor
                    opacity: 0.65
                    font.pixelSize: root.fpx(8)
                    Layout.minimumWidth: 65
                }
                Text {
                    text: parent.displayUrl + "  ↗"
                    color: root.accentColor
                    opacity: ghMa.containsMouse ? 1.0 : 0.72
                    font.pixelSize: root.fpx(8)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                    MouseArea {
                        id: ghMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(sourceRow.activeUrl)
                        ToolTip.text: sourceRow.activeUrl
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 400
                    }
                }
            }
        }
    }
}
