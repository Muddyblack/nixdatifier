// Standalone host: a regular window plus a tray icon. It needs only Qt, so it
// runs on any desktop (GNOME, COSMIC, Sway, XFCE, KDE, X11, ...). The UI is the
// same Engine and views the Plasma widget and the Quickshell panel use.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Nixdatifier.Host
import "../package/contents/ui" as App
import "../package/contents/ui/shared" as UI
import "../package/contents/ui/SettingsSchema.js" as Schema

ApplicationWindow {
    id: win
    title: core.toolTipMainText !== "" ? core.toolTipMainText + " · Nixdatifier" : "Nixdatifier"
    width: settingsOpen ? Math.min(Math.max(cfg.popupWidth, 900), Screen.desktopAvailableWidth || 900) : cfg.popupWidth
    height: cfg.popupHeight
    minimumWidth: 380
    minimumHeight: 480
    color: UI.Theme.backgroundColor
    visible: false

    property bool settingsOpen: false
    property bool configReady: false
    readonly property bool smokeTest: host.smokeTest
    // Everything the editor can change, plus the keys the views write back.
    readonly property var configKeys: Schema.fields.map(f => f.key)

    App.Settings {
        id: cfg
    }
    App.Settings {
        id: draft
    }
    SystemPalette {
        id: palette
    }
    Component {
        id: runner
        ProcessRunner {}
    }

    function loadConfig() {
        // A window with the translucent panel background would show the
        // desktop through its corners, so the standalone defaults are opaque.
        cfg.bgRadius = 0;
        cfg.bgColor = "#ff131923";
        try {
            const saved = JSON.parse(host.readFile(host.configPath) || "{}");
            for (const key of configKeys)
                if (key in saved && (typeof saved[key] === typeof cfg[key] || (typeof cfg[key] === "object" && typeof saved[key] === "string")))
                    cfg[key] = saved[key];
        } catch (e) {
            console.warn("Ignoring unreadable settings:", e);
        }
        for (const key of configKeys)
            cfg[key + "Changed"].connect(saveTimer.restart);
        configReady = true;
    }
    function saveConfig() {
        const out = {};
        for (const key of configKeys)
            out[key] = typeof cfg[key] === "object" ? String(cfg[key]) : cfg[key];
        host.writeFile(host.configPath, JSON.stringify(out, null, 2));
    }
    function copySettings(from, to) {
        for (const key of Schema.fields.map(f => f.key))
            to[key] = from[key];
    }
    function configure() {
        copySettings(cfg, draft);
        settingsOpen = true;
        present();
    }
    function applySettings() {
        settingsEditor.forceActiveFocus();
        copySettings(draft, cfg);
    }
    function present() {
        show();
        raise();
        requestActivate();
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: if (!win.smokeTest)
            win.saveConfig()
    }
    // Remember the size the user chose, like the Plasma popup does.
    Timer {
        id: sizeTimer
        interval: 600
        onTriggered: {
            if (win.visibility === Window.Windowed && win.configReady) {
                cfg.popupWidth = Math.round(win.width);
                cfg.popupHeight = Math.round(win.height);
            }
        }
    }
    onWidthChanged: if (visible)
        sizeTimer.restart()
    onHeightChanged: if (visible)
        sizeTimer.restart()

    // With a tray, closing hides the window and the app keeps running. Without
    // one (stock GNOME, no AppIndicator) there would be no way back, so quit.
    onClosing: close => {
        if (host.trayAvailable && !win.smokeTest) {
            close.accepted = false;
            hide();
        } else {
            Qt.quit();
        }
    }
    Shortcut {
        sequence: "Escape"
        enabled: win.visible && host.trayAvailable
        onActivated: win.settingsOpen ? win.settingsOpen = false : win.hide()
    }
    Shortcut {
        sequence: StandardKey.Quit
        onActivated: Qt.quit()
    }

    Connections {
        target: host
        function onShowRequested() {
            win.present();
        }
        function onHideRequested() {
            win.hide();
        }
        function onToggleRequested() {
            win.visible && win.active ? win.hide() : win.present();
        }
        function onRefreshRequested() {
            core.refreshGenerations();
            core.checkFlakeUpdates();
        }
        function onSettingsRequested() {
            win.configure();
        }
    }

    App.Engine {
        id: core
        settings: cfg
        syncSettings: true
        executor: runner
        autoStart: false
        expanded: win.visible && !win.settingsOpen
        onConfigureRequested: win.configure()
    }

    // Tray icon and `nixdatifier --status` follow the engine.
    Binding {
        target: host
        property: "tooltip"
        value: core.toolTipMainText + "\n" + core.toolTipSubText
    }
    Binding {
        target: host
        property: "iconStyle"
        value: cfg.iconStyle
    }
    Binding {
        target: host
        property: "accent"
        value: core.accentColor
    }
    Binding {
        target: host
        property: "updates"
        value: cfg.compactShowBadge ? core.flakeUpdates.length : 0
    }
    Binding {
        target: host
        property: "working"
        value: core.isSpinning
    }
    Binding {
        target: host
        property: "motion"
        value: cfg.enableMotion
    }
    Binding {
        target: host
        property: "statusJson"
        value: {
            const state = core.isSpinning ? "working" : core.flakeUpdates.length > 0 ? "updates" : "idle";
            return JSON.stringify({
                "text": core.flakeUpdates.length > 0 ? String(core.flakeUpdates.length) : "",
                "alt": state,
                "class": state,
                "generation": core.activeGenNum,
                "updates": core.flakeUpdates.length,
                "tooltip": core.toolTipMainText + "\n" + core.toolTipSubText
            });
        }
    }

    App.ApplicationView {
        anchors.fill: parent
        engine: core
        visible: !win.settingsOpen
    }
    Rectangle {
        anchors.fill: parent
        visible: win.settingsOpen
        color: settingsEditor.tone.panel
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 14
            App.SettingsEditor {
                id: settingsEditor
                Layout.fillWidth: true
                Layout.fillHeight: true
                settings: draft
                currentVersion: host.version
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                App.SettingsButton {
                    tone: settingsEditor.tone
                    text: qsTr("Cancel")
                    onClicked: win.settingsOpen = false
                }
                App.SettingsButton {
                    tone: settingsEditor.tone
                    text: qsTr("Apply")
                    onClicked: win.applySettings()
                }
                App.SettingsButton {
                    tone: settingsEditor.tone
                    text: qsTr("OK")
                    primary: true
                    onClicked: {
                        win.applySettings();
                        win.settingsOpen = false;
                    }
                }
            }
        }
    }

    // Loads the real UI headless in CI and checks nothing failed to compile.
    Timer {
        id: smokeTimer
        interval: 1200
        onTriggered: {
            host.reportLoaded();
            Qt.quit();
        }
    }

    // Autostart (`--background`) can run before the panel has registered its
    // tray host. Wait briefly for one; without it the window stays visible, so
    // the app never disappears with no way to reach it.
    Timer {
        id: trayWait
        property int tries: 0
        interval: 1500
        repeat: true
        onTriggered: {
            if (host.checkTray()) {
                stop();
            } else if (++tries >= 8) {
                stop();
                win.present();
            }
        }
    }

    Component.onCompleted: {
        UI.Theme.iconResolver = name => name ? "image://nixicon/" + name : "";
        UI.Theme.systemTextColor = palette.windowText;
        UI.Theme.systemBackgroundColor = palette.window;
        loadConfig();
        if (win.smokeTest) {
            present();
            smokeTimer.start();
            return;
        }
        core.autoStart = true;
        core.start();
        if (!host.startHidden)
            present();
        else if (!host.checkTray())
            trayWait.start();
    }
}
