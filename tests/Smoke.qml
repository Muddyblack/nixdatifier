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
            if (stage === 4) {
                core.optimiseStatus = {
                    isError: false,
                    autoOptimise: false,
                    timer: "absent"
                };
                core.optimiseEstimate = {
                    isError: false,
                    bytes: 3435973837,
                    sampledPaths: 1000,
                    totalPaths: 69690,
                    partial: false,
                    measuredAt: 0
                };
                core.actionHistory = [
                    {
                        timestamp: "2026-11-01T09:00:00Z",
                        action: "optimise",
                        label: "Optimising Nix store · 4096.00 MiB freed (52011 files)",
                        success: true,
                        output: "4096.00 MiB freed by hard-linking 52011 files"
                    }
                ];
                core.activeViewMode = "tools";
            }
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
                win.width = 600;
                win.height = 740;
                core.rebuildPlan = {
                    source: "nh",
                    custom: false,
                    commands: {
                        "switch": {
                            terminal: "nh os switch /etc/nixos",
                            panel: "nh os switch /etc/nixos --no-nom"
                        }
                    }
                };
                cfg.rebuildOutput = "panel";
                core.rebuildState = {
                    exists: true,
                    running: true,
                    mode: "switch",
                    command: "nh os switch /etc/nixos --no-nom",
                    phase: "building",
                    built: 14,
                    toBuild: 31,
                    fetched: 22,
                    toFetch: 40,
                    downloadBytes: 182000000,
                    current: "firefox-132.0",
                    startedAt: 1790000000,
                    lineCount: 3,
                    tail: ["these 31 derivations will be built:", "building '/nix/store/abc-firefox-132.0.drv'...", "copying path '/nix/store/def-glibc-2.40' from 'https://cache.nixos.org'..."]
                };
                core.isRebuilding = true;
                app.openRebuild();
            }
            if (stage === 27)
                win.capture("rebuild");
            if (stage === 28) {
                core.isRebuilding = false;
                core.rebuildState = null;
                app.closeRebuild();
                cfg.rebuildOutput = "terminal";
            }
            if (stage === 29) {
                core.activeViewMode = "timeline";
                win.findObject(app, "generationSearch").text = "no matching generation";
            }
            if (stage === 30)
                win.capture("empty-search");
            if (stage === 31) {
                win.findObject(app, "generationSearch").text = "";
                win.width = 520;
                win.height = 760;
                core.doctorResult = core.parseDoctor(["about\tinfo\tThis system\tnixdatifier 2.2.2 · NixOS 26.05 (Yarara) · Linux 6.12 · nix (Nix) 2.34.0\t\t\t\t\t", "nixos\tok\tRunning on NixOS\tNixOS 26.05 (Yarara)\t\t\t\t\t", "tools\tok\tRequired tools\tnix, nix-store, nix-env and jq found; runs as root with sudo\t\t\t\t\t", "profiles\tfail\tProfiles readable\t/nix/var/nix/profiles exists but cannot be listed: a permission problem, not a missing system.\tIt should be readable by everyone (drwxr-xr-x root).\tls -ld /nix/var/nix/profiles\t\tls /nix/var/nix/profiles\tls: cannot open directory '/nix/var/nix/profiles': Permission denied", "flake\tfail\tFlake path\tThe configured folder /home/me/nixos does not exist.\tPick your config folder in the settings, or clear the path to search the usual places.\tnixdatifier config set flake /path/to/your/flake\tconfigure\t\t", "optional\tinfo\tOptional tools\tNot found: fzf (the terminal menu). Everything else works without them.\t\t\t\t\t"].join("\n"));
                core.generations = [];
            }
            if (stage === 32)
                win.capture("doctor");
            if (stage === 33) {
                core.flakeUpdates = [];
                core.lastFlakeCheckTime = "";
                core.activeViewMode = "updates";
            }
            if (stage === 34)
                win.capture("doctor-updates");
            if (stage === 35) {
                win.width = 600;
                win.height = 900;
                core.activeViewMode = "health";
            }
            if (stage === 36) {
                // After the tab's own probes (the fake helpers answer nothing).
                core.healthResult = core.parseHealth("nixos=1\nrelease=26.05\neol=2026-12-31\nreboot_required=0\nkernel_running=6.12.42\nkernel_next=6.12.42\nnix=nix (Nix) 2.34.0\x1e\x1ehttps://cache.nixos.org\tok\t120\n");
                core.cveStatus = {
                    scanner: "vulnix",
                    whitelist: "",
                    whitelistError: "",
                    scanned: true
                };
                const cve = (id, score, severity) => ({
                            id,
                            score,
                            severity,
                            url: "https://nvd.nist.gov/vuln/detail/" + id,
                            description: "A heap overflow in the parser allows remote attackers to execute code.",
                            whitelisted: false
                        });
                core.cveResult = {
                    isError: false,
                    storePath: "/nix/store/x-nixos-system-host-26.05",
                    scannedAt: Date.now() / 1000 - 5400,
                    stale: false,
                    scanner: "vulnix 1.12.4",
                    whitelist: "/home/me/.config/vulnix/whitelist.toml",
                    counts: {
                        critical: 1,
                        high: 2,
                        medium: 3,
                        low: 0,
                        unknown: 1
                    },
                    cves: 7,
                    whitelisted: 2,
                    affectedPackages: 4,
                    packages: [
                        {
                            pname: "openssl",
                            version: "3.6.5",
                            severity: "critical",
                            cves: [cve("CVE-2026-31789", 9.8, "critical"), cve("CVE-2026-28390", 5.9, "medium")]
                        },
                        {
                            pname: "curl",
                            version: "8.22.0",
                            severity: "high",
                            cves: [cve("CVE-2026-1965", 7.5, "high"), cve("CVE-2026-3784", 7.4, "high"), cve("CVE-2026-0167", 4.3, "medium")]
                        },
                        {
                            pname: "zstd",
                            version: "1.5.7",
                            severity: "medium",
                            cves: [cve("CVE-2025-49002", 5.3, "medium")]
                        },
                        {
                            pname: "libtiff",
                            version: "4.7.0",
                            severity: "unknown",
                            cves: [cve("CVE-2025-8176", null, "unknown")]
                        }
                    ]
                };
            }
            if (stage === 37)
                win.capture("health-cve");
            if (stage === 38) {
                core.flakeUpdates = [
                    {
                        input: "nixpkgs",
                        oldRev: "abcdef0",
                        newRev: "1234567",
                        overrideRef: "github:NixOS/nixpkgs/1234567",
                        url: "https://github.com/NixOS/nixpkgs"
                    }
                ];
                core.dryRunCache = {
                    nixpkgs: {
                        status: "ok",
                        packages: [],
                        summary: {
                            downloadBytes: 734003200,
                            unpackedBytes: 2147483648,
                            toBuild: 0,
                            toFetch: 120
                        },
                        toplevel: "/nix/store/t-nixos-system-host-26.05.drv"
                    }
                };
                const entry = (id, score, severity, pkg, from, to) => ({
                            id,
                            score,
                            severity,
                            url: "https://nvd.nist.gov/vuln/detail/" + id,
                            package: pkg,
                            fromVersion: from,
                            toVersion: to
                        });
                core.cveDeltaCache = {
                    nixpkgs: {
                        status: "ok",
                        toplevel: "/nix/store/t-nixos-system-host-26.05.drv",
                        fixed: [entry("CVE-2026-31789", 9.8, "critical", "openssl", "3.6.5", "3.6.6"), entry("CVE-2026-1965", 7.5, "high", "curl", "8.22.0", "8.23.0"), entry("CVE-2026-28390", 5.9, "medium", "openssl", "3.6.5", "3.6.6")],
                        introduced: [entry("CVE-2026-40001", 6.1, "medium", "zstd", "1.5.7", "1.6.0")],
                        fixedCounts: {
                            critical: 1,
                            high: 1,
                            medium: 1
                        },
                        introducedCounts: {
                            medium: 1
                        }
                    }
                };
                core.activeViewMode = "updates";
                const view = win.findObject(app, "updatesView");
                view.openPreviews = {
                    nixpkgs: true
                };
            }
            if (stage === 39)
                win.capture("updates-cve");
            if (stage === 40)
                Qt.quit();
        }
    }
}
