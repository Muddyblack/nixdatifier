import QtQuick
import "shared" as UI

Item {
    id: root

    readonly property string toolTipMainText: root.hostname !== "" ? root.hostname : "Nixdatifier"
    readonly property string toolTipSubText: {
        var lines = [];

        if (root.activeGenNum > 0) {
            var genLine = "Generation #" + root.activeGenNum;
            if (root.bootedGenNum > 0 && root.bootedGenNum !== root.activeGenNum)
                genLine += " (active) · Booted: #" + root.bootedGenNum;
            lines.push(genLine);
        }
        if (root.runningTestBuild)
            lines.push("Running a test build that reverts on reboot");

        if (root.nixosVersion !== "")
            lines.push((root.isNixOS ? "NixOS " : "Nix ") + root.nixosVersion);

        var activeDetails = root.detailsCache[root.activeGenNum];
        if (activeDetails && activeDetails.kernelVer)
            lines.push("Kernel: " + activeDetails.kernelVer);

        if (root.uptime !== "")
            lines.push("Uptime: " + root.uptime);

        if (root.flakeUpdates.length > 0) {
            lines.push("");
            lines.push(root.flakeUpdates.length === 1 ? "1 flake update available:" : root.flakeUpdates.length + " flake updates available:");
            for (var i = 0; i < root.flakeUpdates.length; i++) {
                var u = root.flakeUpdates[i];
                lines.push("  • " + u.input + ": " + u.oldRev + " → " + u.newRev);
            }
        } else if (root.lastFlakeCheckTime !== "") {
            lines.push("Flake: up to date");
        }

        if (root.isBusy)
            lines.push("Status: Running action…");
        else if (!root.isNixOS || root.isLoadingGens)
            lines.push("Status: Loading generations…");
        else if (root.isCheckingFlake)
            lines.push("Status: Checking flake updates…");
        else if (root.isLoadingDetails)
            lines.push("Status: Loading generation details…");
        else if (root.isDryRunning)
            lines.push("Status: Calculating update preview…");
        else if (root.isProbingHash)
            lines.push("Status: Calculating hash…");
        else if (!root.isNixOS || root.isLoadingSecrets)
            lines.push("Status: Checking secrets…");

        return lines.join("\n");
    }

    required property var settings
    required property Component executor
    property bool expanded: false
    property bool pinned: false
    property bool autoStart: true
    property bool initialized: false
    property int activeJobs: 0
    signal configureRequested
    readonly property string busyLabel: isBusy ? (currentActionType || qsTr("Running command…")) : isCheckingFlake ? qsTr("Checking flake inputs…") : isDryRunning ? qsTr("Previewing package changes…") : isLoadingDetails || isLoadingPairDiff ? qsTr("Loading package changes…") : isProbingHash ? qsTr("Calculating hash…") : isProbingStoreUsage ? qsTr("Inspecting store path…") : isProbingDevEnv ? qsTr("Inspecting development environment…") : isLoadingSecrets ? qsTr("Inspecting secrets…") : isImpermanenceBusy ? qsTr("Inspecting persistent folders…") : _diskProbeRunning ? qsTr("Measuring Nix store…") : countingChanges ? qsTr("Counting package changes…") : activeJobs > 0 ? qsTr("Refreshing system information…") : ""

    // ── Script directory ──────────────────────────────────────────────────────
    readonly property string scriptDir: Qt.resolvedUrl("../tools/sh/").toString().replace("file://", "")

    // ── Theme / Config aliases ────────────────────────────────────────────────
    readonly property color accentColor: root.settings.accentColor || UI.Theme.highlightColor
    // Treat the previous default as the new neutral rail, preserving custom colors.
    readonly property color timelineColor: !root.settings.timelineColor || Qt.colorEqual(root.settings.timelineColor, "#9b5de5") ? "#71849b" : root.settings.timelineColor
    readonly property color textColor: !root.settings.useSystemTextColor ? (root.settings.customTextColor || "#ffffff") : root.settings.showBg ? UI.Theme.textOn(root.settings.bgColor || "#131923", UI.Theme.systemTextColor) : UI.Theme.systemTextColor
    property string resolvedFlakePath: ""
    property string lockFingerprint: ""
    property int flakeEpoch: 0
    readonly property string flakePath: root.resolvedFlakePath || (root.settings ? root.settings.flakePath : "") || ""
    function refreshFlakeContext(callback) {
        if (!root.isNixOS || !root.settings)
            return;
        const requested = root.settings.flakePath;
        sh(shq(root.scriptDir + "flake-context") + " " + shq(requested), function (cmd, out, err, code) {
            if (requested !== root.settings.flakePath)
                return;
            const lines = (out || "").trim().split("\n");
            const path = lines[0] || "", fingerprint = lines[1] || "";
            const changed = path !== root.resolvedFlakePath || fingerprint !== root.lockFingerprint;
            if (changed) {
                root.flakeEpoch++;
                root.dryRunCache = ({});
                root.releaseNotesCache = ({});
                root.flakeUpdates = [];
                root._lastFlakeCacheTs = 0;
                root.resolvedFlakePath = path;
                root.lockFingerprint = fingerprint;
            }
            if (callback)
                callback(changed);
        });
    }
    // Re-reads the flake context, then re-checks inputs when enabled — always
    // with `force`, otherwise only if the path or lock file changed.
    function syncFlakeContext(force) {
        refreshFlakeContext(function (changed) {
            if ((changed || force) && root.settings.showFlakeSection)
                root.checkFlakeUpdates();
        });
    }
    readonly property real fs: root.settings.fontScale || 1.0
    readonly property var customCommands: {
        try {
            return JSON.parse(root.settings.customCommands || "[]");
        } catch (e) {
            return [];
        }
    }
    // Empty string = auto-detect from KDE/XDG defaults in the terminal script
    readonly property string terminalApp: root.settings.commandTerminal || ""
    readonly property string iconStyle: root.settings.iconStyle || "colored"

    // ── Generations state ─────────────────────────────────────────────────────
    property var generations: []
    onGenerationsChanged: pruneGenerationCaches()
    property string activeStorePath: ""
    property string bootedStorePath: ""
    property bool runningTestBuild: false
    property int activeGenNum: -1
    property int bootedGenNum: -1
    property int selectedGenNum: -1
    property bool isLoadingGens: false
    property bool isLoadingDetails: false
    property bool isBusy: false
    property bool isProbingHash: false
    property bool isProbingStoreUsage: false
    property bool isProbingDevEnv: false
    property bool isLoadingSecrets: false
    property bool isLoadingConfigDiff: false

    // ── Active spinner state (panel spinner spins if any action or probe is running) ──
    readonly property bool isSpinning: root.activeJobs > 0 || root._diskProbeRunning || root.isBusy || root.isLoadingGens || root.isLoadingDetails || root.isLoadingPairDiff || root.isCheckingFlake || root.isDryRunning || root.isProbingHash || root.isProbingStoreUsage || root.isProbingDevEnv || root.isLoadingSecrets || root.isLoadingConfigDiff || root.isImpermanenceBusy

    property var detailsCache: ({})
    property string diffMode: "prev"

    // Cache of pairwise diffs for the Diff tab: key "A_B" -> { diff: [...] }
    property var pairDiffCache: ({})
    property bool isLoadingPairDiff: false

    // Config-diff cache: key = genNum → { status, message, repo, commitA, commitB, diff }
    property var configDiffCache: ({})
    property int pairDiffA: -1
    property int pairDiffB: -1

    // Icon cache: pkgName -> icon string (system theme name or "")
    property var iconCache: ({})

    // Meta cache: pkgName -> { url, source }
    //   source = "nixpkgs" | "plasmoid" | ""   ("" means we looked it up and
    //   found nothing — used to suppress repeated lookups)
    property var metaCache: ({})

    // These caches outlive the popup. Bound retained results across repeated
    // comparisons, package lookups and visits to different development folders.
    function boundedCache(cache, limit) {
        const keys = Object.keys(cache);
        if (keys.length <= limit)
            return cache;
        const kept = {};
        keys.slice(-limit).forEach(key => kept[key] = cache[key]);
        return kept;
    }

    function hasGeneration(number) {
        return root.generations.some(g => g.number === Number(number));
    }

    function pruneGenerationCaches() {
        const keep = (cache, valid) => {
            const next = {};
            Object.keys(cache).forEach(key => {
                if (valid(key))
                    next[key] = cache[key];
            });
            return next;
        };
        root.detailsCache = keep(root.detailsCache, root.hasGeneration);
        root.configDiffCache = keep(root.configDiffCache, root.hasGeneration);
        root.generationCounts = keep(root.generationCounts, root.hasGeneration);
        root.pairDiffCache = keep(root.pairDiffCache, key => key.split("_").every(root.hasGeneration));
        root.countsQueue = root.countsQueue.filter(pair => root.hasGeneration(pair.number));
    }

    // ── Action tracking (exposed to FullView for busy bar text) ───────────────
    property string currentActionType: ""

    // ── Flake state ───────────────────────────────────────────────────────────
    property var flakeUpdates: []
    property bool isCheckingFlake: false
    property string lastFlakeCheckTime: ""

    // Shell snippet that expands to the shared cache file path.
    // All widget instances on the same machine read/write this file.
    // Format: first line is a Unix timestamp (seconds); remaining lines are raw flake-probe TSV.
    // Written by whichever instance runs the probe first; others just read it.
    // Deliberately a shell expression, not a quoted path — evaluated inside sh() calls.
    readonly property string flakeCacheName: "flake-" + Qt.md5(root.flakePath) + "-" + (root.lockFingerprint || "none")
    readonly property string cacheDirExpr: '"${XDG_CACHE_HOME:-$HOME/.cache}/nixdatifier"'
    readonly property string flakeCacheExpr: root.cacheDirExpr + "/" + root.flakeCacheName

    // Unix timestamp of the cache snapshot currently applied to this instance.
    // Used by the sync timer to detect when another instance wrote a newer result.
    property int _lastFlakeCacheTs: 0

    // ── Dry-run preview state ─────────────────────────────────────────────────
    // key = input name, value = { status: "ok"|"error"|"loading", packages: [...] }
    // package: { action, name, oldVersion, newVersion }
    property var dryRunCache: ({})
    property bool isDryRunning: false

    // ── Upstream release notes per flake input ────────────────────────────────
    // key = input name, value = { status: "ok"|"error"|"loading", revisionKey,
    //   compareUrl, releases: [...], commits: [...], moreCommits, errorMsg }
    property var releaseNotesCache: ({})

    // ── System info ───────────────────────────────────────────────────────────
    property string hostname: ""
    property string nixosVersion: ""
    property string lastActivationTime: ""
    property string uptime: ""
    property string userFacePath: ""
    // Keep system operations disabled until sysinfo identifies the host.
    property bool isNixOS: false
    property bool systemDetected: false

    // ── Disk usage state ──────────────────────────────────────────────────────
    // All values in bytes (0 = unknown).
    property real diskStoreBytes: 0
    property real diskReclaimableBytes: -1
    property real diskFreeBytes: 0

    // ── Secrets state ─────────────────────────────────────────────────────────
    // deployedSecrets: live decrypted secrets (e.g. /run/secrets, auto-detected)
    // sourceSecrets:   encrypted source file (e.g. secrets.yaml in the flake repo)
    readonly property var emptySecrets: ({
            path: "",
            exists: false,
            lastModified: "",
            freshness: "",
            fileCount: 0,
            names: [],
            encKind: "",
            sopsVersion: "",
            recipientCount: 0,
            encType: ""
        })
    property var deployedSecrets: emptySecrets
    property var sourceSecrets: emptySecrets

    // ── Impermanence state ───────────────────────────────────────────────────
    // Folders that survive a reboot on a system whose root is wiped on boot.
    // Paths are kept in the helper's escaped form (\xHH for control characters)
    // so they can be handed back to it unchanged; *Text fields are for display.
    readonly property var emptyImpermanence: ({
            detected: false,
            volatile: false,
            volatileWhy: "",
            rootFs: "",
            areas: [],
            entries: []
        })
    property var impermanence: emptyImpermanence
    // { dir, area, total, files, newest, items: [...] } | { isError, value } | null
    property var impermanenceListing: null
    // { clamav, scope, findings: [...] } | { isError, value } | null
    property var impermanenceScan: null
    // { cutoff, days, temp: [...], stale: [...] } | { isError, value } | null
    property var impermanenceCleanup: null
    property bool isProbingImpermanence: false
    property bool isListingImpermanence: false
    property bool isScanningImpermanence: false
    property bool isAnalyzingImpermanence: false
    property bool isRemovingImpermanence: false
    // { <target path>: { kind, size, newest } } | { isError, value } | null
    property var impermanenceSizes: null
    property bool isMeasuringImpermanence: false
    readonly property bool isImpermanenceBusy: isMeasuringImpermanence || isProbingImpermanence || isListingImpermanence || isScanningImpermanence || isAnalyzingImpermanence || isRemovingImpermanence
    property int _impListSeq: 0

    // ── Hash tool state ───────────────────────────────────────────────────────
    property var hashResult: null   // { value: string, isError: bool } | null

    // ── Store usage tool state ───────────────────────────────────────────────
    // { path, exists, roots: [], referrers: [], closureBytes } | { isError: true, value: string } | null
    property var storeUsageResult: null
    property var devEnvProjects: []   // [{ dir, name, state }]
    property var devEnvResult: null   // parsed `devenv inspect`, or { isError, value }
    property int devEnvEpoch: 0       // bumped to bypass cached reads after a change
    property var shellPackages: ({})  // "dir#shell" -> { state, names }
    property var devSpace: []         // [{ dir, name, bytes, kind, modified }]
    property bool isMeasuringSpace: false
    property var healthResult: null
    property bool isProbingHealth: false

    // ── Rebuild history state ────────────────────────────────────────────────
    // Newest first, as returned by the "history list" script.
    property var actionHistory: []
    property bool isLoadingHistory: false

    // ── Pending confirmation ──────────────────────────────────────────────────
    property int pendingGenNum: -1
    property string pendingAction: ""
    property string pendingCleanup: ""

    // ── View state ────────────────────────────────────────────────────────────
    property string activeViewMode: "tools"

    // ── Toast queue ───────────────────────────────────────────────────────────
    property var toasts: []

    function pushToast(message, isError) {
        var arr = root.toasts.filter(t => t.err);
        var existing = -1;
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].msg === message) {
                existing = i;
                break;
            }
        }
        if (existing >= 0) {
            arr.splice(existing, 1);
        }
        arr.push({
            msg: message,
            err: isError || false,
            id: Date.now()
        });
        // Error toasts stay until dismissed; a recurring failure with varying
        // text must not grow the list for the whole session.
        root.toasts = arr.slice(-10);
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 5000
        repeat: false
        onTriggered: {
            var arr = root.toasts.slice();
            for (var i = 0; i < arr.length; i++) {
                if (!arr[i].err) {
                    arr.splice(i, 1);
                    break;
                }
            }
            root.toasts = arr;
            for (var j = 0; j < arr.length; j++) {
                if (!arr[j].err) {
                    restart();
                    return;
                }
            }
        }
    }

    TextEdit {
        id: clipboardHelper
        visible: false
    }

    function copyToClipboard(text) {
        clipboardHelper.text = text;
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        clipboardHelper.text = "";
        root.pushToast(qsTr("Copied to clipboard"), false);
    }

    // Desktop notification — survives popup close. Respects user's preference.
    // Uses notify-send (xdg-compatible) and an appropriate themed icon.
    function notify(title, body, isError) {
        if (!root.settings.showNotifications)
            return;
        const icon = isError ? "dialog-error" : "system-software-update";
        sh("notify-send -i " + icon + " " + shq(title) + " " + shq(body), null);
    }

    // ── Shell helper ──────────────────────────────────────────────────────────
    // Creates a fresh Shell.qml instance, runs cmd, calls cb(cmd,out,err,code), auto-cleans up.
    //
    // The Component itself is compiled once and reused: sh() is on the hot path
    // (every probe, every refresh, every cache read), and Qt.createComponent()
    // re-resolves and re-validates the URL on every call.
    function sh(cmd, cb, mutation) {
        if (!root.executor || root.executor.status !== Component.Ready) {
            Qt.callLater(function () {
                if (cb)
                    cb(cmd, "", qsTr("Process adapter unavailable"), 127);
            });
            return;
        }
        const tracked = cmd.indexOf(root.scriptDir) >= 0;
        if (tracked)
            root.activeJobs++;
        const job = root.executor.createObject(root);
        if (!job) {
            if (tracked)
                root.activeJobs--;
            Qt.callLater(function () {
                if (cb)
                    cb(cmd, "", qsTr("Could not start process"), 127);
            });
            return;
        }
        const actual = mutation ? shq(root.scriptDir + "run") + " mutate -- bash -c " + shq(cmd) : cmd;
        job.exec(actual, function (c, out, err, code) {
            if (tracked)
                root.activeJobs--;
            if (cb)
                cb(cmd, out, err, code);
        });
    }

    // Wrap a value as a single-quoted POSIX-shell literal. Returns `'…'` so
    // callers concatenate without adding their own quotes. Any embedded
    // single quote is closed, re-opened with an escaped quote, and the literal
    // resumes — the canonical safe-quoting idiom.
    // Use this for EVERY user/config/derivation-sourced string that becomes
    // part of a shell command. Concatenating with bare `'…'` plus `.replace`
    // is fragile and has been removed.
    function shq(value) {
        return "'" + String(value == null ? "" : value).replace(/'/g, "'\\''") + "'";
    }

    // Prefixes a system command with pkexec when the user enabled it.
    // Callers pass fixed command text plus validated integers only.
    function privileged(command) {
        return (root.settings.usePkexec ? "pkexec " : "") + command;
    }

    // Runs a script with the Nix tools on PATH, folding stderr into stdout so
    // failures reach the toast and the history entry.
    function systemShell(script) {
        return "sh -c \"export PATH=$PATH:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin; " + script + " 2>&1\"";
    }

    // ── Operations ────────────────────────────────────────────────────────────

    function refreshGenerations() {
        if (!root.isNixOS || root.isLoadingGens)
            return;
        root.isLoadingGens = true;
        sh(shq(root.scriptDir + "generations"), function (cmd, out, err, code) {
            root.isLoadingGens = false;
            // Activation time and version follow the generation list.
            root.probeSysInfo();
            const text = (out || "").trim();
            if (!text) {
                root.pushToast(qsTr("No generations found — is /nix/var/nix/profiles/ accessible?"), true);
                return;
            }
            root.parseGenerations(text);
            if (root.expanded)
                root.probeDiskUsage(false);
        });
    }

    function probeSysInfo() {
        sh(shq(root.scriptDir + "sysinfo"), function (cmd, out, err, code) {
            root.parseSysInfo(out || "");
        });
    }

    // Database sizes avoid walking store files. The shared cache also watches
    // store/profile changes; the short in-process guard coalesces open/refresh
    // events without hiding changes for the entire cache lifetime.
    readonly property int diskProbeTtlMs: 30 * 60 * 1000
    property real _lastDiskProbeMs: 0
    property real _lastDiskRequestMs: 0
    property bool _diskProbeRunning: false
    property bool _diskProbeDirty: false
    property string diskUsageError: ""

    function probeDiskUsage(force) {
        if (force)
            root._diskProbeDirty = true;
        if (root._diskProbeRunning)
            return;
        // Operations can finish after the window closes. Refresh on next open.
        if (root.autoStart && !root.expanded)
            return;
        const refresh = root._diskProbeDirty;
        if (!refresh && root._lastDiskRequestMs > 0 && Date.now() - root._lastDiskRequestMs < 5000)
            return;
        root._diskProbeDirty = false;
        root._diskProbeRunning = true;
        root._lastDiskRequestMs = Date.now();
        sh(shq(root.scriptDir + "run") + " cached disk:nar-v1 " + (refresh ? 0 : Math.round(root.diskProbeTtlMs / 1000)) + " -- " + shq(root.scriptDir + "diskusage"), function (cmd, out, err, code) {
            root._diskProbeRunning = false;
            // A mutation/forced refresh arrived during this snapshot. Do not
            // display it or lose the request; run one fresh probe afterward.
            if (root._diskProbeDirty) {
                root.probeDiskUsage(true);
                return;
            }
            const p = (out || "").trim().split("\x1e");
            const valid = p.length >= 3 && p.slice(0, 3).every(v => /^\d+$/.test(v.trim()) && isFinite(Number(v)));
            if (code !== 0 || !valid) {
                root.diskUsageError = (err || qsTr("Could not measure the Nix store.")).trim();
                root.probeFreeDiskSpace();
                if (refresh)
                    root.pushToast(root.diskUsageError, true);
                return;
            }
            root.diskUsageError = "";
            root.diskStoreBytes = Number(p[0]);
            root.diskReclaimableBytes = Number(p[1]);
            root.diskFreeBytes = Number(p[2]);
            root._lastDiskProbeMs = /^\d+$/.test(p[3] || "") ? Number(p[3]) * 1000 : Date.now();
            if (Date.now() - root._lastDiskProbeMs > 5000)
                root.probeFreeDiskSpace();
        });
    }

    property bool _diskFreeProbeRunning: false
    function probeFreeDiskSpace() {
        if (root._diskFreeProbeRunning)
            return;
        root._diskFreeProbeRunning = true;
        sh(shq(root.scriptDir + "diskusage") + " --free", function (cmd, out, err, code) {
            root._diskFreeProbeRunning = false;
            const value = (out || "").trim();
            if (code === 0 && /^\d+$/.test(value) && isFinite(Number(value)))
                root.diskFreeBytes = Number(value);
        });
    }

    function probeSecrets() {
        if (!root.isNixOS || root.isLoadingSecrets)
            return;
        root.isLoadingSecrets = true;
        sh(shq(root.scriptDir + "secrets") + " " + shq(root.settings.secretsPath) + " " + shq(root.settings.secretsSourcePath) + " " + shq(root.flakePath), function (cmd, out, err, code) {
            root.isLoadingSecrets = false;
            root.parseSopsInfo(out || "");
        });
    }

    function runHashProbe(mode, input) {
        root.hashResult = null;
        // mode comes from a fixed 5-string allowlist in the UI, but guard
        // defensively in case a future caller passes something else.
        const allowed = {
            url: 1,
            zip: 1,
            github: 1,
            file: 1,
            store: 1
        };
        if (!allowed[mode]) {
            root.hashResult = {
                value: "ERROR: invalid hash mode",
                isError: true
            };
            return;
        }
        if (root.isProbingHash)
            return;
        root.isProbingHash = true;
        sh(shq(root.scriptDir + "hash") + " " + shq(mode) + " " + shq(input), function (cmd, out, err, code) {
            root.isProbingHash = false;
            // Line 1 is the hash as the tool reports it, line 2 its SRI form.
            const lines = (out || "").trim().split("\n");
            const isError = code !== 0 || lines[0].startsWith("ERROR:");
            const sri = (lines[1] || "").trim();
            root.hashResult = {
                value: lines[0] || err || qsTr("No hash result returned"),
                sri: !isError && sri.startsWith("sha256-") ? sri : "",
                isError: isError
            };
        });
    }

    // ── Rebuild history ───────────────────────────────────────────────────────
    function loadHistory() {
        if (root.isLoadingHistory)
            return;
        root.isLoadingHistory = true;
        sh(shq(root.scriptDir + "history") + " list", function (cmd, out, err, code) {
            root.isLoadingHistory = false;
            let parsed = [];
            try {
                parsed = JSON.parse(out || "[]");
            } catch (e) {}
            root.actionHistory = Array.isArray(parsed) ? parsed : [];
        });
    }

    // Persists one run's outcome so it survives after its toast is dismissed.
    // action: a stable machine-readable kind (e.g. "switch", "gc", "hm-switch"),
    // NOT the already-localized currentActionType label.
    function recordHistoryEntry(action, label, genNum, exitCode, output) {
        // The kernel caps one shell argument at 128 KiB, and a GC or rebuild
        // log can exceed that — the entry would then be lost entirely. The
        // tail carries the result and any error, so keep that part.
        const limit = 16000;
        const text = String(output || "");
        const kept = text.length > limit ? "…\n" + text.slice(-limit) : text;
        sh(shq(root.scriptDir + "history") + " record " + shq(action) + " " + shq(label) + " " + parseInt(genNum, 10) + " " + parseInt(exitCode, 10) + " " + shq(kept), function () {
            root.loadHistory();
        });
    }

    function clearHistory() {
        sh(shq(root.scriptDir + "history") + " clear", function () {
            root.actionHistory = [];
        });
    }

    // ── Store usage tool ──────────────────────────────────────────────────────
    function probeStoreUsage(path) {
        if (root.isProbingStoreUsage)
            return;
        root.storeUsageResult = null;
        const clean = String(path || "").trim();
        // Client-side check mirrors the shell script's own validation — this is
        // just to fail fast with a friendly message before spawning a process.
        if (!/^\/nix\/store\/[0-9a-z]{32}-/.test(clean)) {
            root.storeUsageResult = {
                isError: true,
                value: qsTr("Not a /nix/store/... path")
            };
            return;
        }
        root.isProbingStoreUsage = true;
        sh(shq(root.scriptDir + "run") + " cached " + shq("storeusage:v2:" + clean) + " 300 -- " + shq(root.scriptDir + "store-usage") + " " + shq(clean), function (cmd, out, err, code) {
            root.isProbingStoreUsage = false;
            if (code !== 0) {
                root.storeUsageResult = {
                    isError: true,
                    value: (err || out || qsTr("Could not inspect store path")).trim()
                };
                return;
            }
            const p = (out || "").split("\x1e");
            const present = (p[3] || "").trim();
            if ((present !== "0" && present !== "1") || (present === "1" && !/^\d+$/.test((p[2] || "").trim()))) {
                root.storeUsageResult = {
                    isError: true,
                    value: qsTr("Incomplete store path inspection.")
                };
                return;
            }
            const exists = present === "1";
            root.storeUsageResult = {
                isError: false,
                path: (p[4] || clean).trim(),
                exists: exists,
                roots: (p[0] || "").split("\n").map(s => s.trim()).filter(s => s),
                referrers: (p[1] || "").split("\n").map(s => s.trim()).filter(s => s),
                closureBytes: parseInt((p[2] || "").trim(), 10) || 0
            };
        });
    }

    // ── Impermanence tool ─────────────────────────────────────────────────────
    // The data-disk choice is part of the command, so cached results of the
    // other choice are never reused.
    function impermanenceCommand(mode, arg) {
        const wide = root.settings.impermanenceAllDisks && (mode === "scan" || mode === "cleanup") ? "env NIXDATIFIER_IMP_ALL=1 " : "";
        return wide + shq(root.scriptDir + "impermanence") + " " + mode + " " + shq(root.settings.impermanencePaths || "") + (arg === undefined ? "" : " " + shq(arg));
    }

    // A helper's output parsed, or the reason it failed.
    function impermanenceResult(code, out, err, failure, parse) {
        return code === 0 ? parse(out || "") : {
            isError: true,
            value: (err || out || failure).trim()
        };
    }

    // Cheap: reads the mount table. Decides whether the tool is offered at all.
    function probeImpermanence() {
        if (root.isProbingImpermanence)
            return;
        root.isProbingImpermanence = true;
        sh(impermanenceCommand("detect"), function (cmd, out, err, code) {
            root.isProbingImpermanence = false;
            root.impermanence = code === 0 ? root.parseImpermanence(out || "") : root.emptyImpermanence;
        });
    }

    function parseImpermanence(raw) {
        const result = {
            detected: false,
            volatile: false,
            volatileWhy: "",
            rootFs: "",
            areas: [],
            entries: []
        };
        for (const line of raw.split("\n")) {
            const f = line.split("\t");
            if (f[0] === "volatile") {
                result.volatile = f[1] === "yes";
                result.volatileWhy = f[2] || "";
            } else if (f[0] === "rootfs") {
                result.rootFs = f[1] || "";
            } else if (f[0] === "persist") {
                result.areas.push({
                    kind: "persist",
                    path: f[1],
                    via: f[2] || "",
                    binds: parseInt(f[3], 10) || 0,
                    fsType: f[4] || "",
                    total: Number(f[5]) || 0,
                    used: Number(f[6]) || 0,
                    avail: Number(f[7]) || 0
                });
            } else if (f[0] === "mount") {
                result.areas.push({
                    kind: "mount",
                    path: f[1],
                    via: "",
                    binds: 0,
                    fsType: f[2] || "",
                    total: Number(f[3]) || 0,
                    used: Number(f[4]) || 0,
                    avail: Number(f[5]) || 0
                });
            } else if (f[0] === "entry") {
                result.entries.push({
                    kind: f[1],
                    target: f[2],
                    source: f[3] || ""
                });
            }
        }
        result.detected = result.areas.some(a => a.kind === "persist");
        return result;
    }

    // Size and last change of every persisted entry, keyed by where it appears.
    property bool _impSizesDirty: false
    function measureImpermanence(force) {
        if (root.isMeasuringImpermanence) {
            if (force)
                root._impSizesDirty = true;
            return;
        }
        root._impSizesDirty = false;
        root.isMeasuringImpermanence = true;
        sh(shq(root.scriptDir + "run") + " cached impermanence " + (force ? 0 : 300) + " -- " + impermanenceCommand("sizes"), function (cmd, out, err, code) {
            root.isMeasuringImpermanence = false;
            if (root._impSizesDirty) {
                root.measureImpermanence(true);
                return;
            }
            root.impermanenceSizes = root.impermanenceResult(code, out, err, qsTr("Could not measure the persistent folders"), root.parseImpermanenceSizes);
        });
    }

    function parseImpermanenceSizes(raw) {
        const sizes = {};
        for (const line of raw.split("\n")) {
            const f = line.split("\t");
            if (f[0] === "E" && f.length >= 6)
                sizes[f[4]] = {
                    kind: f[1],
                    size: Number(f[2]) || 0,
                    newest: parseInt(f[3], 10) || 0,
                    // ok | partial (a lower bound) | failed (unknown, not zero)
                    status: f[6] || "ok"
                };
        }
        return sizes;
    }

    // Folders already measured: dir -> { at, listing }. One walk also yields
    // the level below it, so stepping down or back up needs no new walk.
    property var _impListCache: ({})
    readonly property int _impListFresh: 10 * 60 * 1000
    readonly property int _impListMaxFolders: 300
    readonly property int _impListMaxRows: 60000

    // Whether a folder is open in the tab; work that finishes later (a delete)
    // must not start a walk for a folder the user already left.
    property bool _impFolderOpen: false

    // Lists one folder level. An empty path opens the first persistent root.
    function listImpermanence(path, force) {
        let dir = path;
        if (!dir) {
            const first = root.impermanence.areas.find(a => a.kind === "persist");
            if (!first)
                return;
            dir = first.path;
        }
        root._impFolderOpen = true;
        const known = force ? null : root._impListCache[dir];
        if (known && Date.now() - known.at < root._impListFresh) {
            root.cancelImpermanenceListing();
            root.impermanenceListing = known.listing;
            return;
        }
        const cancel = root.isListingImpermanence ? impermanenceCommand("cancel-list") + " && " : "";
        const seq = ++root._impListSeq;
        root.isListingImpermanence = true;
        sh(cancel + shq(root.scriptDir + "run") + " cached impermanence " + (force ? 0 : 600) + " -- " + impermanenceCommand("list", dir), function (cmd, out, err, code) {
            if (seq !== root._impListSeq)
                return;
            root.isListingImpermanence = false;
            const listing = root.impermanenceResult(code, out, err, qsTr("Could not read this folder"), root.parseImpermanenceListing);
            if (!listing.isError)
                root._rememberListing(listing, force);
            root.impermanenceListing = listing;
        });
    }

    // Nothing shows the remembered folders while the popup is closed, and one
    // walk can hold tens of thousands of rows. Let them go after a while, so an
    // idle widget keeps no such memory; the helper's own cache keeps the next
    // visit cheap, and a quick reopen still finds everything in place.
    function releaseImpermanenceMemory() {
        root._impListCache = ({});
        const listing = root.impermanenceListing;
        // Only read while a walk is remembered; the folder on screen keeps its rows.
        if (listing && !listing.isError)
            listing.children = ({});
    }
    Timer {
        objectName: "impermanenceReleaseTimer"
        interval: 120000
        running: !root.expanded && Object.keys(root._impListCache).length > 0
        onTriggered: root.releaseImpermanenceMemory()
    }

    // The folder view was left: forget it is open and stop its walk.
    function closeImpermanenceFolder() {
        root._impFolderOpen = false;
        root.cancelImpermanenceListing();
    }

    // Nobody waits for the walk in progress any more; stop it instead of
    // letting it keep the disk busy.
    function cancelImpermanenceListing() {
        if (!root.isListingImpermanence)
            return;
        ++root._impListSeq;
        root.isListingImpermanence = false;
        sh(impermanenceCommand("cancel-list"), null);
    }

    // `fresh`: measured just now on request (a refresh), not served from the
    // helper's cache. Then everything remembered below this folder is older
    // than what the walk just saw, so it is replaced or dropped.
    function _rememberListing(listing, fresh) {
        const now = Date.now();
        const cache = Object.assign({}, root._impListCache);
        if (fresh)
            for (const p of Object.keys(cache))
                if (p.indexOf(listing.dir + "/") === 0)
                    delete cache[p];
        // Rows held: its own items, plus the level below it for a real walk.
        // Derived entries share their arrays with that walk but count them
        // too, since they keep them alive once the walk's entry is dropped.
        const below = Object.keys(listing.children).reduce((sum, k) => sum + listing.children[k].length, 0);
        cache[listing.dir] = {
            at: now,
            rows: listing.items.length + below,
            listing: listing
        };
        const keep = {};
        keep[listing.dir] = true;
        for (const item of listing.items) {
            const items = listing.children[item.label];
            const own = cache[item.path];
            // A folder measured by its own walk knows one level more; keep that.
            if (item.kind !== "d" || !items || (own && !own.listing.derived && now - own.at < root._impListFresh))
                continue;
            keep[item.path] = true;
            cache[item.path] = {
                at: now,
                rows: items.length,
                listing: {
                    isError: false,
                    derived: true,
                    partial: listing.partial,
                    dir: item.path,
                    area: listing.area,
                    total: item.size,
                    files: item.count,
                    newest: item.newest,
                    items: items,
                    children: {}
                }
            };
        }
        // Bounded by folders and by rows: a few huge folders weigh as much as
        // many small ones. The oldest go first, then the smallest subfolders of
        // what was just measured (items come largest first); never the folder
        // itself. A subfolder dropped here is simply walked when opened.
        let count = Object.keys(cache).length;
        let rows = Object.keys(cache).reduce((sum, p) => sum + cache[p].rows, 0);
        const order = Object.keys(cache).filter(p => !keep[p]).sort((a, b) => cache[a].at - cache[b].at);
        for (let i = listing.items.length - 1; i >= 0; --i)
            if (keep[listing.items[i].path])
                order.push(listing.items[i].path);
        while ((count > root._impListMaxFolders || rows > root._impListMaxRows) && order.length) {
            const p = order.shift();
            rows -= cache[p].rows;
            delete cache[p];
            --count;
        }
        root._impListCache = cache;
    }

    function _listingItem(dir, f, at) {
        return {
            kind: f[at],
            size: Number(f[at + 1]) || 0,
            count: parseInt(f[at + 2], 10) || 0,
            newest: parseInt(f[at + 3], 10) || 0,
            mtime: parseInt(f[at + 4], 10) || 0,
            mode: f[at + 5],
            owner: f[at + 6],
            flags: f[at + 7],
            link: UI.Theme.unescapePath(f[at + 8]),
            name: UI.Theme.unescapePath(f[at + 9]),
            label: f[at + 9],
            path: dir + "/" + f[at + 9]
        };
    }

    function parseImpermanenceListing(raw) {
        const listing = {
            isError: false,
            dir: "",
            area: "",
            total: 0,
            files: 0,
            newest: 0,
            items: [],
            partial: false,
            moreCount: 0,
            moreBytes: 0,
            children: {}   // child label -> its items, from the same walk
        };
        const tooMany = {};
        for (const line of raw.split("\n")) {
            const f = line.split("\t");
            if (f[0] === "D") {
                listing.dir = f[1];
                listing.area = f[2];
                listing.total = Number(f[3]) || 0;
                listing.files = parseInt(f[4], 10) || 0;
                listing.newest = parseInt(f[5], 10) || 0;
            } else if (f[0] === "C" && f.length >= 11) {
                listing.items.push(root._listingItem(listing.dir, f, 1));
            } else if (f[0] === "G" && f.length >= 12) {
                const kids = listing.children[f[1]] || (listing.children[f[1]] = []);
                kids.push(root._listingItem(listing.dir + "/" + f[1], f, 2));
            } else if (f[0] === "X") {
                tooMany[f[1]] = true;
            } else if (f[0] === "P") {
                // Some folders below could not be read: totals are lower bounds.
                listing.partial = true;
            } else if (f[0] === "R") {
                // The smallest entries of a huge folder, summed up, not listed.
                listing.moreCount = parseInt(f[1], 10) || 0;
                listing.moreBytes = Number(f[2]) || 0;
            }
        }
        // Folders with too many entries to list here are walked when opened;
        // folders with none at all are known to be empty.
        for (const label of Object.keys(tooMany))
            delete listing.children[label];
        for (const item of listing.items)
            if (item.kind === "d" && !tooMany[item.label] && !listing.children[item.label])
                listing.children[item.label] = [];
        return listing;
    }

    function scanImpermanence(force) {
        if (root.isScanningImpermanence)
            return;
        root.isScanningImpermanence = true;
        sh(shq(root.scriptDir + "run") + " cached impermanence " + (force ? 0 : 3600) + " -- " + impermanenceCommand("scan", "14"), function (cmd, out, err, code) {
            root.isScanningImpermanence = false;
            root.impermanenceScan = root.impermanenceResult(code, out, err, qsTr("Could not scan the persistent folders"), root.parseImpermanenceScan);
        });
    }

    function parseImpermanenceScan(raw) {
        const scan = {
            isError: false,
            clamav: false,
            scope: "",
            findings: []
        };
        for (const line of raw.split("\n")) {
            const f = line.split("\t");
            if (f.length < 4)
                continue;
            if (f[0] === "meta") {
                if (f[1] === "clamav")
                    scan.clamav = f[3] === "available";
                else if (f[1] === "scope")
                    scan.scope = f[3];
                continue;
            }
            scan.findings.push({
                severity: f[0],
                category: f[1],
                path: f[2],
                pathText: UI.Theme.unescapePath(f[2]),
                detail: UI.Theme.unescapePath(f[3])
            });
        }
        return scan;
    }

    function analyzeImpermanence(force) {
        if (root.isAnalyzingImpermanence)
            return;
        root.isAnalyzingImpermanence = true;
        const days = Math.max(14, root.settings.impermanenceStaleDays || 180);
        sh(shq(root.scriptDir + "run") + " cached impermanence " + (force ? 0 : 3600) + " -- " + impermanenceCommand("cleanup", String(days)), function (cmd, out, err, code) {
            root.isAnalyzingImpermanence = false;
            root.impermanenceCleanup = root.impermanenceResult(code, out, err, qsTr("Could not analyze the persistent folders"), raw => root.parseImpermanenceCleanup(raw, days));
        });
    }

    function parseImpermanenceCleanup(raw, days) {
        const result = {
            isError: false,
            cutoff: 0,
            days: days,
            temp: [],
            stale: []
        };
        for (const line of raw.split("\n")) {
            const f = line.split("\t");
            if (f[0] === "M") {
                result.cutoff = parseInt(f[1], 10) || 0;
            } else if (f[0] === "T" && f.length >= 5) {
                result.temp.push({
                    label: f[1],
                    size: Number(f[2]) || 0,
                    newest: parseInt(f[3], 10) || 0,
                    path: f[4],
                    pathText: UI.Theme.unescapePath(f[4]),
                    partial: f[5] === "partial"
                });
            } else if (f[0] === "S" && f.length >= 6) {
                result.stale.push({
                    kind: f[1],
                    size: Number(f[2]) || 0,
                    count: parseInt(f[3], 10) || 0,
                    newest: parseInt(f[4], 10) || 0,
                    path: f[5],
                    pathText: UI.Theme.unescapePath(f[5])
                });
            }
        }
        result.temp.sort((a, b) => b.size - a.size);
        result.stale.sort((a, b) => b.size - a.size);
        return result;
    }

    // Deletes one path inside a persistent folder. The helper refuses anything
    // that would break the system; root-owned content is retried through pkexec.
    function removeImpermanencePath(path, name) {
        removeImpermanencePaths([
            {
                path: path,
                name: name
            }
        ]);
    }

    // Deletes paths one after another and reports them together. Deletes asked
    // for while others are still running join the queue instead of waiting.
    // Per-path progress remains visible until the helper confirms the outcome.
    property var impermanenceRemovalStates: ({})
    // `paths` is one path or a list, so queuing a large batch copies the map once.
    function setImpermanenceRemovalState(paths, state, message) {
        const next = Object.assign({}, root.impermanenceRemovalStates);
        for (const path of [].concat(paths)) {
            delete next[path];   // re-added last, so key order is age order
            next[path] = {
                state: state,
                message: message || ""
            };
        }
        // Failures stay for review, but not forever: keep the latest 200.
        const failed = Object.keys(next).filter(p => next[p].state === "failed");
        for (const p of failed.slice(0, Math.max(0, failed.length - 200)))
            delete next[p];
        root.impermanenceRemovalStates = next;
    }
    property var _impRemoval: null   // { queue, done, removed: [paths], failures }
    function removeImpermanencePaths(items) {
        const seen = {};
        const add = (items || []).filter(function (i) {
            if (!i || !i.path || seen[i.path])
                return false;
            seen[i.path] = true;
            const current = root.impermanenceRemovalStates[i.path];
            return !current || (current.state !== "queued" && current.state !== "deleting");
        });
        if (add.length === 0)
            return;
        root.setImpermanenceRemovalState(add.map(i => i.path), "queued", "");
        if (root._impRemoval) {
            root._impRemoval.queue = root._impRemoval.queue.concat(add);
            return;
        }
        root._impRemoval = {
            queue: add,
            done: [],
            removed: [],
            failures: []
        };
        root.isRemovingImpermanence = true;
        root._stepImpermanenceRemoval();
    }

    function _stepImpermanenceRemoval() {
        const run = root._impRemoval;
        if (run.queue.length === 0) {
            root._reportImpermanenceRemoval(run);
            const remaining = Object.assign({}, root.impermanenceRemovalStates);
            for (const path of run.removed)
                delete remaining[path];
            root.impermanenceRemovalStates = remaining;
            root._impRemoval = null;
            root.isRemovingImpermanence = false;
            return;
        }
        const item = run.queue.shift();
        const name = item.name || UI.Theme.unescapePath(item.path);
        run.done.push(item);
        root.setImpermanenceRemovalState(item.path, "deleting", "");
        root._removeImpermanenceOne(item.path, function (code, text) {
            root.recordHistoryEntry("impermanence-remove", qsTr("Delete %1").arg(name), -1, code, text || UI.Theme.unescapePath(item.path));
            if (code === 0) {
                run.removed.push(item.path);
                root.setImpermanenceRemovalState(item.path, "deleted", "");
            } else {
                const why = code === 77 ? qsTr("Permission denied. Enable pkexec in Settings to retry.") : (text || qsTr("Deletion failed")).replace(/^ERROR:\s*/, "");
                root.setImpermanenceRemovalState(item.path, "failed", why);
                run.failures.push({
                    name: name,
                    code: code,
                    text: text
                });
            }
            root._stepImpermanenceRemoval();
        });
    }

    // Root-owned content is retried through pkexec when that is allowed.
    function _removeImpermanenceOne(path, done) {
        const base = impermanenceCommand("remove", path);
        sh(base, function (c, out, err, code) {
            if (code === 77 && root.settings.usePkexec) {
                sh(root.privileged(base), function (c2, out2, err2, code2) {
                    done(code2, (err2 || out2 || "").trim());
                });
                return;
            }
            done(code, (err || out || "").trim());
        });
    }

    function _reportImpermanenceRemoval(run) {
        const total = run.done.length, removed = run.removed.length;
        if (run.failures.length > 0) {
            const f = run.failures[0];
            const why = f.code === 77 ? qsTr("Some of it belongs to another user. Enable pkexec in Settings to delete it.") : (f.text || qsTr("Could not delete %1").arg(f.name)).replace(/^ERROR:\s*/, "");
            root.pushToast(total === 1 ? why : qsTr("Deleted %1 of %2. %3: %4").arg(removed).arg(total).arg(f.name).arg(why), true);
        } else {
            root.pushToast(total === 1 ? qsTr("Deleted %1").arg(run.done[0].name || UI.Theme.unescapePath(run.done[0].path)) : qsTr("Deleted %1 items").arg(removed), false);
        }
        // Even a delete that failed half-way may have removed part of its
        // contents, so cached sizes are stale after any attempt. Folder totals
        // up the tree changed too; measure again when visited.
        root._impListCache = ({});
        // Drop what is gone from the results on hand instead of scanning again:
        // the scan and the analysis are slow, and nothing else changed.
        const gone = p => run.removed.some(r => p === r || p.indexOf(r + "/") === 0);
        const listing = root.impermanenceListing;
        if (listing && !listing.isError)
            root.impermanenceListing = Object.assign({}, listing, {
                items: listing.items.filter(i => !gone(i.path))
            });
        const cleanup = root.impermanenceCleanup;
        if (cleanup && !cleanup.isError)
            root.impermanenceCleanup = Object.assign({}, cleanup, {
                temp: cleanup.temp.filter(t => !gone(t.path)),
                stale: cleanup.stale.filter(s => !gone(s.path))
            });
        const scan = root.impermanenceScan;
        if (scan && !scan.isError)
            root.impermanenceScan = Object.assign({}, scan, {
                findings: scan.findings.filter(f => !f.path || !gone(f.path))
            });
        sh(shq(root.scriptDir + "run") + " invalidate impermanence", function () {
            // Do not bring back a folder the user left while deleting.
            const current = root.impermanenceListing;
            if (root._impFolderOpen && root.expanded && root.activeViewMode === "impermanence" && current && !current.isError)
                root.listImpermanence(current.dir, true);
            if (root.impermanenceSizes)
                root.measureImpermanence(true);
        });
    }

    function openImpermanencePath(path) {
        sh("xdg-open " + shq(UI.Theme.unescapePath(path)), null);
    }

    // Signature-based scanning needs ClamAV; it runs in a terminal so the
    // progress and verdicts are visible.
    function runClamScan() {
        if (root.isBusy)
            return;
        const roots = root.impermanence.areas.map(a => shq(a.path)).join(" ");
        if (!roots)
            return;
        root.isBusy = true;
        root.currentActionType = qsTr("Scanning with ClamAV…");
        const cmd = "clamscan --recursive --infected --exclude-dir='/(var/lib/docker|var/lib/containers)' " + roots;
        sh(shq(root.scriptDir + "terminal") + " " + shq(root.terminalApp) + " " + shq("") + " " + shq(cmd), function (c, out, err, code) {
            root.isBusy = false;
            // clamscan exits 1 when it found something, which is a result, not a failure.
            const message = code === 0 ? qsTr("ClamAV found nothing in the persistent folders.") : code === 1 ? qsTr("ClamAV reported infected files. Review the terminal output.") : qsTr("ClamAV exited with status %1. %2").arg(code).arg((err || "").trim());
            root.recordHistoryEntry("clamscan", qsTr("ClamAV scan"), -1, code === 1 ? 0 : code, qsTr("(output not captured — command ran in a terminal window)"));
            root.pushToast(message, code > 1);
            root.notify("Nixdatifier", message, code > 0);
        }, true);
    }

    // ── Development environments (direnv / flakes), independent of NixOS ──────
    function discoverDevEnvs() {
        sh(shq(root.scriptDir + "devenv") + " discover", function (cmd, out, err, code) {
            if (code !== 0)
                return;
            root.devEnvProjects = (out || "").split("\n").filter(l => l.indexOf("\t") > 0).map(function (line) {
                const f = line.split("\t");
                return {
                    dir: f[0],
                    name: f[0].split("/").filter(x => x).pop() || f[0],
                    state: f[1]
                };
            });
        });
    }
    function parseDevEnv(text) {
        const parts = (text || "").split("\x1e");
        const meta = {};
        for (const line of (parts[0] || "").split("\n")) {
            const i = line.indexOf("=");
            if (i > 0)
                meta[line.slice(0, i)] = line.slice(i + 1);
        }
        const list = v => v ? v.split(",") : [];
        const num = v => parseInt(v, 10) || 0;
        return {
            isError: false,
            dir: meta.dir || "",
            name: meta.name || "",
            direnvVersion: meta.direnv || "",
            envrcPath: meta.envrc_path || "",
            envrcState: meta.envrc_state || "none",
            envrcUses: list(meta.envrc_uses),
            envrc: (parts[1] || "").replace(/\n+$/, ""),
            cachePath: meta.cache_dir || "",
            cacheTime: num(meta.cache_mtime),
            cacheKb: num(meta.cache_size),
            files: list(meta.files),
            description: meta.description || "",
            lockOldest: num(meta.lock_oldest),
            lockNewest: num(meta.lock_newest),
            // devShells need a flake evaluation, so they arrive after the rest.
            shellsState: "loading",
            inputs: (parts[2] || "").split("\n").filter(l => l).map(function (line) {
                const f = line.split("\t");
                return {
                    name: f[0],
                    type: f[1] || "",
                    source: f[2] || "",
                    ref: f[3] || "",
                    rev: f[4] || "",
                    modified: num(f[5]),
                    follows: f[6] || ""
                };
            }),
            shells: (parts[3] || "").split("\n").map(s => s.trim()).filter(s => s)
        };
    }
    function probeDevEnv(path) {
        const clean = String(path || "").trim();
        root.devEnvResult = null;
        if (clean === "" || root.isProbingDevEnv)
            return;
        root.isProbingDevEnv = true;
        sh(shq(root.scriptDir + "run") + " cached " + shq("devenv:" + clean + ":" + root.devEnvEpoch) + " 45 -- " + shq(root.scriptDir + "devenv") + " inspect " + shq(clean), function (cmd, out, err, code) {
            root.isProbingDevEnv = false;
            if (code !== 0) {
                root.devEnvResult = {
                    isError: true,
                    value: (err || out || qsTr("Could not inspect this folder")).trim()
                };
                return;
            }
            const result = root.parseDevEnv(out);
            root.devEnvResult = result;
            // Shown at once; the slow flake evaluation fills the shells in.
            if (result.files.indexOf("flake.nix") >= 0)
                root.loadDevShells(result.dir);
            else
                root.devEnvResult = Object.assign({}, result, {
                    shellsState: "none"
                });
        });
    }
    function loadDevShells(dir) {
        sh(shq(root.scriptDir + "run") + " cached " + shq("devshells:" + dir + ":" + root.devEnvEpoch) + " 180 -- " + shq(root.scriptDir + "devenv") + " shells " + shq(dir), function (cmd, out, err, code) {
            const current = root.devEnvResult;
            if (!current || current.isError || current.dir !== dir)
                return;
            root.devEnvResult = Object.assign({}, current, {
                shells: code === 0 ? (out || "").split("\n").map(s => s.trim()).filter(s => s) : [],
                shellsState: code === 0 ? "ok" : "unavailable"
            });
        });
    }
    // Packages inside one devShell, fetched when the user asks (it evaluates).
    function loadShellPackages(dir, name) {
        const key = dir + "#" + name;
        if (root.shellPackages[key] && root.shellPackages[key].state !== "error")
            return;
        const put = value => {
            const next = Object.assign({}, root.shellPackages);
            next[key] = value;
            root.shellPackages = root.boundedCache(next, 32);
        };
        put({
            state: "loading",
            names: []
        });
        sh(shq(root.scriptDir + "run") + " cached " + shq("shellpkgs:" + key) + " 600 -- " + shq(root.scriptDir + "devenv") + " shellpkgs " + shq(dir) + " " + shq(name), function (cmd, out, err, code) {
            put(code === 0 ? {
                state: "ok",
                names: (out || "").split("\n").map(s => s.trim()).filter(s => s)
            } : {
                state: "error",
                names: []
            });
        });
    }
    // Actions on a project. Terminal ones stay visible, like custom commands.
    function devEnvAction(kind, dir) {
        if (!dir)
            return;
        const refresh = () => {
            root.devEnvEpoch++;
            root.probeDevEnv(dir);
        };
        if (kind === "allow") {
            sh("direnv allow " + shq(dir), function (cmd, out, err, code) {
                root.pushToast(code === 0 ? qsTr("Allowed %1").arg(dir) : (err || qsTr("direnv allow failed")).trim(), code !== 0);
                refresh();
            });
            return;
        }
        const commands = {
            "shell": "if command -v direnv >/dev/null 2>&1 && [ -f .envrc ]; then direnv exec . \"$SHELL\"; else nix develop; fi",
            "update": "nix flake update"
        };
        if (!commands[kind])
            return;
        sh(shq(root.scriptDir + "terminal") + " " + shq(root.terminalApp) + " " + shq(dir) + " " + shq(commands[kind]), function (cmd, out, err, code) {
            if (code !== 0)
                root.pushToast(qsTr("The terminal exited with status %1. %2").arg(code).arg((err || "").trim()), true);
            if (kind === "update")
                refresh();
        });
    }
    function measureDevSpace() {
        if (root.isMeasuringSpace)
            return;
        root.isMeasuringSpace = true;
        sh(shq(root.scriptDir + "run") + " cached " + shq("devspace:" + root.devEnvEpoch) + " 600 -- " + shq(root.scriptDir + "devenv") + " space", function (cmd, out, err, code) {
            root.isMeasuringSpace = false;
            if (code !== 0)
                return;
            root.devSpace = (out || "").split("\n").filter(l => l.indexOf("\t") > 0).map(function (line) {
                const f = line.split("\t");
                return {
                    dir: f[0],
                    name: f[0].split("/").filter(x => x).pop() || f[0],
                    bytes: parseInt(f[1], 10) || 0,
                    kind: f[2] || "files",
                    modified: parseInt(f[3], 10) || 0
                };
            });
        });
    }
    function clearDevCache(dir) {
        sh(shq(root.scriptDir + "devenv") + " clear " + shq(dir), function (cmd, out, err, code) {
            root.pushToast(code === 0 ? qsTr("Cleared the cache of %1. The next garbage collection can reclaim its space.").arg(dir) : (err || qsTr("Could not clear the cache")).trim(), code !== 0);
            root.devEnvEpoch++;
            root.devSpace = root.devSpace.filter(p => p.dir !== dir || code !== 0);
            root.probeDevEnv(dir);
        });
    }

    // ── System health: the quiet failures on a Nix system ─────────────────────
    function parseHealth(text) {
        const parts = (text || "").split("\x1e");
        const meta = {};
        for (const line of (parts[0] || "").split("\n")) {
            const i = line.indexOf("=");
            if (i > 0)
                meta[line.slice(0, i)] = line.slice(i + 1);
        }
        const num = v => parseInt(v, 10) || 0;
        const rows = (part, min) => (part || "").split("\n").map(l => l.split("\t")).filter(f => f.length >= min && f[0]);
        return {
            isError: false,
            nixos: meta.nixos === "1",
            release: meta.release || "",
            eol: meta.eol || "",
            unstable: meta.unstable === "1",
            rebootKnown: "reboot_required" in meta,
            rebootRequired: meta.reboot_required === "1",
            kernelRunning: meta.kernel_running || "",
            kernelNext: meta.kernel_next || "",
            bootTotalKb: num(meta.boot_total_kb),
            bootAvailKb: num(meta.boot_avail_kb),
            bootEntries: "boot_entries" in meta ? num(meta.boot_entries) : -1,
            nixVersion: meta.nix || "",
            experimental: meta.experimental || "",
            trustedUsers: meta.trusted_users || "",
            channels: num(meta.channels),
            hmGenerations: num(meta.hm_generations),
            hmNewest: num(meta.hm_newest),
            profileGenerations: num(meta.profile_generations),
            profileNewest: num(meta.profile_newest),
            failedUnits: root.groupFailedUnits(rows(parts[1], 2).map(f => ({
                        scope: f[0],
                        name: f[1],
                        result: f[2] || "",
                        why: f[3] || ""
                    }))),
            caches: rows(parts[2], 3).map(f => ({
                        url: f[0],
                        status: f[1],
                        ms: num(f[2])
                    }))
        };
    }
    // A failed `x.path` and the `x.service` it triggers are one problem: show
    // them as one row. The service's own message wins, it says what went wrong.
    function groupFailedUnits(units) {
        const out = [];
        for (const unit of units) {
            const base = unit.name.replace(/\.(path|service)$/, "");
            const isPath = unit.name.endsWith(".path");
            const pair = isPath ? units.find(u => u.scope === unit.scope && u.name === base + ".service") : null;
            if (pair)
                continue; // folded into its service below
            const path = unit.name.endsWith(".service") ? units.find(u => u.scope === unit.scope && u.name === base + ".path") : null;
            out.push(Object.assign({}, unit, {
                paired: !!path,
                // The path unit's result is the real reason when the service itself exited fine.
                result: path && path.result && unit.result !== path.result && unit.result === "success" ? path.result : unit.result,
                command: "systemctl " + (unit.scope === "user" ? "--user " : "") + "status " + unit.name
            }));
        }
        return out;
    }
    function probeHealth(force) {
        if (root.isProbingHealth)
            return;
        root.isProbingHealth = true;
        sh(shq(root.scriptDir + "run") + " cached " + shq("health") + " " + (force ? 0 : 120) + " -- " + shq(root.scriptDir + "health"), function (cmd, out, err, code) {
            root.isProbingHealth = false;
            root.healthResult = code === 0 ? root.parseHealth(out) : {
                isError: true,
                value: (err || out || qsTr("Could not check the system")).trim()
            };
        });
    }

    function getPreviousGen(genNum) {
        for (let i = 0; i < root.generations.length; i++) {
            if (root.generations[i].number === genNum) {
                return (i + 1 < root.generations.length) ? root.generations[i + 1].number : root.generations[i].previousNumber || null;
            }
        }
        return null;
    }

    property var generationCounts: ({})
    property var countsQueue: []
    property bool countingChanges: false
    function countPair(genNum) {
        const i = generations.findIndex(g => g.number === genNum);
        const target = i >= 0 ? generations[i] : null;
        const base = i >= 0 ? generations[i + 1] || (target.previousStorePath ? {
                number: target.previousNumber,
                storePath: target.previousStorePath
            } : null) : null;
        if (!target || !base || !target.storePath || !base.storePath)
            return null;
        return {
            number: genNum,
            baseNum: base.number,
            target: target.storePath,
            base: base.storePath,
            key: target.storePath + "|" + base.storePath
        };
    }
    function requestGenerationCounts(genNum) {
        const pair = countPair(genNum);
        if (!pair)
            return;
        const existing = generationCounts[genNum];
        if (existing && existing.key === pair.key && (existing.status !== "error" || Date.now() - existing.checked < 60000))
            return;
        const next = Object.assign({}, generationCounts);
        next[genNum] = {
            key: pair.key,
            baseNum: pair.baseNum,
            status: "loading"
        };
        generationCounts = next;
        countsQueue = countsQueue.concat([pair]);
    }
    Timer {
        interval: 80
        repeat: true
        running: root.expanded && root.activeViewMode === "timeline" && !root.isBusy && !root.countingChanges && root.countsQueue.length > 0
        onTriggered: root.loadNextGenerationCounts()
    }
    function loadNextGenerationCounts() {
        if (countingChanges || !expanded || activeViewMode !== "timeline" || isBusy || !countsQueue.length)
            return;
        const pair = countsQueue[0];
        countsQueue = countsQueue.slice(1);
        const current = countPair(pair.number);
        if (!current || current.key !== pair.key)
            return;
        countingChanges = true;
        sh(shq(scriptDir + "run") + " cached generation-counts 604800 -- " + shq(scriptDir + "change-counts") + " " + shq(pair.target) + " " + shq(pair.base), function (cmd, out, err, code) {
            root.countingChanges = false;
            const live = root.countPair(pair.number);
            if (!live || live.key !== pair.key)
                return;
            let counts = null;
            try {
                counts = JSON.parse(out);
            } catch (e) {}
            const valid = code === 0 && counts && ["added", "removed", "changed"].every(k => Number.isInteger(counts[k]) && counts[k] >= 0);
            const next = Object.assign({}, root.generationCounts);
            next[pair.number] = Object.assign({
                key: pair.key,
                baseNum: pair.baseNum,
                checked: Date.now(),
                status: valid ? "ok" : "error"
            }, valid ? counts : {});
            root.generationCounts = next;
        });
    }

    function loadConfigDiff(genNum) {
        if (root.configDiffCache[genNum] !== undefined)
            return;
        const prev = root.getPreviousGen(genNum);
        const baseNum = prev !== null ? prev : genNum;
        root.isLoadingConfigDiff = true;
        sh(shq(root.scriptDir + "config-diff") + " " + baseNum + " " + genNum, function (cmd, out, err, code) {
            root.isLoadingConfigDiff = false;
            if (!root.hasGeneration(genNum))
                return;
            const parts = (out || "").split("\x1e");
            const cache = Object.assign({}, root.configDiffCache);
            cache[genNum] = {
                status: parts[0] || "error",
                message: parts[1] || "",
                repo: parts[2] || "",
                commitA: parts[3] || "",
                commitB: parts[4] || "",
                diff: parts[5] || ""
            };
            root.configDiffCache = cache;
        });
    }

    function loadGenDetails(genNum) {
        // Coerce to a strict positive integer — genNum is then safe to splice
        // into shell paths without further escaping.
        genNum = parseInt(genNum, 10);
        if (!(genNum > 0))
            return;
        root.loadConfigDiff(genNum);
        if (root.detailsCache[genNum] !== undefined && !root.detailsCache[genNum].partial && root.detailsCache[genNum].diffMode === root.diffMode) {
            root.selectedGenNum = genNum;
            return;
        }
        if (root.isLoadingDetails)
            return;
        root.selectedGenNum = genNum;
        root.isLoadingDetails = true;
        const requestedMode = root.diffMode;

        const link = "/nix/var/nix/profiles/system-" + genNum + "-link";
        let isBooted = false;
        for (let i = 0; i < root.generations.length; i++) {
            if (root.generations[i].number === genNum) {
                isBooted = root.generations[i].booted;
                break;
            }
        }

        let basePath;
        if (isBooted) {
            const prev = root.getPreviousGen(genNum);
            basePath = prev !== null ? "/nix/var/nix/profiles/system-" + prev + "-link" : link;
        } else if (root.diffMode === "booted") {
            const bp = root.bootedStorePath !== "" ? root.bootedStorePath : root.activeStorePath;
            basePath = bp !== "" ? bp : link;
        } else {
            const prev = root.getPreviousGen(genNum);
            basePath = prev !== null ? "/nix/var/nix/profiles/system-" + prev + "-link" : link;
        }

        sh(shq(root.scriptDir + "details") + " " + shq(link) + " " + shq(basePath), function (cmd, out, err, code) {
            root.isLoadingDetails = false;
            if (!root.hasGeneration(genNum))
                return;
            if (code !== 0) {
                root.pushToast(err || qsTr("Could not compare generation"), true);
                return;
            }
            root.parseDetails(genNum, out || "", basePath, requestedMode);
        });
    }

    function comparePair(genA, genB) {
        genA = parseInt(genA, 10);
        genB = parseInt(genB, 10);
        if (!(genA > 0) || !(genB > 0) || genA === genB)
            return;
        root.pairDiffA = genA;
        root.pairDiffB = genB;
        const key = genA + "_" + genB;
        if (root.pairDiffCache[key] !== undefined)
            return;
        if (root.isLoadingPairDiff)
            return;
        root.isLoadingPairDiff = true;
        const linkA = "/nix/var/nix/profiles/system-" + genA + "-link";
        const linkB = "/nix/var/nix/profiles/system-" + genB + "-link";
        // base = B, target = A → diff shows what A has on top of B
        sh(shq(root.scriptDir + "details") + " " + shq(linkA) + " " + shq(linkB), function (cmd, out, err, code) {
            root.isLoadingPairDiff = false;
            if (!root.hasGeneration(genA) || !root.hasGeneration(genB))
                return;
            if (code !== 0) {
                root.pushToast(err || qsTr("Could not compare generations"), true);
                return;
            }
            root.parsePairDiff(genA, genB, out || "");
        });
    }

    // Parses `nix store diff-closures` output into package entries.
    // profileFor(type) names the closure that holds the package's store path.
    function parseDiffLines(raw, profileFor) {
        const list = [];
        for (const rawLine of raw.split("\n")) {
            const m = stripAnsi(rawLine).trim().match(/^([^:]+):\s+(.+?)\s+(?:→|->)\s+(.+?)(?:,\s+([+-]?\d[\d.,]*\s*[KMGT]?i?B))?$/);
            if (!m)
                continue;
            const oldV = m[2], newV = m[3];
            const type = oldV === "∅" || oldV === "null" ? "added" : newV === "∅" || newV === "null" ? "removed" : "upgrade";
            list.push({
                name: m[1].trim(),
                oldVersion: oldV,
                newVersion: newV,
                size: (m[4] || "").trim(),
                type,
                storeProfile: profileFor(type)
            });
        }
        return list;
    }

    // "linux-6.9.1" → "6.9.1"; falls back to the store path's name segment.
    function kernelVersion(kernelPath) {
        const m = kernelPath.match(/linux-([^/]+)/);
        return m ? m[1] : (kernelPath ? kernelPath.split("/").slice(-2, -1)[0] : "—");
    }

    function parsePairDiff(genA, genB, text) {
        const diffList = parseDiffLines(text.split("\x1e")[2] || "", type => "/nix/var/nix/profiles/system-" + (type === "removed" ? genB : genA) + "-link");
        const cache = Object.assign({}, root.pairDiffCache);
        cache[genA + "_" + genB] = {
            diff: diffList
        };
        root.pairDiffCache = root.boundedCache(cache, 24);
        root.loadIcons(diffList);
        root.loadMeta(diffList);
    }

    property var storePathCache: ({})
    function resolveStorePath(pkg) {
        const version = pkg.type === "removed" ? pkg.oldVersion : pkg.newVersion;
        const key = (pkg.storeProfile || "") + "|" + pkg.name + "|" + version;
        if (!pkg.storeProfile || root.storePathCache[key])
            return;
        let cache = Object.assign({}, root.storePathCache);
        cache[key] = {
            path: "",
            message: qsTr("Resolving store path…")
        };
        root.storePathCache = root.boundedCache(cache, 256);
        sh(shq(root.scriptDir + "store-path") + " " + shq(pkg.storeProfile) + " " + shq(pkg.name) + " " + shq(version), function (cmd, out, err, code) {
            const next = Object.assign({}, root.storePathCache);
            const paths = (out || "").trim().split("\n").filter(p => p.startsWith("/nix/store/"));
            next[key] = {
                path: paths.join("\n"),
                message: code ? qsTr("Path unavailable") : qsTr("No matching output in this closure")
            };
            root.storePathCache = root.boundedCache(next, 256);
        });
    }

    property var pendingIcons: ({})
    property var pendingMeta: ({})

    function loadIcons(diffList) {
        if (!root.settings.showPackageIcons)
            return;
        const unknown = [...new Set(diffList.map(d => d.name))].filter(n => n && !(n in root.iconCache) && !root.pendingIcons[n]).sort();
        if (unknown.length === 0)
            return;
        unknown.forEach(n => root.pendingIcons[n] = true);
        const input = unknown.join("\n");
        sh("printf %s " + shq(input) + " | " + shq(root.scriptDir + "icons"), function (cmd, out, err, code) {
            unknown.forEach(n => delete root.pendingIcons[n]);
            if (code !== 0)
                return;
            const updated = Object.assign({}, root.iconCache);
            (out || "").split("\n").forEach(line => {
                const tab = line.indexOf("\t");
                if (tab > 0)
                    updated[line.substring(0, tab)] = line.substring(tab + 1).trim();
            });
            unknown.forEach(n => {
                if (!(n in updated))
                    updated[n] = "";
            });
            root.iconCache = root.boundedCache(updated, 4096);
        });
    }

    // Resolve a real upstream homepage for each package — meta.homepage from
    // nixpkgs, or the Website field of a plasmoid metadata.json. One shell call
    // covers the whole diff (the eval is batched). Packages with no link found
    // are cached with source="" so we don't re-probe them.
    function loadMeta(diffList) {
        const unknown = [...new Set(diffList.map(d => d.name))].filter(n => n && !(n in root.metaCache) && !root.pendingMeta[n]).sort();
        if (unknown.length === 0)
            return;
        unknown.forEach(n => root.pendingMeta[n] = true);
        const input = unknown.join("\n");
        sh("printf %s " + shq(input) + " | " + shq(root.scriptDir + "run") + " cached " + shq("meta:" + Qt.md5(input)) + " 3600 -- " + shq(root.scriptDir + "meta"), function (cmd, out, err, code) {
            unknown.forEach(n => delete root.pendingMeta[n]);
            if (code !== 0)
                return;
            const updated = Object.assign({}, root.metaCache);
            (out || "").split("\n").forEach(line => {
                const parts = line.split("\t");
                if (parts.length >= 3 && parts[0])
                    updated[parts[0]] = {
                        url: parts[1],
                        source: parts[2]
                    };
            });
            unknown.forEach(n => {
                if (!(n in updated))
                    updated[n] = {
                        url: "",
                        source: ""
                    };
            });
            root.metaCache = root.boundedCache(updated, 4096);
        });
    }

    // Write the raw flake-probe output + a timestamp to the shared cache file.
    function writeFlakeCache(rawOutput) {
        const ts = Math.floor(Date.now() / 1000);
        root._lastFlakeCacheTs = ts;
        const content = ts + "\n" + rawOutput;
        sh("mkdir -p " + root.cacheDirExpr + "; t=$(mktemp " + root.cacheDirExpr + "/.state.XXXXXXXX) && printf %s " + shq(content) + " > \"$t\" && mv \"$t\" " + root.flakeCacheExpr, null);
    }

    // Read the shared cache file. Calls cb(tsSeconds, rawTsv) on success, cb(0, "") on miss.
    function readFlakeCache(cb) {
        const epoch = root.flakeEpoch;
        sh("cat " + root.flakeCacheExpr + " 2>/dev/null", function (cmd, out, err, code) {
            if (epoch !== root.flakeEpoch) {
                cb(0, "");
                return;
            }
            if (code !== 0 || !(out || "").trim()) {
                cb(0, "");
                return;
            }
            const nl = out.indexOf("\n");
            if (nl < 0) {
                cb(0, "");
                return;
            }
            const ts = parseInt(out.substring(0, nl), 10) || 0;
            const tsv = out.substring(nl + 1);
            cb(ts, tsv);
        });
    }

    // Apply a cache snapshot: parse the TSV and record which timestamp we applied.
    function applyFlakeCache(ts, tsv) {
        root._lastFlakeCacheTs = ts;
        root.parseFlakeProbe(tsv, false);
    }

    function checkFlakeUpdates(isRetry, quiet) {
        if (!root.isNixOS || root.isBusy || root.isCheckingFlake || root.flakePath === "")
            return;
        root.isCheckingFlake = true;
        const epoch = root.flakeEpoch;
        sh(shq(root.scriptDir + "run") + " cached " + shq("flake:" + root.flakePath) + " 30 -- " + shq(root.scriptDir + "flake-probe") + " " + shq(root.flakePath), function (cmd, out, err, code) {
            root.isCheckingFlake = false;
            if (epoch !== root.flakeEpoch)
                return;
            if (code !== 0) {
                const msg = (err || out || "").trim() || qsTr("flake-probe failed");
                root.pushToast(msg, true);
                return;
            }
            const raw = out || "";
            root.writeFlakeCache(raw);
            root.parseFlakeProbe(raw, !!isRetry, !!quiet);
        });
    }

    property string _notifiedUpdates: ""
    function parseFlakeProbe(text, isRetry, quiet) {
        const lines = text.split("\n");
        const updates = [];
        const unreachable = [];

        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split("\t");
            if (parts.length < 6)
                continue;
            const name = parts[0];
            const status = parts[1];
            const oldRev = parts[2];
            const newRev = parts[3];
            const oldDateTs = parseInt(parts[4]) || 0;
            const url = parts[5];
            if (!name)
                continue;

            if (status === "unreachable") {
                unreachable.push(parts.length > 7 && parts[7] ? name + " (" + parts[7] + ")" : name);
                continue;
            }
            if (status !== "ok")
                continue;

            const overrideRef = parts.length > 6 ? parts[6] : "";
            updates.push({
                input: name,
                revisionKey: oldRev + "\n" + newRev,
                oldRev: oldRev.substring(0, 7),
                newRev: newRev.substring(0, 7),
                oldDateTs: oldDateTs,
                oldDate: oldDateTs > 0 ? new Date(oldDateTs * 1000).toLocaleDateString() : "",
                newDate: qsTr("latest"),
                url: url.replace(/\.git$/, ""),
                overrideRef: overrideRef
            });
        }

        const validPreviews = {};
        for (const u of updates) {
            const previous = root.flakeUpdates.find(p => p.input === u.input);
            if (previous && previous.revisionKey === u.revisionKey && previous.overrideRef === u.overrideRef && root.dryRunCache[u.input])
                validPreviews[u.input] = root.dryRunCache[u.input];
        }
        root.dryRunCache = validPreviews;
        const validNotes = {};
        for (const u of updates) {
            const notes = root.releaseNotesCache[u.input];
            if (notes && notes.revisionKey === u.revisionKey)
                validNotes[u.input] = notes;
        }
        root.releaseNotesCache = validNotes;
        if (JSON.stringify(root.flakeUpdates) !== JSON.stringify(updates))
            root.flakeUpdates = updates;
        root.lastFlakeCheckTime = Qt.formatTime(new Date(), "hh:mm");

        // Transient network blips (network not up yet, GitHub anon rate-limit, brief DNS hiccup)
        // are common on the first probe after login. Silently retry once; only toast if it
        // still fails. After the retry succeeds, that recurrence will hit this branch with
        // no unreachable items, so the toast never fires.
        if (unreachable.length > 0) {
            if (!isRetry) {
                flakeRetryTimer.restart();
            } else {
                root.pushToast(qsTr("Could not reach: %1").arg(unreachable.join(", ")), true);
            }
        }

        const signature = JSON.stringify(updates);
        const announce = signature !== root._notifiedUpdates;
        root._notifiedUpdates = signature;
        if (updates.length > 0 && announce && !quiet)
            root.notify(qsTr("Nix — flake updates available"), (updates.length === 1 ? qsTr("1 flake input has updates available") : qsTr("%1 flake inputs have updates available").arg(updates.length)), false);
    }

    Timer {
        id: flakeRetryTimer
        interval: 15000
        repeat: false
        onTriggered: root.checkFlakeUpdates(true)
    }

    property string updatingInput: ""
    function runFlakeUpdateInput(inputName) {
        if (!root.isNixOS)
            return;
        if (root.flakePath === "") {
            root.pushToast(qsTr("Flake path not configured."), true);
            return;
        }
        if (root.isBusy) {
            root.pushToast(qsTr("Already running another action — please wait."), true);
            return;
        }
        root.isBusy = true;
        root.updatingInput = inputName;
        root.currentActionType = qsTr("Updating %1…").arg(inputName);
        const cmd = "cd " + shq(root.flakePath) + " && nix flake update " + shq(inputName);
        sh(cmd, function (c, out, err, code) {
            root.isBusy = false;
            root.updatingInput = "";
            root.recordHistoryEntry("flake-update", root.currentActionType, -1, code, (err || out || "").trim());
            if (code !== 0) {
                root.pushToast(qsTr("Update failed: ") + (err || out || "").trim(), true);
                return;
            }
            root.pushToast(qsTr("'%1' updated in lock file.").arg(inputName), false);

            root.refreshFlakeContext(function () {
                root.checkFlakeUpdates(false, true);
            });
        }, true);
    }

    function runDryPreview(inputName, overrideRef) {
        if (!root.isNixOS)
            return;
        if (!overrideRef || root.flakePath === "" || !root.flakeUpdates.some(u => u.input === inputName && u.overrideRef === overrideRef))
            return;
        if (root.isDryRunning || root.dryRunCache[inputName] && root.dryRunCache[inputName].status !== "error")
            return;

        const cache = Object.assign({}, root.dryRunCache);
        cache[inputName] = {
            status: "loading",
            packages: []
        };
        root.dryRunCache = cache;
        root.isDryRunning = true;
        const epoch = root.flakeEpoch;
        const revisionKey = root.flakeUpdates.find(u => u.input === inputName).revisionKey;

        // Bound the entire read-only operation, including waiting for a cache
        // lock and downloading/evaluating an overridden input.
        sh("timeout --kill-after=5s 180s " + shq(root.scriptDir + "run") + " cached " + shq("preview:" + root.flakePath + ":" + root.lockFingerprint) + " 300 -- " + shq(root.scriptDir + "dry-run-preview") + " " + shq(root.flakePath) + " " + shq(inputName) + " " + shq(overrideRef) + " " + shq(root.settings.enableHostDetect ? "auto" : "single"), function (cmd, out, err, code) {
            root.isDryRunning = false;
            if (epoch !== root.flakeEpoch || !root.flakeUpdates.some(u => u.input === inputName && u.revisionKey === revisionKey && u.overrideRef === overrideRef))
                return;
            const text = (out || "").trim();
            const updated = Object.assign({}, root.dryRunCache);

            if (code !== 0 || text.startsWith("ERROR:")) {
                updated[inputName] = {
                    status: "error",
                    packages: [],
                    errorMsg: code === 124 || code === 137 ? qsTr("Preview timed out after 3 minutes. Check your connection and try again.") : (text || err || qsTr("Preview failed")).replace(/^ERROR:\s*/, "")
                };
                root.dryRunCache = updated;
                return;
            }
            if (text.startsWith("OK:")) {
                updated[inputName] = {
                    status: "ok",
                    packages: []
                };
                root.dryRunCache = updated;
                return;
            }

            const pkgs = [];
            const lines = text.split("\n");
            for (let i = 0; i < lines.length; i++) {
                const parts = lines[i].split("\t");
                if (parts.length < 2)
                    continue;
                const action = parts[0] || "";
                const name = parts[1] || "";
                const oldV = parts[2] || "";
                const newV = parts[3] || "";
                if (!name)
                    continue;
                pkgs.push({
                    action,
                    type: oldV ? "upgrade" : "added",
                    size: "",
                    name,
                    oldVersion: oldV,
                    newVersion: newV
                });
            }
            updated[inputName] = {
                status: "ok",
                packages: pkgs
            };
            root.dryRunCache = updated;
            root.loadIcons(pkgs);
            root.loadMeta(pkgs);
        });
    }

    // What changed upstream between the locked and the latest revision: GitHub
    // releases and commits (see tools/sh/release-notes). Loaded on demand when
    // a card opens, because anonymous GitHub API calls are limited to 60/hour.
    function loadReleaseNotes(inputName, force) {
        if (!root.isNixOS)
            return;
        const update = root.flakeUpdates.find(u => u.input === inputName);
        if (!update || !update.url || !update.revisionKey)
            return;
        const current = root.releaseNotesCache[inputName];
        if (current && current.revisionKey === update.revisionKey && (current.status !== "error" || !force))
            return;
        const revs = update.revisionKey.split("\n");
        const revisionKey = update.revisionKey;
        const epoch = root.flakeEpoch;
        const setEntry = entry => {
            const next = Object.assign({}, root.releaseNotesCache);
            next[inputName] = Object.assign({
                revisionKey: revisionKey,
                compareUrl: "",
                releases: [],
                commits: [],
                moreCommits: false,
                errorMsg: ""
            }, entry);
            root.releaseNotesCache = next;
        };
        setEntry({
            status: "loading"
        });
        // Results for a revision pair never change, so share them for a day.
        sh("timeout --kill-after=5s 60s " + shq(root.scriptDir + "run") + " cached notes 86400 -- " + shq(root.scriptDir + "release-notes") + " " + shq(update.url) + " " + shq(revs[0]) + " " + shq(revs[1]) + " " + shq(String(update.oldDateTs || 0)), function (cmd, out, err, code) {
            if (epoch !== root.flakeEpoch || !root.flakeUpdates.some(u => u.input === inputName && u.revisionKey === revisionKey))
                return;
            let data = null;
            if (code === 0) {
                try {
                    data = JSON.parse((out || "").trim());
                } catch (e) {
                    data = null;
                }
            }
            if (!data) {
                setEntry({
                    status: "error",
                    errorMsg: code === 124 || code === 137 ? qsTr("Timed out while asking upstream for release notes.") : ((err || out || "").trim() || qsTr("Could not load release notes."))
                });
                return;
            }
            setEntry({
                status: "ok",
                compareUrl: data.compareUrl || "",
                releases: data.releases || [],
                commits: data.commits || [],
                moreCommits: !!data.moreCommits
            });
        });
    }

    function runCustomCommand(cmd, label) {
        if (!root.isNixOS)
            return;
        if (root.isBusy || !cmd.trim())
            return;
        root.isBusy = true;
        root.currentActionType = qsTr("Running %1…").arg(label);
        sh(shq(root.scriptDir + "terminal") + " " + shq(root.terminalApp) + " " + shq(root.flakePath) + " " + shq(cmd), function (c, out, err, code) {
            root.isBusy = false;
            const message = code === 0 ? qsTr("%1 finished.").arg(label) : qsTr("%1 exited with status %2. %3").arg(label).arg(code).arg((err || "").trim());
            root.recordHistoryEntry("custom", label, -1, code, qsTr("(output not captured — command ran in a terminal window)"));
            root.pushToast(message, code !== 0);
            root.notify("Nixdatifier", message, code !== 0);
            root.refreshGenerations();
            root.syncFlakeContext(true);
            root.probeDiskUsage(true);
        }, true);
    }

    function requestAction(genNum, action) {
        if (!root.isNixOS)
            return;
        if (root.isBusy) {
            root.pushToast(qsTr("Already running another action — please wait."), true);
            return;
        }
        const needsConfirm = (action === "rollback" || action === "switch") ? root.settings.confirmBeforeRollback : root.settings.confirmBeforeDelete;
        if (needsConfirm) {
            root.pendingGenNum = genNum;
            root.pendingAction = action;
        } else {
            executeAction(genNum, action);
        }
    }

    function cancelPendingAction() {
        root.pendingGenNum = -1;
        root.pendingAction = "";
    }

    function confirmPendingAction() {
        if (root.pendingGenNum > 0 && root.pendingAction !== "") {
            const g = root.pendingGenNum;
            const a = root.pendingAction;
            root.pendingGenNum = -1;
            root.pendingAction = "";
            executeAction(g, a);
        }
    }

    function executeAction(genNum, action) {
        if (!root.isNixOS)
            return;
        if (root.isBusy)
            return;
        // CRITICAL: this builds a command that runs under `pkexec` (root).
        // Reject anything that isn't a clean positive int or a known action
        // before it can reach the shell-string concatenation below.
        genNum = parseInt(genNum, 10);
        if (!(genNum > 0))
            return;
        if (action !== "switch" && action !== "rollback" && action !== "delete")
            return;
        if (action === "switch" && !root.settings.enableLiveSwitch)
            return;
        if (action === "delete" && (genNum === root.activeGenNum || genNum === root.bootedGenNum)) {
            root.pushToast(qsTr("The booted and next-boot generations cannot be deleted."), true);
            return;
        }
        root.isBusy = true;
        root.currentActionType = action === "switch" ? qsTr("Activating generation…") : action === "rollback" ? qsTr("Setting next boot…") : qsTr("Deleting generation…");

        const profileSwitch = privileged("nix-env --profile /nix/var/nix/profiles/system --switch-generation " + genNum);
        const cmd = systemShell(action === "delete" ? privileged("nix-env --profile /nix/var/nix/profiles/system --delete-generations " + genNum) : profileSwitch + " && " + privileged("/nix/var/nix/profiles/system/bin/switch-to-configuration " + (action === "switch" ? "switch" : "boot")));

        sh(cmd, function (c, out, err, code) {
            root.isBusy = false;
            root.recordHistoryEntry(action, root.currentActionType, genNum, code, (err || out || "").trim());
            if (code !== 0) {
                const msg = (err || out || "").trim();
                const labels = {
                    switch: qsTr("Live switch failed: "),
                    rollback: qsTr("Set-next-boot failed: "),
                    delete: qsTr("Delete failed: ")
                };
                root.pushToast((labels[action] || "") + msg, true);
                return;
            }
            const ok = {
                switch: qsTr("Generation %1 is now active."),
                rollback: qsTr("Generation %1 set for next boot. Reboot to activate."),
                delete: qsTr("Generation %1 deleted.")
            };
            const okTitle = {
                switch: qsTr("Nix — generation activated"),
                rollback: qsTr("Nix — next boot set"),
                delete: qsTr("Nix — generation deleted")
            };
            root.pushToast(ok[action].arg(genNum), false);
            root.notify(okTitle[action], ok[action].arg(genNum), false);
            if (action === "delete" && root.selectedGenNum === genNum)
                root.selectedGenNum = -1;
            root.refreshGenerations();
            root.probeDiskUsage(true);
        }, true);
    }

    function executeCleanup(mode) {
        if (!root.isNixOS)
            return;
        if (mode === "gc-custom") {
            const cmd = root.settings.gcCustomCommand.trim();
            if (cmd)
                root.runCustomCommand(cmd, cmd);
            return;
        }
        if (root.isBusy) {
            root.pushToast(qsTr("Already running another action — please wait."), true);
            return;
        }
        const gcArgs = {
            gc: "",
            "gc-14d": " --delete-older-than 14d",
            "gc-all": " -d"
        }[mode];
        if (gcArgs === undefined)
            return;
        root.isBusy = true;
        root.currentActionType = qsTr("Cleaning Nix store…");
        const cmd = systemShell(privileged("nix-collect-garbage" + gcArgs));
        sh(cmd, function (c, out, err, code) {
            root.isBusy = false;
            root.recordHistoryEntry(mode, root.currentActionType, -1, code, (err || out || "").trim());
            root.refreshGenerations();
            root.probeDiskUsage(true);
            if (code !== 0) {
                root.pushToast(qsTr("GC failed: ") + (err || out || "").trim(), true);
                return;
            }
            const freed = ((out || "") + "\n" + (err || "")).match(/(\d[\d,.]* \w+B?) freed/i);
            const msg = freed ? qsTr("GC complete — %1 freed.").arg(freed[1]) : qsTr("GC complete.");
            root.pushToast(msg, false);
            root.notify(qsTr("Nix — garbage collected"), msg, false);
        }, true);
    }

    // ── Parsers ───────────────────────────────────────────────────────────────

    function parseGenerations(text) {
        const lines = text.split("\n");

        let activePath = "";
        let bootedPath = "";
        let startIdx = 0;
        if (lines[0] && (lines[0].startsWith("/nix/store/") || lines[0].startsWith("/nix/var/"))) {
            activePath = lines[0].trim();
            startIdx = 1;
            if (lines[1] && (lines[1].startsWith("/nix/store/") || lines[1].startsWith("/nix/var/"))) {
                bootedPath = lines[1].trim();
                startIdx = 2;
            }
        }
        root.activeStorePath = activePath;
        root.bootedStorePath = bootedPath;

        const list = [];
        let activeNum = -1;
        let bootedNum = -1;
        let currentPath = "";
        for (let i = startIdx; i < lines.length; i++) {
            if (lines[i].startsWith("current ")) {
                currentPath = lines[i].slice(8).trim();
                continue;
            }
            const m = lines[i].match(/^([\d-]+ [\d:]+)\.\d+ [+-]\d+ '([^']*system-(\d+)-link)' -> '([^']+)'/);
            if (!m)
                continue;
            const genNum = parseInt(m[3]);
            const storePath = m[4];
            const isActive = activePath !== "" && storePath === activePath;
            const isBooted = bootedPath !== "" && storePath === bootedPath;
            if (isActive)
                activeNum = genNum;
            if (isBooted)
                bootedNum = genNum;
            list.push({
                number: genNum,
                timestamp: m[1],
                storePath,
                active: isActive,
                booted: isBooted
            });
        }

        list.sort((a, b) => b.number - a.number);
        // `nixos-rebuild test` / `nh os test` activate a closure without registering a generation.
        root.runningTestBuild = currentPath !== "" && !list.some(g => g.storePath === currentPath);
        // Keep the preceding closure even when the displayed history is limited.
        for (let i = 0; i + 1 < list.length; ++i) {
            list[i].previousNumber = list[i + 1].number;
            list[i].previousStorePath = list[i + 1].storePath;
        }

        // Keep only the highest generation matching the booted store path
        let maxBooted = list.reduce((max, g) => g.booted && g.number > max ? g.number : max, -1);
        bootedNum = maxBooted;
        for (let i = 0; i < list.length; i++)
            list[i].booted = (list[i].number === bootedNum);

        const maxG = Math.max(3, root.settings.maxGenerations || 10);
        if (list.length > maxG)
            list.splice(maxG);

        activeNum = list.reduce((max, g) => g.active && g.number > max ? g.number : max, -1);
        list.forEach(g => g.active = g.number === activeNum);
        if (JSON.stringify(root.generations) !== JSON.stringify(list))
            root.generations = list;
        root.activeGenNum = activeNum;
        root.bootedGenNum = bootedNum;

        root.loadGenSummaries();
        root.snapshotActiveConfig();
    }

    // Eagerly populate nixos-version + kernel for all gens (no nix commands — instant).
    // Writes partial detailsCache entries so header badges appear without expanding first.
    function loadGenSummaries() {
        sh(shq(root.scriptDir + "gen-summaries"), function (cmd, out, err, code) {
            const records = (out || "").split("\x1d");
            const cache = Object.assign({}, root.detailsCache);
            for (let i = 0; i < records.length; i++) {
                const parts = records[i].split("\x1e");
                const genNum = parseInt(parts[0], 10);
                if (!(genNum > 0) || !root.hasGeneration(genNum))
                    continue;
                // Don't overwrite a fully-loaded entry (which has diff data).
                if (cache[genNum] !== undefined && !cache[genNum].partial)
                    continue;
                const nixosVer = (parts[1] || "").trim();
                cache[genNum] = {
                    nixosVer,
                    kernelVer: root.kernelVersion((parts[2] || "").trim()),
                    commitDate: "",
                    diff: [],
                    closureBytes: 0,
                    partial: true
                };
            }
            root.detailsCache = cache;
        });
    }

    // Record git HEAD of the config repo for the currently-active generation.
    // Idempotent — the tool short-circuits if (gen, commit) is already on file.
    // Only fires when a config repo is configured (or flakePath is a git repo).
    function snapshotActiveConfig() {
        if (root.activeGenNum <= 0)
            return;
        const repo = (root.settings.configRepoPath || root.flakePath || "").trim();
        if (!repo)
            return;
        sh(shq(root.scriptDir + "config-snapshot") + " " + root.activeGenNum + " " + shq(repo), function (cmd, out, err, code) { /* fire-and-forget */ });
    }

    function stripAnsi(s) {
        return s.replace(/\x1b\[[0-9;]*[mGKHFABCDEFJRSTsu]/g, "");
    }

    function parseDetails(genNum, text, basePath, requestedMode) {
        // \x1e separates: [0]=nixos-version  [1]=kernel-path  [2]=diff lines
        const parts = text.split("\x1e");
        const nixosVer = stripAnsi((parts[0] || "").trim());
        const kernelVer = kernelVersion(stripAnsi((parts[1] || "").trim()));
        const sizeRaw = (parts[3] || "").trim();
        const closureBytes = /^\d+$/.test(sizeRaw) ? parseInt(sizeRaw, 10) : 0;
        const diffList = parseDiffLines(parts[2] || "", type => type === "removed" ? (basePath || "/run/booted-system") : "/nix/var/nix/profiles/system-" + genNum + "-link");

        // Extract commit date from nixos version e.g. "25.11.20260518.abc1234"
        let commitDate = "";
        const dateM = nixosVer.match(/(\d{4})(\d{2})(\d{2})/);
        if (dateM)
            commitDate = dateM[1] + "-" + dateM[2] + "-" + dateM[3];

        const cache = Object.assign({}, root.detailsCache);
        cache[genNum] = {
            nixosVer,
            kernelVer,
            commitDate,
            diff: diffList,
            closureBytes,
            diffMode: requestedMode || root.diffMode
        };
        root.detailsCache = cache;
        root.loadIcons(diffList);
        root.loadMeta(diffList);
    }

    function parseSysInfo(text) {
        const p = text.split("---");
        root.hostname = p[0] ? p[0].trim() : "";
        root.nixosVersion = p[1] ? p[1].trim() : "";
        root.uptime = p[2] ? p[2].trim() : "";
        root.lastActivationTime = p[3] ? p[3].trim() : "";
        root.userFacePath = p[4] ? p[4].trim() : "";
        // Detect once; subsequent probes only refresh display information.
        const flag = p[5] === undefined ? "" : p[5].trim();
        if (!root.systemDetected && (flag === "1" || flag === "0")) {
            root.isNixOS = flag === "1";
            root.systemDetected = true;
            root.activeViewMode = root.isNixOS ? (root.settings.defaultView || "timeline") : "tools";
        }
    }

    function parseSopsInfo(text) {
        const blocks = text.split("===");
        root.deployedSecrets = parseSecretsBlock(blocks[0] || "", "deployed");
        root.sourceSecrets = parseSecretsBlock(blocks[1] || "", "source");
    }

    function parseSecretsBlock(raw, kind) {
        const empty = root.emptySecrets;
        // Preserve a leading empty line (path=empty) by only trimming, not filtering.
        const rawLines = raw.split("\n").map(l => l.trim());
        // Drop leading blank lines AND trailing blank lines, keep blanks in between.
        let start = 0;
        while (start < rawLines.length && rawLines[start] === "")
            start++;
        // If the first non-blank line is a status keyword, the path field was empty.
        if (start >= rawLines.length || rawLines[start] === "missing")
            return empty;
        const lines = rawLines.slice(start).filter(l => l !== "");
        if (lines.length < 2)
            return empty;
        const sep = lines.indexOf("---");
        const exists = lines[1] === "exists";
        const lastModified = (sep > 2) ? lines[2] : "";
        const names = lines.filter(l => l.startsWith("name:")).map(l => l.slice(5));

        if (kind === "deployed") {
            const freshness = (sep >= 0 && lines.length > sep + 1) ? lines[sep + 1] : "";
            const fileCount = (sep >= 0 && lines.length > sep + 2) ? (parseInt(lines[sep + 2]) || 0) : 0;
            return {
                path: lines[0],
                exists,
                lastModified,
                freshness,
                fileCount,
                names,
                encKind: "",
                sopsVersion: "",
                recipientCount: 0,
                encType: ""
            };
        } else {
            const encKind = (sep >= 0 && lines.length > sep + 1) ? lines[sep + 1] : "";
            const sopsVersion = (sep >= 0 && lines.length > sep + 2) ? lines[sep + 2] : "";
            const recipientCount = (sep >= 0 && lines.length > sep + 3) ? (parseInt(lines[sep + 3]) || 0) : 0;
            const encType = (sep >= 0 && lines.length > sep + 4) ? lines[sep + 4] : "";
            return {
                path: lines[0],
                exists,
                lastModified,
                freshness: "",
                fileCount: names.length,
                names,
                encKind,
                sopsVersion,
                recipientCount,
                encType
            };
        }
    }

    // ── Init & timers ─────────────────────────────────────────────────────────
    function start() {
        // Probe sysinfo first so we know whether we're on NixOS before launching
        // NixOS-only operations (generations, secrets).  The probe is fast — it
        // reads /etc/hostname, /proc/uptime and a few small files.
        sh(shq(root.scriptDir + "sysinfo"), function (cmd, out, err, code) {
            root.parseSysInfo(out || "");
            if (root.isNixOS) {
                refreshGenerations();
                probeSecrets();
                root.refreshFlakeContext(function () {
                    if (root.settings.showFlakeSection && root.flakePath !== "") {
                        root.bootFlakeCheck();
                        root.armCacheWatcher();
                    }
                });
            } else if (!root.systemDetected) {
                root.pushToast(qsTr("Could not detect the system. System actions are unavailable."), true);
            }
        });
        root.probeImpermanence();
        loadHistory();
        // Deliberately no probeDiskUsage() here — it is deferred to the first
        // time the popup is opened, so a widget that is never clicked never
        // walks /nix/store.
    }

    Component.onCompleted: {
        initialized = true;
        if (autoStart)
            Qt.callLater(start);
    }

    // On startup: read the shared cache first. If it is fresh (written within
    // checkInterval seconds by any widget instance), apply it immediately and
    // skip the network probe entirely. Otherwise fall through to the deferred probe.
    function bootFlakeCheck() {
        root.readFlakeCache(function (ts, tsv) {
            if (ts > 0 && tsv.trim() !== "") {
                const age = Math.floor(Date.now() / 1000) - ts;
                const interval = Math.max(60, root.settings.checkInterval || 3600);
                if (age < interval) {
                    root.applyFlakeCache(ts, tsv);
                    return;
                }
            }
            initialFlakeCheckTimer.start();
        });
    }

    // Deferred first probe — gives the network a chance to come up after login.
    Timer {
        id: initialFlakeCheckTimer
        interval: 30000
        repeat: false
        onTriggered: root.checkFlakeUpdates()
    }

    onExpandedChanged: {
        if (root.initialized && root.settings && root.expanded && root.autoStart) {
            root.syncFlakeContext(false);
            if (root.isNixOS && root.settings.autoRefreshOnOpen)
                refreshGenerations();
            // The very first open always populates the disk chips; after that
            // it follows the auto-refresh preference. Either way it is
            // TTL-guarded, so reopening the popup does not re-walk the store.
            if (root._diskProbeDirty || root._lastDiskProbeMs === 0 || root.settings.autoRefreshOnOpen)
                probeDiskUsage();
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.isNixOS && root.autoStart && root.expanded && root.flakePath !== ""
        onTriggered: root.syncFlakeContext(false)
    }
    Connections {
        target: root.settings
        function onFlakePathChanged() {
            if (root.autoStart)
                root.syncFlakeContext(true);
        }
        function onShowFlakeSectionChanged() {
            if (root.autoStart && root.settings.showFlakeSection) {
                root.checkFlakeUpdates();
                root.armCacheWatcher();
            }
        }
        function onSecretsPathChanged() {
            if (root.autoStart)
                root.probeSecrets();
        }
        function onSecretsSourcePathChanged() {
            if (root.autoStart)
                root.probeSecrets();
        }
        function onImpermanencePathsChanged() {
            if (root.autoStart)
                root.probeImpermanence();
        }
    }
    // Full network probe on the configured interval.
    Timer {
        interval: Math.max(60, root.settings.checkInterval || 3600) * 1000
        running: root.isNixOS && root.autoStart && root.settings.showFlakeSection && root.flakePath !== ""
        repeat: true
        onTriggered: root.checkFlakeUpdates()
    }

    // Cross-instance sync via inotifywait: starts a one-shot shell that blocks
    // until the cache file is modified, then reads and applies it immediately,
    // then arms itself again. Falls back to a slow poll when inotifywait is
    // missing or unusable.
    //
    // The watch command reports its own outcome instead of unconditionally
    // succeeding: an absent inotifywait, a too-old inotify-tools without
    // --include, or a missing cache directory used to make the callback fire
    // instantly, which re-armed instantly, which spawned another shell — a
    // process-spawn loop that pegs a core for as long as the widget is loaded.
    // Now a non-"changed" result switches to polling permanently, arming is
    // never faster than watcherMinArmMs, and a run of suspiciously fast
    // "changed" results also drops us to polling.
    readonly property int watcherMinArmMs: 2000
    readonly property int watcherMaxFastArms: 5
    property bool _watcherArmed: false
    property bool _watcherDisabled: false
    property real _watcherArmedAtMs: 0
    property int _watcherFastArms: 0

    function armCacheWatcher() {
        if (!root.isNixOS || !root.autoStart || !root.settings.showFlakeSection || root._watcherArmed || root._watcherDisabled || root.flakePath === "")
            return;
        root._watcherArmed = true;
        root._watcherArmedAtMs = Date.now();
        // Watch the cache directory for writes to our specific filename.
        // Watching the directory means inotifywait works even before the file exists.
        const cacheDir = root.cacheDirExpr;
        const probe = "command -v inotifywait >/dev/null 2>&1 || { echo unsupported; exit 0; }; mkdir -p " + cacheDir + "; inotifywait -t 300 -e close_write -e moved_to -q --include '(flake.lock|flake-.*)' " + cacheDir + " " + shq(root.flakePath) + " >/dev/null 2>&1; code=$?; if [ $code -eq 0 ]; then echo changed; elif [ $code -eq 2 ]; then echo timeout; else echo failed; fi";
        sh(probe, function (cmd, out, err, code) {
            root._watcherArmed = false;
            const result = (out || "").trim();

            if (result === "timeout") {
                watcherRearmTimer.restart();
                return;
            }
            if (result !== "changed") {
                // No usable watch (no inotifywait, unsupported flags, bad dir).
                root.fallBackToCachePolling();
                return;
            }

            // A real close_write can legitimately arrive quickly, but a *run*
            // of near-instant returns means the watch is not actually blocking.
            if (Date.now() - root._watcherArmedAtMs < root.watcherMinArmMs) {
                root._watcherFastArms += 1;
                if (root._watcherFastArms >= root.watcherMaxFastArms) {
                    root.fallBackToCachePolling();
                    return;
                }
            } else {
                root._watcherFastArms = 0;
            }

            root.refreshFlakeContext(function (changed) {
                if (changed && root.settings.showFlakeSection)
                    root.checkFlakeUpdates();
                else if (!root.isCheckingFlake)
                    root.syncFlakeCache();
            });

            // Re-arm off a timer, never straight from the callback, so there is
            // always a floor on how often we can spawn the watch process.
            watcherRearmTimer.restart();
        });
    }

    function fallBackToCachePolling() {
        root._watcherDisabled = true;
        watcherRearmTimer.stop();
        flakeCacheFallbackTimer.start();
    }

    function syncFlakeCache() {
        root.readFlakeCache(function (ts, tsv) {
            if (ts > root._lastFlakeCacheTs)
                root.applyFlakeCache(ts, tsv);
        });
    }

    // Enforces watcherMinArmMs between two consecutive watch processes.
    Timer {
        id: watcherRearmTimer
        interval: root.watcherMinArmMs
        repeat: false
        onTriggered: root.armCacheWatcher()
    }

    // Fallback poll used only when inotifywait is unavailable or unusable.
    // Cross-instance flake state is not urgent, so this is deliberately slow:
    // it is a `cat` of a small file, but there is no reason to do it every
    // minute for the life of the session.
    Timer {
        id: flakeCacheFallbackTimer
        interval: 300000
        repeat: true
        running: false
        onTriggered: {
            if (root.isCheckingFlake || !root.settings.showFlakeSection)
                return;
            root.refreshFlakeContext(function (changed) {
                if (changed)
                    root.checkFlakeUpdates();
                else
                    root.syncFlakeCache();
            });
        }
    }

    // sysinfo is cheap (reads /proc and two small files), but there is no point
    // refreshing it every 5 minutes when nothing is on screen — while the popup
    // is closed it only backs the panel tooltip, so a slow tick is plenty.
    Timer {
        interval: root.expanded ? 300000 : 1800000
        running: root.autoStart
        repeat: true
        onTriggered: root.probeSysInfo()
    }

    // True only while the popup is actually on screen. Threaded down through
    // the view tree so looping animations can stop when nobody can see them —
    // a QML animation left running keeps the render loop ticking whether or
    // not its item is visible.
    readonly property bool uiActive: root.expanded
}
