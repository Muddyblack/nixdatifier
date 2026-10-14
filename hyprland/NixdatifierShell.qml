import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../package/contents/ui" as App
import "../package/contents/ui/shared" as UI
import "../package/contents/ui/SettingsSchema.js" as Schema

ShellRoot {
    id: root
    property bool popupOpen: false
    property bool settingsOpen: false
    property bool configReady: false
    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/nixdatifier/hyprland.json"
    readonly property string statusPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nixdatifier-" + Quickshell.env("USER") + "/status.json"
    readonly property bool topEdge: cfg.popupPosition.indexOf("bottom") !== 0
    readonly property bool leftEdge: cfg.popupPosition.endsWith("left")
    readonly property bool rightEdge: cfg.popupPosition.endsWith("right")
    readonly property bool smokeTest: Quickshell.env("NIXDATIFIER_SMOKE_TEST") === "1"
    function copySettings(from, to) {
        for (const f of Schema.fields)
            to[f.key] = from[f.key];
        to.pillMode = from.pillMode;
        to.popupPosition = from.popupPosition;
        to.panelEdgeOffset = from.panelEdgeOffset;
        to.panelSideOffset = from.panelSideOffset;
    }
    function configure() {
        copySettings(cfg, draft);
        settingsOpen = true;
        popupOpen = true;
    }
    function applySettings() {
        settingsEditor.forceActiveFocus();
        copySettings(draft, cfg);
        settingsFile.writeAdapter();
    }
    FileView {
        id: packageMetadata
        path: decodeURIComponent(Qt.resolvedUrl("../package/metadata.json").toString().replace(/^file:\/\//, ""))
        property string version: ""
        onLoaded: version = JSON.parse(text()).KPlugin.Version
    }
    FileView {
        id: settingsFile
        path: root.configPath
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: root.configReady = true
        onLoadFailed: root.configReady = true
        onAdapterUpdated: if (root.configReady && !root.smokeTest)
            writeAdapter()
        JsonAdapter {
            id: cfg
            property string flakePath: ""
            property string configRepoPath: ""
            property int checkInterval: 3600
            property int maxGenerations: 10
            property string defaultView: "timeline"
            property bool enableHostDetect: true
            property string customCommands: "[{\"label\":\"update\",\"cmd\":\"nix flake update\"},{\"label\":\"upnix\",\"cmd\":\"upnix\"}]"
            property bool showCommandButtons: true
            property string commandTerminal: ""
            property bool usePkexec: true
            property bool enableLiveSwitch: true
            property bool confirmBeforeRollback: true
            property bool confirmBeforeDelete: true
            property bool showDeleteButton: true
            property bool showNotifications: true
            property bool autoRefreshOnOpen: true
            property bool showFlakeSection: true
            property string secretsPath: ""
            property string secretsSourcePath: ""
            property string impermanencePaths: ""
            property int impermanenceStaleDays: 180
            property bool impermanenceAllDisks: false
            property bool diffFilterEnabled: true
            property color timelineColor: "#71849b"
            property color accentColor: "#91bcff"
            property real fontScale: 1.0
            property bool showBg: true
            property string bgColor: "#f5131923"
            property real bgRadius: 14.0
            property bool useSystemTextColor: true
            property color customTextColor: "#ffffff"
            property bool enableGlow: true
            property string iconStyle: "colored"
            property string diffViewMode: "compact"
            property bool showPackageIcons: true
            property string compactStyle: "icon"
            property bool compactShowBadge: true
            property bool compactAnimateIcon: true
            property int popupWidth: 600
            property int popupHeight: 740
            property string gcCustomCommand: ""
            property bool enableMotion: true
            property string pillMode: "always"
            property string popupPosition: "top-right"
            property int panelEdgeOffset: 0
            property int panelSideOffset: 0
        }
    }
    App.Settings {
        id: draft
    }
    Component {
        id: processAdapter
        ProcessAdapter {}
    }
    App.Engine {
        id: core
        settings: cfg
        syncSettings: true
        executor: processAdapter
        autoStart: false
        expanded: root.popupOpen && !root.settingsOpen
        onConfigureRequested: root.configure()
    }
    onConfigReadyChanged: if (configReady && !smokeTest) {
        core.autoStart = true;
        core.start();
    }
    Component.onCompleted: {
        UI.Theme.iconResolver = function (name) {
            return name ? Quickshell.iconPath(name, true) : "";
        };
        if (smokeTest) {
            root.popupOpen = true;
            testTimer.start();
        }
    }
    Timer {
        id: testTimer
        interval: 1200
        onTriggered: {
            console.log("NIXDATIFIER_HOST_LOADED");
            Qt.quit();
        }
    }
    FileView {
        id: statusFile
        path: root.smokeTest ? "" : root.statusPath
        atomicWrites: true
        printErrors: false
        onAdapterUpdated: if (!root.smokeTest)
            statusWriteTimer.restart()
        JsonAdapter {
            property bool working: core.isSpinning
            property bool motion: cfg.enableMotion && cfg.compactAnimateIcon
            property string iconStyle: cfg.iconStyle
            property string accent: String(cfg.accentColor)
            property string summary: core.toolTipMainText + "\n" + core.toolTipSubText
            property int updates: cfg.compactShowBadge ? core.flakeUpdates.length : 0
        }
    }
    Timer {
        id: statusWriteTimer
        interval: 0
        repeat: false
        onTriggered: statusFile.writeAdapter()
    }
    IpcHandler {
        target: "panel"
        function toggle(): void {
            root.popupOpen = !root.popupOpen;
        }
        // Named `open`: `qs ipc … call panel show` would collide with Quickshell's own `ipc show`.
        function open(): void {
            root.popupOpen = true;
        }
        function hide(): void {
            root.popupOpen = false;
        }
        function refresh(): void {
            core.refreshGenerations();
            core.checkFlakeUpdates();
        }
        function configure(): void {
            root.configure();
        }
        function summary(): string {
            return core.toolTipSubText;
        }
        function quit(): void {
            Qt.quit();
        }
    }
    PanelWindow {
        id: pillWindow
        property bool revealed: false
        readonly property bool shown: cfg.pillMode === "always" || revealed || root.popupOpen || pillDrag.pressed
        visible: cfg.pillMode !== "tray"
        color: "transparent"
        exclusiveZone: 0
        aboveWindows: true
        // A stable surface keeps drag coordinates independent of compositor moves.
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        mask: Region {
            item: pillBox
        }
        Rectangle {
            id: pillBox
            width: pillWindow.shown ? 106 : 72
            height: pillWindow.shown ? 38 : 4
            readonly property real restingX: root.leftEdge ? 8 + cfg.panelSideOffset : root.rightEdge ? pillWindow.width - width - 8 - cfg.panelSideOffset : (pillWindow.width - width) / 2
            readonly property real restingY: root.topEdge ? (pillWindow.shown ? 4 : 0) + cfg.panelEdgeOffset : pillWindow.height - height - (pillWindow.shown ? 4 : 0) - cfg.panelEdgeOffset
            x: pillDrag.moving ? pillDrag.dragX : Math.max(0, Math.min(pillWindow.width - width, restingX))
            y: pillDrag.moving ? pillDrag.dragY : Math.max(0, Math.min(pillWindow.height - height, restingY))
            radius: 17
            color: pillWindow.shown ? cfg.bgColor : "transparent"
            border.color: pillWindow.shown ? UI.Theme.line : "transparent"
            App.CompactView {
                visible: pillWindow.shown
                anchors.fill: parent
                anchors.margins: 3
                accentColor: core.accentColor
                textColor: core.textColor
                activeGenNum: core.activeGenNum
                flakeUpdates: core.flakeUpdates
                isBusy: core.isBusy
                isLoadingGens: core.isLoadingGens
                isSpinning: core.isSpinning
                enableMotion: cfg.enableMotion && cfg.compactAnimateIcon
                compactStyle: "pill"
                compactShowBadge: cfg.compactShowBadge
                iconStyle: cfg.iconStyle
                onToggleExpanded: root.popupOpen = !root.popupOpen
            }
            MouseArea {
                id: pillDrag
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: moving ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property bool moving: false
                property point pressPoint
                property real startX: 0
                property real startY: 0
                property real dragX: 0
                property real dragY: 0
                onPressed: mouse => {
                    pressPoint = mapToItem(pillBox.parent, mouse.x, mouse.y);
                    startX = pillBox.x;
                    startY = pillBox.y;
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const point = mapToItem(pillBox.parent, mouse.x, mouse.y);
                    const dx = point.x - pressPoint.x;
                    const dy = point.y - pressPoint.y;
                    if (!moving && Math.hypot(dx, dy) < Qt.styleHints.startDragDistance)
                        return;
                    dragX = Math.max(8, Math.min(pillWindow.width - pillBox.width - 8, startX + dx));
                    dragY = Math.max(4, Math.min(pillWindow.height - pillBox.height - 4, startY + dy));
                    if (!moving) {
                        moving = true;
                        root.popupOpen = false;
                    }
                }
                onReleased: {
                    if (moving) {
                        const left = dragX + pillBox.width / 2 < pillWindow.width / 2;
                        const top = dragY + pillBox.height / 2 < pillWindow.height / 2;
                        cfg.popupPosition = (top ? "top-" : "bottom-") + (left ? "left" : "right");
                        cfg.panelSideOffset = Math.round(Math.max(0, (left ? dragX : pillWindow.width - pillBox.width - dragX) - 8));
                        cfg.panelEdgeOffset = Math.round(Math.max(0, (top ? dragY : pillWindow.height - pillBox.height - dragY) - 4));
                        moving = false;
                    } else {
                        root.popupOpen = !root.popupOpen;
                    }
                }
                onCanceled: moving = false
            }
        }
        HoverHandler {
            id: hover
            parent: pillBox
            onHoveredChanged: {
                if (hovered) {
                    pillWindow.revealed = true;
                    hidePill.stop();
                } else
                    hidePill.restart();
            }
        }
        Timer {
            id: hidePill
            interval: 400
            onTriggered: if (!hover.hovered && !pillDrag.pressed)
                pillWindow.revealed = false
        }
        Timer {
            id: tipDelay
            interval: 500
            running: hover.hovered && pillWindow.shown && !root.popupOpen
        }
    }
    // Separate popup so the tooltip isn't clipped to the pill's tiny layer surface.
    PopupWindow {
        visible: !pillDrag.pressed && pillWindow.visible && hover.hovered && !tipDelay.running && pillWindow.shown && !root.popupOpen && !root.smokeTest
        color: "transparent"
        anchor.window: pillWindow
        anchor.rect.x: pillBox.x
        anchor.rect.y: pillBox.y + (root.topEdge ? 0 : -6)
        anchor.rect.width: pillBox.width
        anchor.rect.height: pillBox.height + 6
        anchor.edges: (root.topEdge ? Edges.Bottom : Edges.Top) | (root.leftEdge ? Edges.Left : root.rightEdge ? Edges.Right : 0)
        anchor.gravity: (root.topEdge ? Edges.Bottom : Edges.Top) | (root.leftEdge ? Edges.Right : root.rightEdge ? Edges.Left : 0)
        implicitWidth: tipBox.implicitWidth
        implicitHeight: tipBox.implicitHeight
        Rectangle {
            id: tipBox
            anchors.fill: parent
            implicitWidth: tipText.width + 20
            implicitHeight: tipText.implicitHeight + 14
            radius: 8
            color: cfg.bgColor
            border.color: UI.Theme.line
            Column {
                id: tipText
                x: 10
                y: 7
                width: Math.min(360, Math.max(tipMain.implicitWidth, tipSub.implicitWidth))
                spacing: 2
                Text {
                    id: tipMain
                    width: parent.width
                    text: core.toolTipMainText
                    color: core.textColor
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                Text {
                    id: tipSub
                    width: parent.width
                    visible: text !== ""
                    text: core.toolTipSubText
                    color: UI.Theme.muted
                    wrapMode: Text.Wrap
                }
            }
        }
    }
    PanelWindow {
        id: popup
        visible: root.popupOpen
        color: "transparent"
        focusable: true
        exclusiveZone: 0
        aboveWindows: true
        implicitWidth: Math.max(380, Math.min(cfg.popupWidth, screen ? screen.width - 24 : 600))
        implicitHeight: Math.max(420, Math.min(cfg.popupHeight, screen ? screen.height - 64 : 740))
        anchors {
            top: root.topEdge
            bottom: !root.topEdge
            left: root.leftEdge
            right: root.rightEdge
        }
        margins {
            top: Math.min(46 + cfg.panelEdgeOffset, Math.max(12, (popup.screen ? popup.screen.height : 1080) - popup.height - 12))
            bottom: Math.min(46 + cfg.panelEdgeOffset, Math.max(12, (popup.screen ? popup.screen.height : 1080) - popup.height - 12))
            left: Math.min(12 + cfg.panelSideOffset, Math.max(12, (popup.screen ? popup.screen.width : 1920) - popup.width - 12))
            right: Math.min(12 + cfg.panelSideOffset, Math.max(12, (popup.screen ? popup.screen.width : 1920) - popup.width - 12))
        }
        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: {
                if (root.settingsOpen)
                    root.settingsOpen = false;
                else
                    root.popupOpen = false;
            }
            App.ApplicationView {
                anchors.fill: parent
                engine: core
                visible: !root.settingsOpen
            }
            Rectangle {
                anchors.fill: parent
                visible: root.settingsOpen
                color: UI.Theme.backgroundColor
                radius: 14
                border.color: UI.Theme.line
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14
                    App.SettingsEditor {
                        id: settingsEditor
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        settings: draft
                        currentVersion: packageMetadata.version
                        hyprland: true
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        UI.ActionButton {
                            text: qsTr("Cancel")
                            onClicked: root.settingsOpen = false
                        }
                        UI.ActionButton {
                            text: qsTr("Apply")
                            onClicked: root.applySettings()
                        }
                        UI.ActionButton {
                            text: qsTr("OK")
                            primary: true
                            onClicked: {
                                root.applySettings();
                                root.settingsOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
    HyprlandFocusGrab {
        // Other layer-shell compositors (including niri) do not implement
        // Hyprland's focus-grab protocol. Escape and the tray still dismiss.
        active: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") && root.popupOpen && !core.pinned && !root.smokeTest
        windows: [popup]
        onCleared: root.popupOpen = false
    }
}
