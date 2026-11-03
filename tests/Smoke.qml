import QtQuick
import QtQuick.Window
import "../package/contents/ui" as App
import "../package/contents/ui/shared" as UI

Window {
    id: win
    width: 600
    height: 740
    visible: true
    color: "#131923"
    App.Settings {
        id: cfg
        showCommandButtons: true
        showNotifications: false
    }
    Component {
        id: adapter
        QtObject {
            function exec(cmd, cb) {
                Qt.callLater(function () {
                    cb(cmd, "", "", 0);
                });
            }
        }
    }
    App.Engine {
        id: core
        settings: cfg
        executor: adapter
        autoStart: false
        expanded: true
    }
    App.ApplicationView {
        id: app
        anchors.fill: parent
        engine: core
    }
    App.SettingsEditor {
        id: editor
        anchors.fill: parent
        settings: cfg
        visible: false
    }
    Component.onCompleted: {
        core.generations = [
            {
                number: 661,
                timestamp: "2026-09-11 10:01:12",
                active: true,
                booted: false
            },
            {
                number: 660,
                timestamp: "2026-09-10 13:41:24",
                active: false,
                booted: true
            },
            {
                number: 659,
                timestamp: "2026-09-10 13:29:21",
                active: false,
                booted: false
            }
        ];
        core.activeGenNum = 661;
        core.bootedGenNum = 660;
        // Reproduce a light desktop theme around the custom dark widget.
        UI.Theme.systemTextColor = "#000000";
        UI.Theme.systemBackgroundColor = "#eff0f1";
        core.hostname = "muddyblack";
        core.lastActivationTime = "2026-09-11 10:01:12";
        core.lastFlakeCheckTime = "13:57";
        core.diskStoreBytes = 114500000000;
        core.diskReclaimableBytes = 24000000000;
        core.diskFreeBytes = 64100000000;
        core.nixosVersion = "26.05";
        core.uptime = "1h 35m";
        core.detailsCache = {
            661: {
                nixosVer: "26.05",
                kernelVer: "6.12.42",
                diff: [
                    {
                        name: "bitwarden-desktop",
                        type: "added",
                        oldVersion: "∅",
                        newVersion: "2026.8",
                        size: "16.2 KiB"
                    },
                    {
                        name: "aider-chat",
                        type: "removed",
                        oldVersion: "0.86.1",
                        newVersion: "∅",
                        size: "-2.9 MiB"
                    }
                ],
                closureBytes: 113700000000
            }
        };
        core.detailsCache = Object.assign({}, core.detailsCache, {
            660: {
                nixosVer: "26.05 · 2026-09-07",
                kernelVer: "6.12.42"
            },
            659: {
                nixosVer: "26.05 · 2026-09-07",
                kernelVer: "6.12.41"
            }
        });
        core.selectedGenNum = 661;
        core.flakeUpdates = [
            {
                input: "nixpkgs",
                oldRev: "abcdef0",
                newRev: "1234567",
                overrideRef: "github:NixOS/nixpkgs/1234567",
                url: "https://github.com/NixOS/nixpkgs"
            },
            {
                input: "home-manager",
                oldRev: "81c3c12",
                newRev: "52afd93",
                url: "https://github.com/nix-community/home-manager"
            },
            {
                input: "hyprland",
                oldRev: "c11765e",
                newRev: "31db77a",
                url: "https://github.com/hyprwm/Hyprland"
            }
        ];
        core.dryRunCache = {
            nixpkgs: {
                status: "ok",
                packages: core.detailsCache[661].diff.map((p, i) => Object.assign({
                        action: i % 3 === 0 ? "build" : "fetch"
                    }, p)),
                summary: {
                    downloadBytes: 2576980378,
                    unpackedBytes: 9126805504,
                    toBuild: 38,
                    toFetch: 412
                }
            }
        };
    }
    function findObject(item, name) {
        if (item.objectName === name)
            return item;
        for (let child of item.children || []) {
            const found = findObject(child, name);
            if (found)
                return found;
        }
        return null;
    }
    function capture(name) {
        app.grabToImage(function (r) {
            r.saveToFile("/tmp/nixdatifier-" + name + ".png");
        });
    }
    Timer {
        interval: 550
        running: true
        repeat: true
        property int stage: 0
        onTriggered: {
            stage++;
            if (stage === 1)
                win.capture("timeline");
            if (stage === 2) {
                core.activeViewMode = "updates";
                win.findObject(app, "updatesView").togglePreview(core.flakeUpdates[0]);
            }
            if (stage === 3)
                win.capture("updates");
            if (stage === 4)
                core.activeViewMode = "tools";
            if (stage === 5)
                win.capture("tools");
            if (stage === 6) {
                win.height = 480;
                core.pushToast("Could not reach: nixpkgs", true);
            }
            if (stage === 7)
                win.capture("tools-short");
            if (stage === 8)
                win.width = 380;
            if (stage === 9)
                win.capture("tools-narrow");
            if (stage === 10) {
                core.activeViewMode = "updates";
                core.isDryRunning = true;
            }
            if (stage === 11)
                win.capture("updates-narrow");
            if (stage === 12) {
                core.isDryRunning = false;
                core.activeViewMode = "timeline";
            }
            if (stage === 13)
                win.capture("timeline-narrow");
            if (stage === 14)
                core.activeViewMode = "diff";
            if (stage === 15)
                win.capture("compare-narrow");
            if (stage === 16)
                core.activeViewMode = "secrets";
            if (stage === 17)
                core.activeViewMode = "hash";
            if (stage === 18) {
                app.visible = false;
                editor.visible = true;
            }
            if (stage >= 19 && stage <= 21)
                editor.currentTab = stage - 18;
            if (stage === 22) {
                editor.visible = false;
                app.visible = true;
                win.width = 466;
                win.height = 666;
                cfg.customCommands = JSON.stringify([
                    {
                        label: "Update flake",
                        cmd: "nix flake update"
                    },
                    {
                        label: "Rebuild system",
                        cmd: "upnix"
                    }
                ]);
                app.openCommands();
            }
            if (stage === 23)
                win.capture("commands");
            if (stage === 24) {
                win.width = 380;
                win.height = 480;
                cfg.customCommands = JSON.stringify([
                    {
                        label: "Update flake",
                        cmd: "nix flake update"
                    },
                    {
                        label: "Rebuild system",
                        cmd: "nixos-rebuild switch --flake /etc/nixos#my-machine --show-trace"
                    }
                ]);
            }
            if (stage === 25)
                win.capture("commands-narrow");
            if (stage === 26) {
                app.closeCommands();
                core.activeViewMode = "timeline";
                win.findObject(app, "generationSearch").text = "no matching generation";
            }
            if (stage === 27)
                win.capture("empty-search");
            if (stage === 28)
                Qt.quit();
        }
    }
}
