pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "shared" as UI
import "components"

// Folders that survive a reboot on a system whose root is wiped on every boot.
// Everything else is gone after a restart, so these are the places where old
// data piles up and where malware would have to live to come back.
//
// Three views: Folders (what is kept, and what is inside), Cleanup (pick
// leftovers, review, delete) and Security (things that start by themselves).
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
    property var removalStates: ({})
    property var sizes: null
    property bool isListing: false
    property bool isMeasuring: false
    property bool isScanning: false
    property bool isAnalyzing: false
    property bool isRemoving: false
    property int staleDays: 180

    property string lens: "folders"     // "folders" | "cleanup" | "security"
    property bool showDisks: false
    property string pendingPath: ""

    // Folders: the kept list, or the inside of one folder.
    property string search: ""
    property string folderSearch: ""
    property string scope: "all"        // "all" | "home" | "system"
    property string sortBy: "size"      // "size" | "recent" | "name"
    readonly property int pageSize: 60
    property int visibleLimit: pageSize
    property int folderLimit: pageSize
    property string openDir: ""         // folder on show; "" is the kept list
    property string baseDir: ""         // where the walk started
    property string baseTitle: ""
    property string filter: "all"       // "all" | "stale" | "exec" | "perms" | "hidden"

    // Selection: path -> { path, name, size, kind } (cleanup category or "item").
    property var selection: ({})
    property bool reviewing: false

    // Security
    property bool showMinor: false

    signal listRequested(string path, bool force)
    signal listCancelRequested
    signal sizesRequested(bool force)
    signal scanRequested(bool force)
    signal analyzeRequested(bool force)
    signal removeRequested(string path, string name)
    signal removeManyRequested(var items)
    signal openRequested(string path)
    signal clamScanRequested
    signal copyToClipboard(string text)

    anchors.fill: parent
    visible: activeViewMode === "impermanence"

    readonly property color secondary: "#a9b5c7"
    readonly property color tertiary: "#8794a8"
    readonly property var severityRank: ({
            "high": 0,
            "medium": 1,
            "low": 2,
            "info": 3
        })
    // While another folder loads, the one before is not shown under its name.
    readonly property bool listingOk: !!listing && !listing.isError && (!isListing || listing.dir === openDir)
    readonly property bool scanOk: !!scan && !scan.isError
    readonly property bool cleanupOk: !!cleanup && !cleanup.isError
    readonly property bool sizesOk: !!sizes && !sizes.isError

    function px(n) {
        return UI.Theme.fontPx(n, fs);
    }
    // Control characters in names come through as \xHH; show the character.
    function plain(text) {
        return UI.Theme.unescapePath(text);
    }
    // Last component of an escaped path; names with control characters stay visible as \xHH.
    function baseName(path) {
        const parts = String(path || "").split("/").filter(p => p !== "");
        return parts.length ? parts[parts.length - 1] : String(path || "");
    }
    // "/persist/home/u/.cache/x" reads as "~/.cache/x".
    function tidy(path) {
        const t = plain(path);
        const bases = [""].concat(impermanence.areas.map(a => plain(a.path)).filter(a => a !== "/home"));
        for (const base of bases) {
            if (t.indexOf(base + "/home/") !== 0)
                continue;
            const rest = t.slice(base.length + 6);
            const slash = rest.indexOf("/");
            return slash < 0 ? "~" : "~" + rest.slice(slash);
        }
        return t;
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
    function bytes(n) {
        return UI.Theme.formatBytes(n) || "0 B";
    }

    function setLens(next) {
        // A selection belongs to the list it was made in.
        if (next !== lens)
            clearSelection();
        lens = next;
        pendingPath = "";
        if (next === "folders" && !sizes && !isMeasuring)
            sizesRequested(false);
        if (next === "folders" && openDir !== "" && !listing && !isListing)
            listRequested(openDir, false);
        if (next === "security" && !scan && !isScanning)
            scanRequested(false);
        if (next === "cleanup" && !cleanup && !isAnalyzing)
            analyzeRequested(false);
    }
    // Activating a view can update its models; do it after visibility/layout
    // bindings finish, rather than re-entering those bindings during startup.
    onVisibleChanged: if (visible)
        Qt.callLater(activateVisibleLens)
    function activateVisibleLens() {
        if (visible)
            setLens(lens);
    }
    onSearchChanged: visibleLimit = pageSize
    onFolderSearchChanged: folderLimit = pageSize
    onFilterChanged: folderLimit = pageSize
    onSortByChanged: {
        folderLimit = pageSize;
        visibleLimit = pageSize;
    }
    onScopeChanged: visibleLimit = pageSize

    // ── Folder navigation ────────────────────────────────────────────────
    function openFolder(path, title) {
        lens = "folders";
        baseDir = path;
        baseTitle = title;
        enter(path);
    }
    function enter(path) {
        pendingPath = "";
        filter = "all";
        clearSelection();
        folderSearch = "";
        folderLimit = pageSize;
        openDir = path;
        listRequested(path, false);
        scroll.ScrollBar.vertical.position = 0;
    }
    function closeFolder() {
        pendingPath = "";
        filter = "all";
        clearSelection();
        // Always: besides stopping a walk, the engine learns no folder is open.
        listCancelRequested();
        openDir = "";
    }
    function goBack() {
        if (openDir === "" || openDir === baseDir) {
            closeFolder();
            return;
        }
        const cut = openDir.lastIndexOf("/");
        enter(cut > 0 ? openDir.slice(0, cut) : baseDir);
    }
    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: if (tab.lens === "folders")
            tab.goBack()
    }

    // ── Kept entries ─────────────────────────────────────────────────────
    // Well-known places, so "/home/u/.config/Code" reads as "VS Code settings".
    readonly property var knownHome: ({
            ".config/Code": qsTr("VS Code settings"),
            ".config/Code - OSS": qsTr("VSCodium settings"),
            ".config/VSCodium": qsTr("VSCodium settings"),
            ".vscode": qsTr("VS Code extensions"),
            ".vscode-oss": qsTr("VSCodium extensions"),
            ".cursor": qsTr("Cursor"),
            ".config/Cursor": qsTr("Cursor settings"),
            ".mozilla": qsTr("Firefox"),
            ".zen": qsTr("Zen browser"),
            ".librewolf": qsTr("LibreWolf"),
            ".thunderbird": qsTr("Thunderbird"),
            ".config/google-chrome": qsTr("Google Chrome"),
            ".config/chromium": qsTr("Chromium"),
            ".config/BraveSoftware": qsTr("Brave"),
            ".config/vivaldi": qsTr("Vivaldi"),
            ".config/discord": qsTr("Discord"),
            ".config/vesktop": qsTr("Vesktop"),
            ".config/Signal": qsTr("Signal"),
            ".config/obsidian": qsTr("Obsidian settings"),
            ".config/spotify": qsTr("Spotify"),
            ".config/JetBrains": qsTr("JetBrains settings"),
            ".local/share/JetBrains": qsTr("JetBrains data"),
            ".ssh": qsTr("SSH keys and hosts"),
            ".gnupg": qsTr("GPG keys"),
            ".local/share/keyrings": qsTr("Saved passwords (keyring)"),
            ".local/share/kwalletd": qsTr("KDE Wallet"),
            ".local/share/Steam": qsTr("Steam"),
            ".steam": qsTr("Steam"),
            ".local/share/direnv": qsTr("direnv allowed folders"),
            ".local/share/zoxide": qsTr("zoxide history"),
            ".local/share/fish": qsTr("Fish history"),
            ".local/share/nix": qsTr("Nix user data"),
            ".cargo": qsTr("Rust (cargo)"),
            ".rustup": qsTr("Rust toolchains"),
            ".npm": qsTr("npm cache"),
            ".local/share/pnpm": qsTr("pnpm store"),
            ".local/share/containers": qsTr("Podman images"),
            ".config/kdeconnect": qsTr("KDE Connect"),
            ".local/share/baloo": qsTr("File search index"),
            ".config/gh": qsTr("GitHub CLI login"),
            ".config/git": qsTr("Git settings"),
            ".claude": qsTr("Claude Code"),
            ".config/Claude": qsTr("Claude desktop"),
            ".cache": qsTr("All app caches"),
            ".config": qsTr("All app settings"),
            ".local/share": qsTr("All app data"),
            ".local/state": qsTr("All app state"),
            "Documents": qsTr("Documents"),
            "Downloads": qsTr("Downloads"),
            "Pictures": qsTr("Pictures"),
            "Music": qsTr("Music"),
            "Videos": qsTr("Videos"),
            "Desktop": qsTr("Desktop")
        })
    readonly property var knownSystem: ({
            "/var/lib/bluetooth": qsTr("Bluetooth pairings"),
            "/var/lib/NetworkManager": qsTr("Network state"),
            "/etc/NetworkManager/system-connections": qsTr("Saved Wi-Fi and VPN"),
            "/var/lib/docker": qsTr("Docker images and volumes"),
            "/var/lib/containers": qsTr("Podman images"),
            "/var/lib/libvirt": qsTr("Virtual machines"),
            "/var/lib/flatpak": qsTr("Flatpak apps"),
            "/var/lib/nixos": qsTr("NixOS user and group IDs"),
            "/var/lib/systemd": qsTr("systemd state"),
            "/var/lib/systemd/coredump": qsTr("Crash dumps"),
            "/var/lib/tailscale": qsTr("Tailscale login"),
            "/var/lib/sbctl": qsTr("Secure Boot keys"),
            "/var/lib/fprint": qsTr("Fingerprints"),
            "/var/lib/upower": qsTr("Battery history"),
            "/var/lib/colord": qsTr("Colour profiles"),
            "/var/lib/sddm": qsTr("Login screen"),
            "/var/lib/AccountsService": qsTr("User accounts"),
            "/var/lib/ollama": qsTr("Ollama models"),
            "/var/log": qsTr("System logs"),
            "/var/cache": qsTr("System caches"),
            "/etc/ssh": qsTr("SSH host keys"),
            "/etc/machine-id": qsTr("Machine ID"),
            "/etc/nixos": qsTr("NixOS configuration")
        })

    function describe(target) {
        const t = plain(target);
        const home = /^\/home\/[^/]+\/(.+)$/.exec(t) || /^\/root\/(.+)$/.exec(t);
        if (home) {
            const rel = home[1];
            const friendly = knownHome[rel] || "";
            return {
                scope: "home",
                shown: "~/" + rel,
                title: friendly || rel.split("/").pop(),
                friendly: friendly !== ""
            };
        }
        const friendly = knownSystem[t] || "";
        return {
            scope: "system",
            shown: t,
            title: friendly || t.split("/").pop() || t,
            friendly: friendly !== ""
        };
    }

    // Every entry the configuration persists, joined with its measured size.
    readonly property var persistedRows: {
        return impermanence.entries.map(function (e) {
            const d = describe(e.target);
            const m = sizesOk ? sizes[e.target] : null;
            return {
                kind: e.kind,
                target: e.target,
                source: e.source,
                scope: d.scope,
                shown: d.shown,
                title: d.title,
                friendly: d.friendly,
                size: m ? m.size : 0,
                newest: m ? m.newest : 0,
                status: m ? m.status : "failed"
            };
        });
    }
    // Total without counting an entry that sits inside another one twice.
    readonly property real persistedBytes: {
        if (!sizesOk)
            return 0;
        const targets = persistedRows.map(r => plain(r.target));
        let sum = 0;
        for (const r of persistedRows) {
            const t = plain(r.target);
            if (!targets.some(o => o !== t && t.indexOf(o + "/") === 0))
                sum += r.size;
        }
        return sum;
    }
    // Some entry could not be measured fully: the total is a lower bound.
    readonly property bool persistedPartial: sizesOk && persistedRows.some(r => r.status !== "ok")
    // A size that could not be measured is unknown, not zero; a partial one is a lower bound.
    function sizeLabel(size, status) {
        if (status === "failed")
            return "—";
        return (status === "partial" ? "≥ " : "") + bytes(size);
    }
    function scopeCount(which) {
        return persistedRows.filter(r => r.scope === which).length;
    }
    readonly property var filteredRows: {
        const q = search.trim().toLowerCase();
        const rows = persistedRows.filter(r => (scope === "all" || r.scope === scope) && (q === "" || r.title.toLowerCase().indexOf(q) >= 0 || r.shown.toLowerCase().indexOf(q) >= 0));
        rows.sort(function (a, b) {
            if (sortBy === "size" && sizesOk && a.size !== b.size)
                return b.size - a.size;
            if (sortBy === "recent" && sizesOk && a.newest !== b.newest)
                return b.newest - a.newest;
            return a.shown.localeCompare(b.shown);
        });
        return rows;
    }
    readonly property var visibleRows: filteredRows.slice(0, visibleLimit)

    // Subvolumes and bind mounts of one filesystem share their numbers: one bar per disk.
    readonly property var disks: {
        const groups = [];
        for (const a of impermanence.areas) {
            const key = a.fsType + "|" + a.total + "|" + a.used;
            let g = groups.find(x => x.key === key);
            if (!g) {
                g = {
                    key: key,
                    fsType: a.fsType,
                    total: a.total,
                    used: a.used,
                    avail: a.avail,
                    paths: []
                };
                groups.push(g);
            }
            g.paths.push(a.path);
        }
        return groups;
    }

    // ── Inside a folder ──────────────────────────────────────────────────
    function isBound(item) {
        const path = plain(item.path);
        return impermanence.entries.some(e => e.source === path);
    }

    // Kept list › where the walk started › each folder below it.
    readonly property var crumbs: {
        if (!listingOk || !listing.dir)
            return [];
        let base = baseDir, label = baseTitle;
        if (!base || (listing.dir !== base && listing.dir.indexOf(base + "/") !== 0)) {
            base = listing.area;
            label = plain(base);
        }
        const out = [
            {
                label: qsTr("Kept folders"),
                path: ""
            },
            {
                label: label,
                path: base
            }
        ];
        const rel = listing.dir.length > base.length ? listing.dir.slice(base.length + 1) : "";
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

    readonly property var filters: [
        {
            id: "all",
            label: qsTr("Everything"),
            explain: ""
        },
        {
            id: "stale",
            label: qsTr("Not changed in %1 days").arg(staleDays),
            explain: qsTr("Nothing inside changed for a long time. That does not mean unused: archives, photos and keys rarely change.")
        },
        {
            id: "exec",
            label: qsTr("Executables"),
            explain: qsTr("Programs and scripts, and folders that contain them. Expected in bin and tool folders; worth a look in documents or downloads.")
        },
        {
            id: "perms",
            label: qsTr("Unusual permissions"),
            explain: qsTr("Files that run with their owner's rights (setuid) or that any user on this machine can change. Usually leftovers, rarely needed in a home folder.")
        },
        {
            id: "hidden",
            label: qsTr("Hidden"),
            explain: qsTr("Dot-files, and names with invisible characters or edge spaces that hide them from file listings.")
        }
    ]
    readonly property var activeFilter: filters.find(f => f.id === filter) || filters[0]

    readonly property var shownItems: {
        if (!listingOk)
            return [];
        const query = folderSearch.trim().toLowerCase();
        return listing.items.filter(function (item) {
            if (query && plain(item.label).toLowerCase().indexOf(query) < 0)
                return false;
            if (isGone(item.path))
                return false;
            if (filter === "stale")
                return ageDays(item.newest) > staleDays;
            if (filter === "exec")
                return /[xe]/.test(item.flags);
            if (filter === "perms")
                return /[sw]/.test(item.flags);
            if (filter === "hidden")
                return /[hc]/.test(item.flags);
            return true;
        }).sort(function (a, b) {
            if (sortBy === "size" && a.size !== b.size)
                return b.size - a.size;
            if (sortBy === "recent" && a.newest !== b.newest)
                return b.newest - a.newest;
            return plain(a.label).localeCompare(plain(b.label));
        });
    }

    // At most one marker per row, the most important one.
    function markerFor(item) {
        if (item.flags.indexOf("s") >= 0)
            return {
                text: qsTr("Setuid"),
                tone: UI.Theme.negative
            };
        if (item.flags.indexOf("c") >= 0)
            return {
                text: qsTr("Invisible characters"),
                tone: UI.Theme.negative
            };
        if (item.flags.indexOf("w") >= 0)
            return {
                text: qsTr("World-writable"),
                tone: UI.Theme.changed
            };
        if (item.flags.indexOf("x") >= 0)
            return {
                text: qsTr("Executable"),
                tone: tertiary
            };
        return {
            text: "",
            tone: tertiary
        };
    }
    function describeItem(item) {
        const parts = [];
        if (isBound(item))
            parts.push(qsTr("Kept by your config"));
        if (item.kind === "d")
            parts.push(itemCount(item.count));
        if (item.kind === "l")
            parts.push(item.link.indexOf("/nix/store/") === 0 ? qsTr("Link managed by Nix") : qsTr("Link to %1").arg(item.link));
        parts.push(qsTr("changed %1").arg(ago(item.newest)));
        if (item.owner)
            parts.push(item.owner);
        return parts.join(" · ");
    }

    // Rows stay present while queued or deleting. Only confirmed successes disappear.
    function removalFor(path) {
        return removalStates[path] || {
            state: "",
            message: ""
        };
    }
    function isPending(path) {
        const state = removalFor(path).state;
        return state === "queued" || state === "deleting";
    }
    property var removedPaths: ({})
    onRemovalStatesChanged: Qt.callLater(syncRemovedPaths)
    function syncRemovedPaths() {
        const next = {};
        for (const path of Object.keys(removalStates))
            if (removalStates[path].state === "deleted")
                next[path] = true;
        const keys = Object.keys(next);
        if (keys.length !== Object.keys(removedPaths).length || keys.some(p => !removedPaths[p]))
            removedPaths = next;
    }
    function isGone(path) {
        // Compare ancestors instead of scanning every removed path for each row.
        let current = path;
        while (current) {
            if (removedPaths[current])
                return true;
            const slash = current.lastIndexOf("/");
            if (slash <= 0)
                break;
            current = current.slice(0, slash);
        }
        return false;
    }
    function removeOne(path, name) {
        pendingPath = "";
        removeRequested(path, name);
    }

    // ── Cleanup ──────────────────────────────────────────────────────────
    readonly property var tempItems: cleanupOk && cleanup.temp ? cleanup.temp.filter(t => !isGone(t.path)) : []
    readonly property var staleItems: cleanupOk && cleanup.stale ? cleanup.stale.filter(s => !isGone(s.path)) : []
    readonly property real tempBytes: tempItems.reduce((sum, t) => sum + t.size, 0)
    readonly property var selectedItems: Object.keys(selection).map(k => selection[k])
    readonly property int selectedCount: selectedItems.length
    readonly property real selectedBytes: selectedItems.reduce((sum, t) => sum + t.size, 0)

    function cleanupKind(item) {
        if (item.label === "Trash")
            return "trash";
        if (item.label === "Application cache" || item.label === "Build or dependency cache")
            return "cache";
        if (item.label === "Core dump" || item.label === "Rotated log")
            return "logs";
        return "temporary";
    }
    readonly property var cleanupGroups: [
        {
            kind: "cache",
            title: qsTr("Caches"),
            note: qsTr("Usually recreated by apps or build tools. Rebuilding may need downloads or take time.")
        },
        {
            kind: "trash",
            title: qsTr("Trash"),
            note: qsTr("Permanently removes trashed files. Restore anything you need first.")
        },
        {
            kind: "temporary",
            title: qsTr("Temporary and backup files"),
            note: qsTr("May include recovery copies and unfinished downloads. Check each file before deleting.")
        },
        {
            kind: "logs",
            title: qsTr("Logs and crash reports"),
            note: qsTr("Past diagnostic records cannot be recreated. Keep any you still need for troubleshooting.")
        },
        {
            kind: "personal",
            title: qsTr("Your files"),
            note: qsTr("Not changed in %1 days. That does not mean unused; check before deleting.").arg(staleDays)
        }
    ]
    function cleanupItems(kind) {
        return kind === "personal" ? staleItems : tempItems.filter(i => cleanupKind(i) === kind);
    }

    function isSelected(path) {
        return selection[path] !== undefined;
    }
    function toggleSelected(item, kind) {
        if (isPending(item.path))
            return;
        const next = Object.assign({}, selection);
        if (next[item.path] !== undefined)
            delete next[item.path];
        else
            next[item.path] = {
                path: item.path,
                name: baseName(item.path),
                size: item.size,
                kind: kind
            };
        selection = next;
        if (selectedCount === 0)
            reviewing = false;
    }
    function selectAll(items, kind) {
        const next = Object.assign({}, selection);
        for (const item of items.filter(i => !isPending(i.path)))
            next[item.path] = {
                path: item.path,
                name: baseName(item.path),
                size: item.size,
                kind: kind
            };
        selection = next;
    }
    function clearSelection() {
        selection = ({});
        reviewing = false;
    }
    function deleteSelected() {
        const items = selectedItems.map(i => ({
                    path: i.path,
                    name: i.name
                }));
        clearSelection();
        removeManyRequested(items);
    }
    // Selections that no longer exist after a new analysis are dropped.
    onCleanupChanged: {
        if (!cleanupOk || lens !== "cleanup")
            return;
        const known = {};
        for (const t of tempItems)
            known[t.path] = true;
        for (const s of staleItems)
            known[s.path] = true;
        const next = {};
        for (const k of Object.keys(selection))
            if (known[k])
                next[k] = selection[k];
        selection = next;
        if (Object.keys(next).length === 0)
            reviewing = false;
    }

    // ── Security ─────────────────────────────────────────────────────────
    function severityTone(severity) {
        return severity === "high" ? UI.Theme.negative : severity === "medium" ? UI.Theme.changed : tertiary;
    }
    readonly property var findings: {
        if (!scanOk)
            return [];
        return scan.findings.map((f, i) => Object.assign({
                order: i
            }, f)).filter(f => f.severity !== "meta" && !(f.path && isGone(f.path))).sort((a, b) => (severityRank[a.severity] - severityRank[b.severity]) || (a.order - b.order));
    }
    function countOf(severity) {
        return findings.filter(f => f.severity === severity).length;
    }
    readonly property int attentionCount: countOf("high") + countOf("medium")

    // ── Building blocks ──────────────────────────────────────────────────
    // One list row: optional checkbox, icon, name and size first, the path
    // beneath. Open is always there; copy and delete show on hover or focus, in the
    // same flat icon buttons as the rest of the app. Deleting one row is
    // confirmed inside the row.
    component EntryRow: Rectangle {
        id: er
        property string path: ""
        property string location: path     // what Open and Copy act on
        readonly property var removal: tab.removalFor(path)
        readonly property bool working: removal.state === "queued" || removal.state === "deleting" || removal.state === "deleted"
        property string glyph: "ic_folder"
        property color glyphColor: UI.Theme.muted
        property string title: ""
        property string subtitle: ""
        property bool monoSubtitle: false
        property string detail: ""
        property string sizeText: ""
        property string tagText: ""
        property color tagTone: UI.Theme.muted
        property bool first: false
        property bool clickable: false     // the row opens something
        property bool selectable: false    // the whole row ticks the box
        property bool checkable: false     // a box to tick, the row still opens
        property bool selected: false
        property bool showOpen: true
        property bool showCopy: true
        property bool canDelete: true
        property bool confirming: false
        property real fs: tab.fs
        property color textColor: tab.textColor
        property color accent: tab.accentColor
        readonly property bool hasBox: selectable || checkable
        readonly property bool hovered: rowHover.hovered
        signal activated
        signal toggled
        signal deleteAsked
        signal deleteConfirmed
        signal deleteCancelled

        activeFocusOnTab: (clickable || selectable) && !working
        Accessible.role: selectable ? Accessible.CheckBox : Accessible.Button
        Accessible.name: title + (subtitle ? ", " + subtitle : "")
        Accessible.checkable: selectable
        Accessible.checked: selected
        Accessible.onPressAction: activateRow()
        Accessible.onToggleAction: if (selectable && !working)
            toggled()
        function activateRow() {
            if (!working) {
                if (selectable)
                    toggled();
                else if (clickable)
                    activated();
            }
        }
        Keys.onReturnPressed: activateRow()
        Keys.onEnterPressed: activateRow()
        Keys.onSpacePressed: {
            if (!working && hasBox)
                toggled();
            else
                activateRow();
        }
        border.width: activeFocus ? 1 : 0
        border.color: accent
        Layout.fillWidth: true
        implicitHeight: Math.max(46 * fs, rowContent.implicitHeight + 16)
        radius: 8
        color: confirming ? UI.Theme.wash(UI.Theme.negative, .08) : selected && checkable ? UI.Theme.wash(accent, .07) : hovered ? "#0affffff" : "transparent"

        HoverHandler {
            id: rowHover
        }
        Rectangle {
            visible: !er.first && !er.confirming
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: 1
            color: "#0bffffff"
        }
        MouseArea {
            anchors.fill: parent
            enabled: er.clickable || er.selectable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                er.forceActiveFocus();
                er.activateRow();
            }
        }
        ColumnLayout {
            id: rowContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                opacity: er.working ? 0.6 : 1
                spacing: 10
                CheckBox {
                    objectName: "entryCheckBox"
                    visible: er.hasBox
                    enabled: !er.working
                    checked: er.selected
                    Accessible.name: qsTr("Select %1").arg(er.title)
                    implicitWidth: 28
                    implicitHeight: 32
                    padding: 0
                    indicator: Rectangle {
                        x: 2
                        y: (parent.height - height) / 2
                        width: 20
                        height: 20
                        radius: 4
                        color: er.selected ? er.accent : "transparent"
                        border.color: parent.activeFocus ? er.accent : "#8794a8"
                        border.width: parent.activeFocus ? 2 : 1
                        UI.Icon {
                            anchors.centerIn: parent
                            width: 13
                            height: 13
                            visible: er.selected
                            source: Qt.resolvedUrl("assets/ic_check.svg")
                            isMask: true
                            color: "#10151d"
                        }
                    }
                    onClicked: er.toggled()
                }
                UI.Icon {
                    source: Qt.resolvedUrl("assets/" + er.glyph + ".svg")
                    isMask: true
                    color: er.glyphColor
                    implicitWidth: 18
                    implicitHeight: 18
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            Layout.fillWidth: true
                            text: er.title
                            textFormat: Text.PlainText
                            color: er.textColor
                            font.pixelSize: UI.Theme.fontPx(13, er.fs)
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Tag {
                            visible: er.tagText !== ""
                            text: er.tagText
                            tone: er.tagTone
                            fs: er.fs
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: er.subtitle !== ""
                        text: er.subtitle
                        textFormat: Text.PlainText
                        color: "#a9b5c7"
                        font.family: er.monoSubtitle ? UI.Theme.fixedWidthFont.family : Qt.application.font.family
                        font.pixelSize: UI.Theme.fontPx(11, er.fs)
                        elide: Text.ElideMiddle
                    }
                }
                Text {
                    visible: er.sizeText !== ""
                    text: er.sizeText
                    color: er.textColor
                    font.pixelSize: UI.Theme.fontPx(12, er.fs)
                    font.weight: Font.Medium
                }
                // Hover actions keep their space so the size column never jumps.
                UI.ActionButton {
                    visible: er.showCopy && !er.confirming
                    opacity: er.hovered || er.activeFocus || activeFocus ? 1 : 0
                    glyph: Qt.resolvedUrl("assets/ic_copy.svg")
                    flatStyle: true
                    implicitHeight: 30
                    tip: qsTr("Copy path")
                    objectName: "entryCopy"
                    onClicked: tab.copyToClipboard(tab.plain(er.location))
                }
                UI.ActionButton {
                    visible: er.canDelete && !er.confirming
                    opacity: er.hovered || er.activeFocus || activeFocus ? 1 : 0
                    enabled: !er.working
                    glyph: Qt.resolvedUrl("assets/ic_delete.svg")
                    flatStyle: true
                    implicitHeight: 30
                    tip: qsTr("Delete…")
                    onClicked: er.deleteAsked()
                }
                UI.ActionButton {
                    visible: er.showOpen && !er.confirming
                    glyph: Qt.resolvedUrl("assets/ic_external.svg")
                    flatStyle: true
                    implicitHeight: 30
                    tip: qsTr("Show in file manager")
                    onClicked: tab.openRequested(er.location)
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: (er.hasBox ? 28 : 0) + 28
                visible: er.detail !== ""
                text: er.detail
                textFormat: Text.PlainText
                color: "#a9b5c7"
                font.pixelSize: UI.Theme.fontPx(11, er.fs)
                wrapMode: Text.Wrap
                lineHeight: 1.35
            }
            Text {
                Layout.fillWidth: true
                visible: er.removal.state !== "" && er.removal.state !== "deleted"
                text: er.removal.state === "queued" ? qsTr("Queued…") : er.removal.state === "deleting" ? qsTr("Deleting…") : qsTr("Could not delete: %1").arg(er.removal.message)
                textFormat: Text.PlainText
                color: er.removal.state === "failed" ? UI.Theme.negative : tab.secondary
                font.pixelSize: UI.Theme.fontPx(11, er.fs)
                wrapMode: Text.Wrap
                Accessible.role: Accessible.StaticText
            }
            RowLayout {
                Layout.fillWidth: true
                visible: er.confirming
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Delete “%1” for good?").arg(er.title)
                    textFormat: Text.PlainText
                    color: UI.Theme.negative
                    font.pixelSize: UI.Theme.fontPx(12, er.fs)
                    elide: Text.ElideMiddle
                }
                UI.ActionButton {
                    text: qsTr("Cancel")
                    flatStyle: true
                    implicitHeight: 30
                    font.pixelSize: UI.Theme.fontPx(11, er.fs)
                    onClicked: er.deleteCancelled()
                }
                UI.ActionButton {
                    text: qsTr("Delete")
                    primary: true
                    accent: UI.Theme.negative
                    implicitHeight: 30
                    font.pixelSize: UI.Theme.fontPx(11, er.fs)
                    enabled: !er.working
                    onClicked: er.deleteConfirmed()
                }
            }
        }
    }

    // Quiet surface that holds a list of rows; no outline.
    component ListSurface: Rectangle {
        default property alias rows: surfaceColumn.data
        Layout.fillWidth: true
        implicitHeight: surfaceColumn.implicitHeight + 8
        radius: 10
        color: "#04ffffff"
        ColumnLayout {
            id: surfaceColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            spacing: 0
        }
    }

    // Heading above a list, with optional note and trailing buttons.
    component ListHeading: ColumnLayout {
        id: lh
        property string title: ""
        property string note: ""
        property real fs: tab.fs
        property color textColor: tab.textColor
        default property alias trailing: headingTrailing.data
        Layout.fillWidth: true
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: lh.title
                textFormat: Text.PlainText
                color: lh.textColor
                font.pixelSize: UI.Theme.fontPx(13, lh.fs)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            RowLayout {
                id: headingTrailing
                spacing: 4
            }
        }
        Text {
            Layout.fillWidth: true
            visible: lh.note !== ""
            text: lh.note
            textFormat: Text.PlainText
            color: "#a9b5c7"
            font.pixelSize: UI.Theme.fontPx(11, lh.fs)
            wrapMode: Text.Wrap
            lineHeight: 1.35
        }
    }

    // What the helper said when it failed, in place of the result it would have given.
    component ErrorNotice: Notice {
        required property var result
        Layout.fillWidth: true
        visible: !!result && !!result.isError
        glyph: "ic_warning"
        tone: UI.Theme.negative
        emphasis: true
        fs: tab.fs
        text: visible ? String(result.value).replace(/^ERROR:\s*/, "") : ""
    }

    // Reveals the next page of a long list.
    component MoreButton: UI.ActionButton {
        property int remaining: 0
        Layout.alignment: Qt.AlignHCenter
        text: qsTr("Show %1 more").arg(Math.min(tab.pageSize, remaining))
        flatStyle: true
        implicitHeight: 32
        font.pixelSize: tab.px(12)
    }

    // Plain explanatory text, without a box around it.
    component Hint: Text {
        property real fs: tab.fs
        Layout.fillWidth: true
        textFormat: Text.PlainText
        color: "#8794a8"
        font.pixelSize: UI.Theme.fontPx(11, fs)
        wrapMode: Text.Wrap
        lineHeight: 1.4
    }

    component FolderTools: RowLayout {
        id: tools
        property bool inside: false
        Layout.fillWidth: true
        spacing: 6
        TextField {
            objectName: tools.inside ? "impermanenceFolderSearch" : "impermanenceSearch"
            Layout.fillWidth: true
            implicitHeight: 32
            placeholderText: tools.inside ? qsTr("Search this folder") : qsTr("Search kept folders")
            Accessible.name: placeholderText
            text: tools.inside ? tab.folderSearch : tab.search
            color: tab.textColor
            placeholderTextColor: tab.tertiary
            selectByMouse: true
            font.pixelSize: tab.px(12)
            leftPadding: 10
            background: Rectangle {
                radius: 8
                color: "#06ffffff"
                border.color: parent.activeFocus ? tab.accentColor : "transparent"
            }
            onTextEdited: {
                if (tools.inside)
                    tab.folderSearch = text;
                else
                    tab.search = text;
            }
            Keys.onEscapePressed: {
                if (tools.inside)
                    tab.folderSearch = "";
                else
                    tab.search = "";
            }
        }
        UI.ActionButton {
            objectName: tools.inside ? "impermanenceFolderSort" : "impermanenceSort"
            text: qsTr("Sort: %1").arg(tab.sortBy === "size" ? qsTr("Largest") : tab.sortBy === "recent" ? qsTr("Recent") : qsTr("A–Z"))
            implicitHeight: 32
            font.pixelSize: tab.px(11)
            onClicked: sortMenu.open()
            Menu {
                id: sortMenu
                objectName: tools.inside ? "impermanenceFolderSortMenu" : "impermanenceSortMenu"
                y: parent.height
                Repeater {
                    model: [
                        {
                            key: "size",
                            label: qsTr("Largest")
                        },
                        {
                            key: "recent",
                            label: qsTr("Recent")
                        },
                        {
                            key: "name",
                            label: qsTr("A–Z")
                        }
                    ]
                    MenuItem {
                        required property var modelData
                        objectName: "folderSortOption-" + modelData.key
                        text: modelData.label
                        checkable: true
                        checked: tab.sortBy === modelData.key
                        onTriggered: tab.sortBy = modelData.key
                    }
                }
            }
        }
        UI.ActionButton {
            objectName: tools.inside ? "impermanenceFolderRefresh" : "impermanenceRemeasure"
            glyph: Qt.resolvedUrl("assets/ic_refresh.svg")
            flatStyle: true
            implicitHeight: 32
            tip: qsTr("Measure again")
            enabled: tools.inside ? !tab.isListing : !tab.isMeasuring
            onClicked: tools.inside ? tab.listRequested(tab.openDir, true) : tab.sizesRequested(true)
        }
    }

    ColumnLayout {
        id: fixedHeader
        objectName: "impermanenceHeader"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 10
        // ── Header: one line, disk details on demand ─────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: tab.persistedRows.length === 0 ? qsTr("Persistent folders") : tab.persistedBytes > 0 ? qsTr("%1 kept · %2").arg(tab.itemCount(tab.persistedRows.length)).arg((tab.persistedPartial ? "≥ " : "") + tab.bytes(tab.persistedBytes)) : qsTr("%1 kept").arg(tab.itemCount(tab.persistedRows.length))
                        textFormat: Text.PlainText
                        color: tab.textColor
                        font.pixelSize: tab.px(15)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: tab.impermanence.volatile ? qsTr("Your root starts empty on every boot; only these survive.") : qsTr("These are kept across reboots.")
                        color: tab.secondary
                        font.pixelSize: tab.px(11)
                        elide: Text.ElideRight
                    }
                }
                UI.ActionButton {
                    objectName: "impermanenceDisks"
                    visible: tab.disks.length > 0
                    text: tab.disks.length === 1 && tab.disks[0].total > 0 ? qsTr("%1 free").arg(tab.bytes(tab.disks[0].avail)) : qsTr("%1 disks").arg(tab.disks.length)
                    glyph: Qt.resolvedUrl(tab.showDisks ? "assets/ic_chevron_up.svg" : "assets/ic_disk.svg")
                    tip: tab.showDisks ? qsTr("Hide disk details") : qsTr("Disk usage and kept places")
                    flatStyle: true
                    implicitHeight: 32
                    font.pixelSize: tab.px(12)
                    onClicked: tab.showDisks = !tab.showDisks
                }
            }
            Repeater {
                model: tab.showDisks ? tab.disks : []
                ColumnLayout {
                    id: disk
                    required property var modelData
                    readonly property real share: modelData.total > 0 ? modelData.used / modelData.total : 0
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: disk.modelData.total > 0 ? qsTr("%1 of %2 used · %3 free · %4").arg(tab.bytes(disk.modelData.used)).arg(tab.bytes(disk.modelData.total)).arg(tab.bytes(disk.modelData.avail)).arg(disk.modelData.fsType) : disk.modelData.fsType
                        textFormat: Text.PlainText
                        color: tab.secondary
                        font.pixelSize: tab.px(11)
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        visible: disk.modelData.total > 0
                        implicitHeight: 6
                        radius: 3
                        color: "#10ffffff"
                        Rectangle {
                            width: parent.width * Math.min(1, disk.share)
                            height: parent.height
                            radius: 3
                            color: disk.share > 0.9 ? UI.Theme.negative : disk.share > 0.75 ? UI.Theme.changed : tab.accentColor
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: disk.modelData.paths
                            UI.ActionButton {
                                required property string modelData
                                text: modelData
                                tip: qsTr("Open %1").arg(modelData)
                                glyph: Qt.resolvedUrl("assets/ic_folder.svg")
                                implicitHeight: 30
                                font.family: UI.Theme.fixedWidthFont.family
                                font.pixelSize: tab.px(11)
                                onClicked: {
                                    tab.showDisks = false;
                                    tab.openFolder(modelData, modelData);
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── View switch ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.round(36 * tab.fs)
            radius: 9
            color: "#06ffffff"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 3
                Repeater {
                    model: [
                        {
                            id: "folders",
                            label: qsTr("Folders"),
                            badge: "",
                            tone: tab.tertiary
                        },
                        {
                            id: "cleanup",
                            label: qsTr("Cleanup"),
                            badge: tab.cleanupOk && tab.tempBytes > 0 ? tab.bytes(tab.tempBytes) : "",
                            tone: UI.Theme.positive
                        },
                        {
                            id: "security",
                            label: qsTr("Security"),
                            badge: tab.scanOk && tab.attentionCount > 0 ? String(tab.attentionCount) : "",
                            tone: tab.countOf("high") > 0 ? UI.Theme.negative : UI.Theme.changed
                        }
                    ]
                    Button {
                        id: segment
                        required property var modelData
                        readonly property bool active: tab.lens === modelData.id
                        objectName: "impermanenceLens-" + modelData.id
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Accessible.name: modelData.label
                        checkable: true
                        checked: active
                        onClicked: tab.setLens(modelData.id)
                        background: Rectangle {
                            radius: 7
                            color: segment.active ? UI.Theme.wash(tab.accentColor, .16) : segment.hovered ? "#08ffffff" : "transparent"
                            border.width: segment.activeFocus ? 1 : 0
                            border.color: tab.accentColor
                        }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: segment.modelData.label
                                color: segment.active ? tab.accentColor : tab.textColor
                                font.pixelSize: tab.px(12)
                                font.weight: segment.active ? Font.DemiBold : Font.Normal
                            }
                            Text {
                                visible: segment.modelData.badge !== ""
                                text: segment.modelData.badge
                                color: segment.modelData.tone
                                font.pixelSize: tab.px(10)
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            objectName: "impermanenceFolderNavigation"
            Layout.fillWidth: true
            visible: tab.lens === "folders" && tab.openDir !== ""
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                UI.ActionButton {
                    objectName: "impermanenceBack"
                    text: qsTr("Back")
                    glyph: Qt.resolvedUrl("assets/ic_back.svg")
                    implicitHeight: 32
                    font.pixelSize: tab.px(12)
                    onClicked: tab.goBack()
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 0
                    Repeater {
                        model: tab.crumbs
                        RowLayout {
                            id: crumb
                            required property var modelData
                            required property int index
                            readonly property bool last: index === tab.crumbs.length - 1
                            spacing: 0
                            Text {
                                visible: crumb.index > 0
                                text: "›"
                                color: tab.tertiary
                                font.pixelSize: tab.px(13)
                                leftPadding: 2
                                rightPadding: 2
                            }
                            UI.ActionButton {
                                text: crumb.modelData.label
                                flatStyle: true
                                foreground: crumb.last ? tab.textColor : tab.secondary
                                implicitHeight: 30
                                font.pixelSize: tab.px(12)
                                font.weight: crumb.last ? Font.DemiBold : Font.Normal
                                onClicked: {
                                    if (crumb.last)
                                        return;
                                    if (crumb.modelData.path === "")
                                        tab.closeFolder();
                                    else
                                        tab.enter(crumb.modelData.path);
                                }
                            }
                        }
                    }
                }
            }
            FolderTools {
                inside: true
            }
        }
    }

    UI.ScrollView {
        id: scroll
        objectName: "impermanenceScroll"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: fixedHeader.bottom
        anchors.topMargin: 10
        anchors.bottom: selectionBar.visible ? selectionBar.top : parent.bottom
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 12

            // ── Folders: the kept list ───────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: tab.lens === "folders" && tab.openDir === ""
                spacing: 10

                FolderTools {}
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: [
                            {
                                id: "all",
                                label: qsTr("All"),
                                count: tab.persistedRows.length
                            },
                            {
                                id: "home",
                                label: qsTr("Home"),
                                count: tab.scopeCount("home")
                            },
                            {
                                id: "system",
                                label: qsTr("System"),
                                count: tab.scopeCount("system")
                            }
                        ]
                        UI.ActionButton {
                            required property var modelData
                            objectName: "impermanenceScope-" + modelData.id
                            text: modelData.label + "  " + modelData.count
                            accent: tab.accentColor
                            primary: tab.scope === modelData.id
                            flatStyle: tab.scope !== modelData.id
                            implicitHeight: 30
                            font.pixelSize: tab.px(11)
                            onClicked: tab.scope = modelData.id
                        }
                    }
                }
                Hint {
                    visible: tab.isMeasuring && !tab.sizesOk
                    text: qsTr("Measuring sizes…")
                }
                ErrorNotice {
                    result: tab.sizes
                }

                ListSurface {
                    visible: tab.visibleRows.length > 0
                    Repeater {
                        model: tab.visibleRows
                        EntryRow {
                            required property var modelData
                            required property int index
                            path: modelData.path || modelData.source || ""
                            location: modelData.target
                            first: index === 0
                            glyph: modelData.kind === "d" ? "ic_folder" : "ic_outline_box"
                            glyphColor: modelData.kind === "d" ? tab.accentColor : tab.tertiary
                            title: modelData.title
                            subtitle: modelData.shown + (tab.sizesOk && modelData.newest > 0 ? " · " + qsTr("changed %1").arg(tab.ago(modelData.newest)) : "")
                            sizeText: tab.sizesOk ? tab.sizeLabel(modelData.size, modelData.status) : "…"
                            clickable: modelData.kind === "d"
                            canDelete: false
                            onActivated: tab.openFolder(modelData.source, modelData.title)
                        }
                    }
                }
                MoreButton {
                    visible: remaining > 0
                    remaining: tab.filteredRows.length - tab.visibleLimit
                    onClicked: tab.visibleLimit += tab.pageSize
                }
                ListSurface {
                    visible: tab.persistedRows.length === 0 && tab.impermanence.areas.length > 0
                    Repeater {
                        model: tab.persistedRows.length === 0 ? tab.impermanence.areas : []
                        EntryRow {
                            required property var modelData
                            required property int index
                            objectName: "persistentRoot-" + index
                            location: modelData.path
                            first: index === 0
                            title: modelData.path
                            subtitle: qsTr("Open persistent folder")
                            clickable: true
                            canDelete: false
                            onActivated: tab.openFolder(modelData.path, modelData.path)
                        }
                    }
                }
                Hint {
                    visible: tab.persistedRows.length === 0 && tab.impermanence.areas.length === 0
                    text: qsTr("No persistent folders detected.")
                }
                Hint {
                    visible: tab.persistedRows.length > 0 && tab.filteredRows.length === 0
                    text: qsTr("Nothing matches “%1”.").arg(tab.search)
                }
                Hint {
                    visible: tab.persistedRows.length > 0
                    text: qsTr("Open a folder to see and clean up what is inside. The folders themselves are kept by your configuration.")
                }
            }

            // ── Folders: inside one folder ───────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: tab.lens === "folders" && tab.openDir !== ""
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    visible: tab.listingOk
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: tab.listingOk ? qsTr("%1 in %2 · last change %3").arg((tab.listing.partial ? "≥ " : "") + tab.bytes(tab.listing.total)).arg(tab.listing.files === 1 ? qsTr("1 file") : qsTr("%1 files").arg(tab.listing.files)).arg(tab.ago(tab.listing.newest)) : ""
                        textFormat: Text.PlainText
                        color: tab.secondary
                        font.pixelSize: tab.px(12)
                        elide: Text.ElideRight
                    }
                    UI.ActionButton {
                        objectName: "impermanenceSelectAll"
                        readonly property var deletable: tab.shownItems.filter(i => !tab.isBound(i) && !tab.isPending(i.path))
                        readonly property bool all: deletable.length > 0 && deletable.every(i => tab.isSelected(i.path))
                        visible: deletable.length > 1
                        text: all ? qsTr("Select none") : qsTr("Select all")
                        flatStyle: true
                        implicitHeight: 30
                        font.pixelSize: tab.px(11)
                        onClicked: all ? tab.clearSelection() : tab.selectAll(deletable, "item")
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    visible: tab.listingOk && tab.listing.items.length > 0
                    spacing: 5
                    Repeater {
                        model: tab.filters
                        UI.ActionButton {
                            required property var modelData
                            objectName: "impermanenceFilter-" + modelData.id
                            text: modelData.label
                            accent: tab.accentColor
                            primary: tab.filter === modelData.id
                            flatStyle: tab.filter !== modelData.id
                            implicitHeight: 30
                            font.pixelSize: tab.px(11)
                            onClicked: tab.filter = modelData.id
                        }
                    }
                }
                Hint {
                    visible: tab.activeFilter.explain !== ""
                    text: tab.activeFilter.explain
                }
                ErrorNotice {
                    result: tab.listing
                }
                Hint {
                    visible: tab.isListing
                    text: qsTr("Measuring this folder…")
                }
                Hint {
                    objectName: "impermanencePartialHint"
                    visible: tab.listingOk && !!tab.listing.partial
                    text: qsTr("Some folders in here could not be read, so sizes are at least what is shown.")
                }
                Hint {
                    objectName: "impermanenceMoreHint"
                    visible: tab.listingOk && (tab.listing.moreCount || 0) > 0
                    text: visible ? qsTr("Only the largest entries are listed; %1 smaller ones (%2 together) are left out. Open the folder in your file manager to see all.").arg(tab.listing.moreCount).arg(tab.bytes(tab.listing.moreBytes)) : ""
                }

                ListSurface {
                    visible: tab.shownItems.length > 0
                    opacity: tab.isListing ? 0.55 : 1
                    Repeater {
                        objectName: "impermanenceFolderRows"
                        model: tab.shownItems.slice(0, tab.folderLimit)
                        EntryRow {
                            required property var modelData
                            required property int index
                            objectName: "folderEntry-" + modelData.name
                            readonly property var marker: tab.markerFor(modelData)
                            readonly property bool deletable: !tab.isBound(modelData)
                            path: modelData.path || modelData.source || ""
                            first: index === 0
                            glyph: modelData.kind === "d" ? "ic_folder" : "ic_outline_box"
                            glyphColor: marker.tone === UI.Theme.negative ? UI.Theme.negative : modelData.kind === "d" ? tab.accentColor : tab.tertiary
                            title: modelData.label
                            subtitle: tab.describeItem(modelData)
                            sizeText: tab.bytes(modelData.size)
                            tagText: marker.text
                            tagTone: marker.tone
                            clickable: modelData.kind === "d"
                            checkable: deletable
                            selected: tab.isSelected(modelData.path)
                            canDelete: deletable
                            confirming: tab.pendingPath === modelData.path
                            onActivated: tab.enter(modelData.path)
                            onToggled: tab.toggleSelected(modelData, "item")
                            onDeleteAsked: tab.pendingPath = modelData.path
                            onDeleteCancelled: tab.pendingPath = ""
                            onDeleteConfirmed: tab.removeOne(modelData.path, modelData.name)
                        }
                    }
                }
                MoreButton {
                    objectName: "impermanenceMoreFiles"
                    visible: remaining > 0
                    remaining: tab.shownItems.length - tab.folderLimit
                    onClicked: tab.folderLimit += tab.pageSize
                }
                Hint {
                    visible: tab.listingOk && tab.shownItems.length === 0
                    text: tab.listing && tab.listing.items.length === 0 ? qsTr("This folder is empty.") : qsTr("Nothing here matches the search or filter.")
                }
            }

            // ── Cleanup: pick ────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: tab.lens === "cleanup" && !tab.reviewing
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Hint {
                        text: qsTr("Tick what you want gone, then review. Nothing is deleted before you confirm.")
                    }
                    UI.ActionButton {
                        objectName: "impermanenceReanalyze"
                        text: tab.isAnalyzing ? qsTr("Analyzing…") : qsTr("Analyze again")
                        glyph: Qt.resolvedUrl("assets/ic_refresh.svg")
                        flatStyle: true
                        implicitHeight: 32
                        font.pixelSize: tab.px(12)
                        enabled: !tab.isAnalyzing
                        onClicked: tab.analyzeRequested(true)
                    }
                }
                ErrorNotice {
                    result: tab.cleanup
                }
                Hint {
                    visible: tab.isAnalyzing && !tab.cleanup
                    text: qsTr("Measuring the kept folders. This can take a while on large disks.")
                }

                Repeater {
                    model: tab.cleanupGroups
                    ColumnLayout {
                        id: candidateGroup
                        required property var modelData
                        readonly property var items: tab.cleanupItems(modelData.kind)
                        property int limit: 40
                        Layout.fillWidth: true
                        visible: items.length > 0
                        spacing: 6
                        ListHeading {
                            title: candidateGroup.modelData.title + " · " + tab.bytes(candidateGroup.items.reduce((sum, i) => sum + i.size, 0))
                            note: candidateGroup.modelData.note
                            UI.ActionButton {
                                visible: candidateGroup.modelData.kind === "cache"
                                objectName: "impermanenceSelectCaches"
                                readonly property bool all: candidateGroup.items.every(i => tab.isSelected(i.path))
                                text: all ? qsTr("Deselect caches") : qsTr("Select caches")
                                flatStyle: true
                                implicitHeight: 30
                                font.pixelSize: tab.px(11)
                                onClicked: {
                                    if (all) {
                                        for (const item of candidateGroup.items)
                                            if (tab.isSelected(item.path))
                                                tab.toggleSelected(item, "cache");
                                    } else
                                        tab.selectAll(candidateGroup.items, "cache");
                                }
                            }
                        }
                        ListSurface {
                            Repeater {
                                model: candidateGroup.items.slice(0, candidateGroup.limit)
                                EntryRow {
                                    required property var modelData
                                    required property int index
                                    objectName: "cleanupEntry-" + index + "-" + candidateGroup.modelData.kind
                                    path: modelData.path
                                    first: index === 0
                                    selectable: true
                                    selected: tab.isSelected(modelData.path)
                                    glyph: candidateGroup.modelData.kind === "cache" ? "ic_clock" : "ic_folder"
                                    glyphColor: candidateGroup.modelData.kind === "cache" ? tab.accentColor : tab.tertiary
                                    title: tab.baseName(modelData.path)
                                    subtitle: (modelData.label || qsTr("last changed %1").arg(tab.ago(modelData.newest))) + " · " + tab.tidy(modelData.path)
                                    sizeText: tab.sizeLabel(modelData.size, modelData.partial ? "partial" : "ok")
                                    canDelete: false
                                    onToggled: tab.toggleSelected(modelData, candidateGroup.modelData.kind)
                                }
                            }
                        }
                        MoreButton {
                            visible: remaining > 0
                            remaining: candidateGroup.items.length - candidateGroup.limit
                            onClicked: candidateGroup.limit += tab.pageSize
                        }
                    }
                }
                Notice {
                    Layout.fillWidth: true
                    visible: tab.cleanupOk && tab.tempItems.length === 0 && tab.staleItems.length === 0
                    glyph: "ic_check"
                    tone: UI.Theme.positive
                    emphasis: true
                    fs: tab.fs
                    text: qsTr("Nothing to clean up.")
                }
                Hint {
                    visible: tab.cleanupOk
                    text: qsTr("Keys, the SSH and GnuPG folders and anything your configuration binds into the system are never offered.")
                }
            }

            // ── Cleanup: review ──────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: tab.lens === "cleanup" && tab.reviewing
                spacing: 12

                ListHeading {
                    title: qsTr("Review: delete %1, %2").arg(tab.itemCount(tab.selectedCount)).arg(tab.bytes(tab.selectedBytes))
                    note: qsTr("Deletion is permanent. Review the paths and the notes for each group before continuing.")
                }
                Repeater {
                    model: tab.cleanupGroups
                    ColumnLayout {
                        id: reviewGroup
                        required property var modelData
                        readonly property var items: tab.selectedItems.filter(i => i.kind === modelData.kind)
                        Layout.fillWidth: true
                        visible: items.length > 0
                        spacing: 6
                        Text {
                            text: reviewGroup.modelData.title + " — " + reviewGroup.modelData.note
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: reviewGroup.modelData.kind === "personal" ? UI.Theme.changed : tab.secondary
                            font.pixelSize: tab.px(12)
                            font.weight: Font.Medium
                        }
                        ListSurface {
                            Repeater {
                                model: reviewGroup.items
                                EntryRow {
                                    required property var modelData
                                    required property int index
                                    path: modelData.path || modelData.source || ""
                                    first: index === 0
                                    selectable: true
                                    selected: true
                                    objectName: "reviewEntry-" + index + "-" + reviewGroup.modelData.kind
                                    glyph: reviewGroup.modelData.kind === "cache" ? "ic_clock" : "ic_folder"
                                    glyphColor: reviewGroup.modelData.kind === "cache" ? UI.Theme.positive : UI.Theme.changed
                                    title: modelData.name
                                    subtitle: tab.tidy(modelData.path)
                                    sizeText: tab.bytes(modelData.size)
                                    canDelete: false
                                    onToggled: tab.toggleSelected(modelData, modelData.kind)
                                }
                            }
                        }
                    }
                }
                Hint {
                    text: qsTr("Untick anything you want to keep.")
                }
            }

            // ── Security ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: tab.lens === "security"
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    UI.Icon {
                        visible: tab.scanOk
                        source: Qt.resolvedUrl("assets/" + (tab.attentionCount > 0 ? "ic_warning" : "ic_check") + ".svg")
                        isMask: true
                        color: tab.countOf("high") > 0 ? UI.Theme.negative : tab.attentionCount > 0 ? UI.Theme.changed : UI.Theme.positive
                        implicitWidth: 20
                        implicitHeight: 20
                    }
                    Text {
                        Layout.fillWidth: true
                        text: tab.isScanning && !tab.scan ? qsTr("Scanning the kept folders…") : !tab.scanOk ? "" : tab.attentionCount === 0 ? qsTr("Nothing needs your attention") : [tab.countOf("high") > 0 ? qsTr("%n to check now", "", tab.countOf("high")) : "", tab.countOf("medium") > 0 ? qsTr("%n to review", "", tab.countOf("medium")) : ""].filter(s => s !== "").join(" · ")
                        textFormat: Text.PlainText
                        color: tab.textColor
                        font.pixelSize: tab.px(14)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    UI.ActionButton {
                        objectName: "impermanenceRescan"
                        text: tab.isScanning ? qsTr("Scanning…") : qsTr("Scan again")
                        glyph: Qt.resolvedUrl("assets/ic_refresh.svg")
                        flatStyle: true
                        implicitHeight: 32
                        font.pixelSize: tab.px(12)
                        enabled: !tab.isScanning
                        onClicked: tab.scanRequested(true)
                    }
                }
                Hint {
                    text: qsTr("A reboot wipes everything else, so anything planted to come back has to live in these folders. This looks for things that start by themselves, programs in places meant for documents, and names made to hide. It is a quick check, not an antivirus.")
                }
                ErrorNotice {
                    result: tab.scan
                }

                Repeater {
                    model: [
                        {
                            id: "high",
                            title: qsTr("Check now"),
                            note: qsTr("Commands that download and run code, forced libraries and setuid files.")
                        },
                        {
                            id: "medium",
                            title: qsTr("Review"),
                            note: qsTr("Recently changed autostart entries, programs in data folders and unusual permissions. Often legitimate.")
                        },
                        {
                            id: "minor",
                            title: qsTr("Notes"),
                            note: qsTr("Things that start with your session or system. Listed so you know they are there.")
                        }
                    ]
                    ColumnLayout {
                        id: group
                        required property var modelData
                        readonly property bool minor: modelData.id === "minor"
                        readonly property var items: tab.findings.filter(f => group.minor ? tab.severityRank[f.severity] > 1 : f.severity === group.modelData.id)
                        Layout.fillWidth: true
                        visible: items.length > 0
                        spacing: 6
                        ListHeading {
                            title: group.modelData.title + " · " + group.items.length
                            note: group.modelData.note
                            textColor: group.modelData.id === "high" ? UI.Theme.negative : group.modelData.id === "medium" ? UI.Theme.changed : tab.textColor
                            UI.ActionButton {
                                visible: group.minor
                                text: tab.showMinor ? qsTr("Hide") : qsTr("Show")
                                flatStyle: true
                                implicitHeight: 30
                                font.pixelSize: tab.px(11)
                                onClicked: tab.showMinor = !tab.showMinor
                            }
                        }
                        ListSurface {
                            visible: !group.minor || tab.showMinor
                            Repeater {
                                model: !group.minor || tab.showMinor ? group.items : []
                                EntryRow {
                                    required property var modelData
                                    required property int index
                                    path: modelData.path || modelData.source || ""
                                    first: index === 0
                                    glyph: modelData.severity === "high" || modelData.severity === "medium" ? "ic_warning" : "ic_info"
                                    glyphColor: tab.severityTone(modelData.severity)
                                    title: modelData.category
                                    subtitle: modelData.path !== "" ? tab.tidy(modelData.path) : ""
                                    monoSubtitle: true
                                    detail: modelData.detail
                                    showOpen: modelData.path !== ""
                                    showCopy: modelData.path !== ""
                                    canDelete: modelData.path !== ""
                                    confirming: modelData.path !== "" && tab.pendingPath === modelData.path
                                    onDeleteAsked: tab.pendingPath = modelData.path
                                    onDeleteCancelled: tab.pendingPath = ""
                                    onDeleteConfirmed: tab.removeOne(modelData.path, tab.baseName(modelData.path))
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: tab.scanOk
                    spacing: 8
                    Hint {
                        text: tab.scan && tab.scan.clamav ? qsTr("For a signature-based check, run ClamAV over the kept folders. It opens in a terminal.") : qsTr("For a signature-based check, install ClamAV (pkgs.clamav) and run freshclam once.")
                    }
                    UI.ActionButton {
                        visible: !!tab.scan && tab.scan.clamav
                        text: qsTr("Deep scan")
                        glyph: Qt.resolvedUrl("assets/ic_terminal.svg")
                        implicitHeight: 32
                        font.pixelSize: tab.px(12)
                        onClicked: tab.clamScanRequested()
                    }
                }
                Hint {
                    visible: tab.scanOk
                    text: qsTr("Files that link into the Nix store come from your configuration and are skipped. Container images, game libraries and caches are not inspected. Key material is never read.")
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 4
            }
        }
    }

    // ── Selection bar ────────────────────────────────────────────────────
    // Cleanup goes through a review page; inside a folder the bar itself asks.
    // More can be picked while a batch runs; each row shows its outcome.
    Rectangle {
        id: selectionBar
        objectName: "impermanenceSelectionBar"
        readonly property bool inCleanup: tab.lens === "cleanup"
        readonly property bool asking: tab.reviewing && !inCleanup
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: (inCleanup || tab.lens === "folders") && tab.selectedCount > 0
        implicitHeight: barRow.implicitHeight + 18
        radius: 10
        color: UI.Theme.wash(asking ? UI.Theme.negative : tab.accentColor, .09)
        RowLayout {
            id: barRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: selectionBar.asking ? qsTr("Delete %1 (%2) for good?").arg(tab.itemCount(tab.selectedCount)).arg(tab.bytes(tab.selectedBytes)) : qsTr("%1 selected · %2").arg(tab.selectedCount).arg(tab.bytes(tab.selectedBytes))
                color: selectionBar.asking ? UI.Theme.negative : tab.textColor
                font.pixelSize: tab.px(12)
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            UI.ActionButton {
                text: tab.reviewing ? (selectionBar.inCleanup ? qsTr("Back") : qsTr("Cancel")) : qsTr("Clear")
                flatStyle: true
                implicitHeight: 32
                font.pixelSize: tab.px(12)
                onClicked: {
                    if (tab.reviewing)
                        tab.reviewing = false;
                    else
                        tab.clearSelection();
                }
            }
            UI.ActionButton {
                objectName: "impermanenceReview"
                text: tab.reviewing ? qsTr("Delete %1").arg(tab.itemCount(tab.selectedCount)) : selectionBar.inCleanup ? qsTr("Review selected") : qsTr("Delete…")
                glyph: !tab.reviewing && !selectionBar.inCleanup ? Qt.resolvedUrl("assets/ic_delete.svg") : ""
                primary: true
                accent: tab.reviewing || !selectionBar.inCleanup ? UI.Theme.negative : tab.accentColor
                implicitHeight: 32
                font.pixelSize: tab.px(12)
                onClicked: {
                    if (tab.reviewing) {
                        tab.deleteSelected();
                    } else {
                        tab.reviewing = true;
                        if (selectionBar.inCleanup)
                            scroll.ScrollBar.vertical.position = 0;
                    }
                }
            }
        }
    }
}
