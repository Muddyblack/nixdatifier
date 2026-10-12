import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "shared" as UI
import "components"

// Development environments of any project folder: direnv state, the .envrc,
// flake inputs and devShells. Nothing here is specific to NixOS.
Item {
    id: devEnvTab

    required property color accentColor
    required property color textColor
    required property real fs
    required property var devEnvResult
    required property var devEnvProjects
    required property string activeViewMode
    property string systemFlakePath: ""
    property bool isProbingDevEnv: false
    property var shellPackages: ({})
    property var devSpace: []
    property bool isMeasuringSpace: false

    readonly property var result: devEnvResult
    readonly property bool found: !!result && !result.isError
    readonly property bool hasFlake: found && !!result.files && result.files.indexOf("flake.nix") >= 0
    // The devShell whose packages are shown, and the cache awaiting a second click.
    property string openShell: ""
    property string confirmClear: ""
    property string shownDir: ""
    readonly property var openPackages: found && openShell !== "" && !!result ? (shellPackages[result.dir + "#" + openShell] || null) : null
    onResultChanged: {
        const dir = (result && !result.isError) ? result.dir : "";
        if (dir !== shownDir) {
            shownDir = dir;
            openShell = "";
        }
    }

    signal devEnvRequested(string path)
    signal discoverRequested
    signal copyToClipboard(string text)
    signal actionRequested(string kind, string dir)
    signal shellPackagesRequested(string dir, string name)
    signal measureSpaceRequested
    signal clearCacheRequested(string dir)

    anchors.fill: parent
    visible: activeViewMode === "devenv"
    onVisibleChanged: if (visible)
        discoverRequested()

    function inspect(path) {
        const target = (path !== undefined ? path : pathField.text).trim();
        if (target === "" || isProbingDevEnv)
            return;
        pathField.text = target;
        devEnvRequested(target);
    }
    function ago(epoch) {
        if (!epoch)
            return "—";
        const days = Math.floor((Date.now() / 1000 - epoch) / 86400);
        if (days < 1)
            return qsTr("today");
        if (days === 1)
            return qsTr("yesterday");
        if (days < 60)
            return qsTr("%1 days ago").arg(days);
        if (days < 730)
            return qsTr("%1 months ago").arg(Math.round(days / 30));
        return qsTr("%1 years ago").arg(Math.round(days / 365));
    }
    function staleTone(epoch) {
        const days = (Date.now() / 1000 - epoch) / 86400;
        return !epoch ? UI.Theme.muted : days > 180 ? UI.Theme.negative : days > 60 ? UI.Theme.changed : UI.Theme.positive;
    }
    function stateLabel(state) {
        switch (state) {
        case "allowed":
            return qsTr("Allowed");
        case "blocked":
            return qsTr("Blocked");
        case "denied":
            return qsTr("Denied");
        case "unknown":
            return qsTr("direnv missing");
        }
        return qsTr("Not set up");
    }
    function stateTone(state) {
        return state === "allowed" ? UI.Theme.positive : state === "blocked" || state === "unknown" ? UI.Theme.changed : state === "denied" ? UI.Theme.negative : UI.Theme.muted;
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
                text: qsTr("See how a project's development environment is set up: direnv, Nix flakes, shell.nix and devenv. Works for any folder, on any distribution.")
                color: "#9bacc4"
                font.pixelSize: UI.Theme.fontPx(11, devEnvTab.fs)
                wrapMode: Text.Wrap
                lineHeight: 1.5
            }
            Text {
                Layout.bottomMargin: 7
                text: qsTr("Project folder")
                color: "#a3b2c9"
                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                FieldInput {
                    id: pathField
                    objectName: "devEnvInput"
                    Layout.fillWidth: true
                    mono: true
                    placeholderText: "~/projects/my-app"
                    accent: devEnvTab.accentColor
                    textColor: devEnvTab.textColor
                    fs: devEnvTab.fs
                    onAccepted: devEnvTab.inspect()
                }
                UI.ActionButton {
                    objectName: "devEnvInspect"
                    implicitHeight: pathField.implicitHeight
                    text: devEnvTab.isProbingDevEnv ? qsTr("Inspecting…") : qsTr("Inspect")
                    glyph: Qt.resolvedUrl("assets/ic_search.svg")
                    primary: true
                    accent: devEnvTab.accentColor
                    font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                    enabled: pathField.text.trim() !== "" && !devEnvTab.isProbingDevEnv
                    onClicked: devEnvTab.inspect()
                }
            }

            // Folders direnv already knows, plus the system flake as a shortcut.
            Subheading {
                Layout.fillWidth: true
                Layout.topMargin: 20
                visible: projects.count > 0
                text: qsTr("Your projects")
                detail: qsTr("from direnv")
                fs: devEnvTab.fs
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 9
                spacing: 7
                visible: projects.count > 0
                Repeater {
                    id: projects
                    model: {
                        const list = devEnvTab.devEnvProjects.slice(0, 24);
                        if (devEnvTab.systemFlakePath !== "" && !list.some(p => p.dir === devEnvTab.systemFlakePath))
                            list.unshift({
                                dir: devEnvTab.systemFlakePath,
                                name: qsTr("System flake"),
                                state: ""
                            });
                        return list;
                    }
                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool current: devEnvTab.found && devEnvTab.result.dir === modelData.dir
                        implicitWidth: chipText.implicitWidth + 22
                        implicitHeight: chipText.implicitHeight + 14
                        radius: 8
                        color: current ? UI.Theme.wash(devEnvTab.accentColor, .16) : chipArea.containsMouse ? "#0affffff" : "#05ffffff"
                        border.color: current ? devEnvTab.accentColor : "#10ffffff"
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.name
                            color: devEnvTab.textColor
                            font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: devEnvTab.inspect(chip.modelData.dir)
                        }
                        ToolTip.visible: chipArea.containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: chip.modelData.dir
                    }
                }
            }

            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 18
                visible: !!devEnvTab.result && devEnvTab.result.isError
                glyph: "ic_warning"
                tone: UI.Theme.negative
                emphasis: true
                fs: devEnvTab.fs
                text: devEnvTab.result && devEnvTab.result.isError ? devEnvTab.result.value : ""
            }

            // ── Overview ─────────────────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 22
                visible: devEnvTab.found
                text: devEnvTab.found ? devEnvTab.result.name : ""
                color: devEnvTab.textColor
                font.pixelSize: UI.Theme.fontPx(15, devEnvTab.fs)
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 3
                visible: devEnvTab.found && devEnvTab.result.description !== ""
                text: devEnvTab.found ? devEnvTab.result.description : ""
                color: UI.Theme.muted
                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                wrapMode: Text.Wrap
            }
            InfoRows {
                Layout.fillWidth: true
                Layout.topMargin: 14
                visible: devEnvTab.found
                textColor: devEnvTab.textColor
                fs: devEnvTab.fs
                rows: {
                    if (!devEnvTab.found)
                        return [];
                    const r = devEnvTab.result;
                    const out = [
                        {
                            label: qsTr("direnv"),
                            value: devEnvTab.stateLabel(r.envrcState) + (r.direnvVersion ? "  ·  " + r.direnvVersion : ""),
                            tone: devEnvTab.stateTone(r.envrcState)
                        }
                    ];
                    if (r.envrcUses.length)
                        out.push({
                            label: qsTr("Provides"),
                            value: r.envrcUses.join(", ")
                        });
                    if (r.cacheTime)
                        out.push({
                            label: qsTr("Cached environment"),
                            value: devEnvTab.ago(r.cacheTime) + (r.cacheKb ? "  ·  " + UI.Theme.formatBytes(r.cacheKb * 1024) : "")
                        });
                    if (r.lockNewest)
                        out.push({
                            label: qsTr("Flake inputs"),
                            value: qsTr("%1, oldest locked %2").arg(r.inputs.length).arg(devEnvTab.ago(r.lockOldest)),
                            tone: devEnvTab.staleTone(r.lockOldest)
                        });
                    if (r.files.length)
                        out.push({
                            label: qsTr("Project files"),
                            value: r.files.join(", ")
                        });
                    return out;
                }
            }
            Notice {
                Layout.fillWidth: true
                Layout.topMargin: 12
                visible: devEnvTab.found && devEnvTab.result.envrcState === "none" && devEnvTab.result.files.indexOf("flake.nix") >= 0
                glyph: "ic_info"
                tone: UI.Theme.changed
                emphasis: true
                fs: devEnvTab.fs
                text: qsTr("This project has a flake but no .envrc. Add `use flake` to .envrc and run `direnv allow` to load its shell automatically.")
            }
            // ── Actions ──────────────────────────────────────────────────────
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 14
                spacing: 8
                visible: devEnvTab.found
                UI.ActionButton {
                    objectName: "devEnvAllow"
                    visible: devEnvTab.found && (devEnvTab.result.envrcState === "blocked" || devEnvTab.result.envrcState === "denied")
                    text: qsTr("Allow (direnv allow)")
                    primary: true
                    accent: devEnvTab.accentColor
                    font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                    onClicked: devEnvTab.actionRequested("allow", devEnvTab.result.dir)
                }
                UI.ActionButton {
                    objectName: "devEnvShell"
                    visible: devEnvTab.found && (devEnvTab.hasFlake || devEnvTab.result.envrcState === "allowed")
                    text: qsTr("Open shell")
                    glyph: Qt.resolvedUrl("assets/ic_terminal.svg")
                    tip: qsTr("Open a terminal inside this project's environment")
                    font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                    onClicked: devEnvTab.actionRequested("shell", devEnvTab.result.dir)
                }
                UI.ActionButton {
                    objectName: "devEnvUpdate"
                    visible: devEnvTab.found && devEnvTab.result.files.indexOf("flake.lock") >= 0
                    text: qsTr("Update inputs")
                    glyph: Qt.resolvedUrl("assets/ic_refresh.svg")
                    tip: qsTr("Run `nix flake update` in a terminal")
                    font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                    onClicked: devEnvTab.actionRequested("update", devEnvTab.result.dir)
                }
            }

            // ── devShells ────────────────────────────────────────────────────
            Subheading {
                Layout.fillWidth: true
                Layout.topMargin: 22
                visible: devEnvTab.hasFlake
                text: qsTr("Dev shells")
                detail: devEnvTab.found && devEnvTab.result.shellsState === "ok" ? String(devEnvTab.result.shells.length) : ""
                fs: devEnvTab.fs
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 9
                spacing: 7
                visible: devEnvTab.hasFlake && devEnvTab.result.shells.length > 0
                Repeater {
                    model: devEnvTab.found ? devEnvTab.result.shells : []
                    Rectangle {
                        id: shellChip
                        required property string modelData
                        readonly property bool open: devEnvTab.openShell === modelData
                        implicitWidth: shellText.implicitWidth + 20
                        implicitHeight: shellText.implicitHeight + 12
                        radius: 7
                        color: open ? UI.Theme.wash(devEnvTab.accentColor, .22) : shellArea.containsMouse ? UI.Theme.wash(devEnvTab.accentColor, .14) : UI.Theme.wash(devEnvTab.accentColor, .08)
                        border.color: open ? devEnvTab.accentColor : "transparent"
                        Text {
                            id: shellText
                            anchors.centerIn: parent
                            text: shellChip.modelData
                            color: devEnvTab.accentColor
                            font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                        }
                        MouseArea {
                            id: shellArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                devEnvTab.openShell = shellChip.open ? "" : shellChip.modelData;
                                if (devEnvTab.openShell !== "")
                                    devEnvTab.shellPackagesRequested(devEnvTab.result.dir, shellChip.modelData);
                            }
                        }
                        ToolTip.visible: shellArea.containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: qsTr("Show the packages in this shell")
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 10
                visible: devEnvTab.openShell !== ""
                text: !devEnvTab.openPackages || devEnvTab.openPackages.state === "loading" ? qsTr("Evaluating the shell…") : devEnvTab.openPackages.state === "error" ? qsTr("Could not list the packages offline.") : devEnvTab.openPackages.names.length === 0 ? qsTr("This shell adds no packages.") : ""
                color: UI.Theme.muted
                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                wrapMode: Text.Wrap
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 6
                visible: !!devEnvTab.openPackages && devEnvTab.openPackages.names.length > 0
                Repeater {
                    model: devEnvTab.openPackages ? devEnvTab.openPackages.names.slice(0, 60) : []
                    Tag {
                        required property string modelData
                        text: modelData
                        tone: UI.Theme.muted
                        fs: devEnvTab.fs
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: !!devEnvTab.openPackages && devEnvTab.openPackages.names.length > 60
                text: devEnvTab.openPackages ? qsTr("and %1 more").arg(devEnvTab.openPackages.names.length - 60) : ""
                color: UI.Theme.muted
                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 10
                visible: devEnvTab.hasFlake && devEnvTab.result.shellsState === "loading"
                text: qsTr("Evaluating the flake…")
                color: UI.Theme.muted
                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 10
                visible: devEnvTab.hasFlake && devEnvTab.result.shellsState === "unavailable"
                text: qsTr("Dev shells could not be listed offline. Evaluate the flake once with `nix flake show`, or check that flake.nix is tracked by git.")
                color: UI.Theme.muted
                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                wrapMode: Text.Wrap
            }

            // ── Flake inputs ─────────────────────────────────────────────────
            Subheading {
                Layout.fillWidth: true
                Layout.topMargin: 22
                visible: devEnvTab.found && devEnvTab.result.inputs.length > 0
                text: qsTr("Flake inputs")
                detail: devEnvTab.found ? String(devEnvTab.result.inputs.length) : ""
                fs: devEnvTab.fs
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 9
                visible: devEnvTab.found && devEnvTab.result.inputs.length > 0
                implicitHeight: inputList.implicitHeight + 12
                radius: 9
                color: "#03ffffff"
                border.color: "#0effffff"
                ColumnLayout {
                    id: inputList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 0
                    Repeater {
                        model: devEnvTab.found ? devEnvTab.result.inputs : []
                        RowLayout {
                            id: inputRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.topMargin: 7
                            Layout.bottomMargin: 7
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: inputRow.modelData.name
                                    color: devEnvTab.textColor
                                    font.pixelSize: UI.Theme.fontPx(11, devEnvTab.fs)
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: inputRow.modelData.follows !== "" ? qsTr("follows %1").arg(inputRow.modelData.follows) : [inputRow.modelData.source, inputRow.modelData.ref].filter(x => x).join(" · ")
                                    color: UI.Theme.muted
                                    font.family: UI.Theme.fixedWidthFont.family
                                    font.pixelSize: UI.Theme.fontPx(9, devEnvTab.fs)
                                    elide: Text.ElideMiddle
                                }
                            }
                            Text {
                                visible: inputRow.modelData.rev !== ""
                                text: inputRow.modelData.rev
                                color: UI.Theme.muted
                                font.family: UI.Theme.fixedWidthFont.family
                                font.pixelSize: UI.Theme.fontPx(9, devEnvTab.fs)
                            }
                            Text {
                                visible: inputRow.modelData.modified > 0
                                text: devEnvTab.ago(inputRow.modelData.modified)
                                color: devEnvTab.staleTone(inputRow.modelData.modified)
                                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                            }
                        }
                    }
                }
            }

            // ── Space held by dev environments ───────────────────────────────
            Subheading {
                Layout.fillWidth: true
                Layout.topMargin: 22
                text: qsTr("Space held by dev environments")
                detail: devEnvTab.devSpace.length > 0 ? String(devEnvTab.devSpace.length) : ""
                fs: devEnvTab.fs
                UI.ActionButton {
                    objectName: "devEnvMeasure"
                    text: devEnvTab.isMeasuringSpace ? qsTr("Measuring…") : devEnvTab.devSpace.length > 0 ? qsTr("Measure again") : qsTr("Measure")
                    flatStyle: true
                    implicitHeight: 23
                    enabled: !devEnvTab.isMeasuringSpace
                    font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                    onClicked: devEnvTab.measureSpaceRequested()
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 9
                visible: devEnvTab.devSpace.length === 0
                text: devEnvTab.isMeasuringSpace ? qsTr("Measuring your direnv projects…") : qsTr("Each project's .direnv cache keeps its packages alive, which is often why garbage collection frees less than expected. Measuring reads each project's closure size at low priority.")
                color: UI.Theme.muted
                font.pixelSize: UI.Theme.fontPx(10, devEnvTab.fs)
                wrapMode: Text.Wrap
                lineHeight: 1.4
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 9
                visible: devEnvTab.devSpace.length > 0
                implicitHeight: spaceList.implicitHeight + 12
                radius: 9
                color: "#03ffffff"
                border.color: "#0effffff"
                ColumnLayout {
                    id: spaceList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 0
                    Repeater {
                        model: devEnvTab.devSpace
                        RowLayout {
                            id: spaceRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.topMargin: 7
                            Layout.bottomMargin: 7
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: spaceRow.modelData.name
                                    color: devEnvTab.textColor
                                    font.pixelSize: UI.Theme.fontPx(11, devEnvTab.fs)
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: spaceRow.modelData.dir
                                    color: UI.Theme.muted
                                    font.family: UI.Theme.fixedWidthFont.family
                                    font.pixelSize: UI.Theme.fontPx(9, devEnvTab.fs)
                                    elide: Text.ElideMiddle
                                }
                            }
                            Text {
                                text: UI.Theme.formatBytes(spaceRow.modelData.bytes) || "—"
                                color: devEnvTab.textColor
                                font.pixelSize: UI.Theme.fontPx(11, devEnvTab.fs)
                            }
                            UI.ActionButton {
                                objectName: "devEnvClear"
                                readonly property bool confirming: devEnvTab.confirmClear === spaceRow.modelData.dir
                                text: confirming ? qsTr("Confirm") : qsTr("Clear cache")
                                flatStyle: !confirming
                                primary: confirming
                                accent: UI.Theme.negative
                                implicitHeight: 23
                                tip: qsTr("Delete this project's .direnv cache. direnv rebuilds it the next time you enter the folder.")
                                font.pixelSize: UI.Theme.fontPx(9, devEnvTab.fs)
                                onClicked: {
                                    if (confirming) {
                                        devEnvTab.confirmClear = "";
                                        devEnvTab.clearCacheRequested(spaceRow.modelData.dir);
                                    } else {
                                        devEnvTab.confirmClear = spaceRow.modelData.dir;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 8
                visible: devEnvTab.devSpace.length > 0
                text: qsTr("Sizes are closure sizes; packages shared between projects count in each. Space is only reclaimed by the next garbage collection.")
                color: UI.Theme.muted
                font.pixelSize: UI.Theme.fontPx(9, devEnvTab.fs)
                wrapMode: Text.Wrap
            }

            // ── .envrc ───────────────────────────────────────────────────────
            CodeBlock {
                Layout.fillWidth: true
                Layout.topMargin: 22
                Layout.bottomMargin: 6
                visible: devEnvTab.found && devEnvTab.result.envrc !== ""
                label: ".envrc"
                text: devEnvTab.found ? devEnvTab.result.envrc : ""
                accent: devEnvTab.accentColor
                textColor: devEnvTab.textColor
                fs: devEnvTab.fs
                maximumHeight: 190
                onCopyRequested: t => devEnvTab.copyToClipboard(t)
            }
        }
    }
}
