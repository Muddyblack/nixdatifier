import QtQuick
import QtTest
import "../package/contents/ui" as App
import "../package/contents/ui/shared" as UI

Item {
    id: host
    width: 700
    height: 1000
    property bool holdTerminal: false
    property var terminalJobs: []
    App.Settings {
        id: cfg
        showNotifications: false
        showPackageIcons: false
        enableMotion: true
    }
    Component {
        id: executor
        QtObject {
            function exec(cmd, cb) {
                if (host.holdTerminal && cmd.indexOf("/terminal'") >= 0) {
                    host.terminalJobs.push({
                        cmd: cmd,
                        callback: cb
                    });
                    return;
                }
                Qt.callLater(function () {
                    cb(cmd, "", "", 0);
                });
            }
        }
    }
    App.Engine {
        id: core
        settings: cfg
        executor: executor
        autoStart: false
        expanded: true
    }
    App.ApplicationView {
        id: app
        anchors.fill: parent
        engine: core
    }
    SignalSpy {
        id: commandSpy
        target: app
        signalName: "runCommand"
    }
    TestCase {
        name: "SharedView"
        when: windowShown
        function test_persistent_folders_tab_appears_only_when_detected() {
            core.impermanence = core.emptyImpermanence;
            const navigation = findChild(app, "tab-impermanence");
            verify(!navigation.visible);
            verify(!app.tools.some(t => t.key === "impermanence"));
            core.impermanence = core.parseImpermanence("volatile\tyes\ttmpfs\npersist\t/persist\tbind\t2\text4\t1000\t500\t500\n");
            verify(navigation.visible);
            verify(!app.tools.some(t => t.key === "impermanence"));
            wait(50);
            mouseClick(navigation);
            compare(core.activeViewMode, "impermanence");
            verify(navigation.selected);
            verify(!app.inTools);
            compare(app.activeTool, null);
            verify(!findChild(app, "toolsOverlay").visible);
            const content = findChild(app, "impermanenceTab");
            verify(content.visible);
            compare(content.parent.objectName, "viewBody");
        }
        function test_persistent_folders_tab_shows_folders_findings_and_confirms_deletes() {
            core.impermanence = core.parseImpermanence("volatile\tyes\ttmpfs\npersist\t/persist\tbind\t1\text4\t1000\t500\t500\nentry\td\t/home/u/.ssh\t/persist/home/u/.ssh\n");
            core.impermanenceListing = core.parseImpermanenceListing("D\t/persist/home/u\t/persist\t5000\t12\t1700000000\n" + "C\td\t4000\t10\t1700000000\t1700000000\t755\tu\th\t\t.cache\n" + "C\td\t1000\t2\t1700000000\t1700000000\t700\tu\th\t\t.ssh\n");
            core.activeViewMode = "impermanence";
            wait(50);
            const tab = findChild(app, "impermanenceTab");
            verify(tab.visible);
            compare(tab.shownItems.length, 2);
            compare(tab.crumbs.length, 3);
            // Entries bound by the configuration cannot be deleted from here.
            verify(tab.isBound(tab.shownItems[1]));
            verify(!tab.isBound(tab.shownItems[0]));
            tab.pendingPath = tab.shownItems[0].path;
            wait(20);
            tab.setLens("security");
            compare(tab.pendingPath, "");
            core.impermanenceScan = core.parseImpermanenceScan("high\tSuspicious command\t/persist/a.desktop\tExec=curl x | sh\n" + "low\tRuns automatically\t/persist/b\tnote\n");
            compare(tab.findings.length, 2);
            compare(tab.shownFindings.length, 1);
            compare(tab.minorCount, 1);
            tab.setLens("browse");
        }
        function test_non_nixos_tools() {
            core.isNixOS = false;
            core.activeViewMode = "tools";
            compare(app.releaseLabel, "Nix");
            verify(!app.tools.some(t => t.key === "secrets"));
            verify(app.tools.some(t => t.key === "health"));
            verify(app.tools.some(t => t.key === "devenv"));
            verify(findChild(app, "toolsView").visible);
        }
        function init() {
            core.isNixOS = true;
            core.systemDetected = true;
            host.holdTerminal = false;
            host.terminalJobs = [];
            commandSpy.clear();
            app.commandsOpen = false;
            host.width = 700;
            host.height = 1000;
            core.expanded = true;
            core.toasts = [];
            core.isDryRunning = false;
            core.cancelPendingAction();
            cfg.enableLiveSwitch = true;
            cfg.showDeleteButton = true;
            cfg.confirmBeforeRollback = true;
            cfg.confirmBeforeDelete = true;
            cfg.enableGlow = true;
            cfg.useSystemTextColor = true;
            cfg.showBg = true;
            cfg.showCommandButtons = true;
            core.activeViewMode = "timeline";
            core.selectedGenNum = -1;
            core.generationCounts = {};
            core.generations = [
                {
                    number: 661,
                    timestamp: "2026-09-11 10:01:00",
                    active: true,
                    booted: false
                },
                {
                    number: 660,
                    timestamp: "2026-09-10 13:41:00",
                    active: false,
                    booted: true
                }
            ];
            core.activeGenNum = 661;
            core.bootedGenNum = 660;
            core.detailsCache = {
                661: {
                    diff: [],
                    nixosVer: "26.05",
                    kernelVer: "6.12"
                },
                660: {
                    diff: [],
                    nixosVer: "26.05",
                    kernelVer: "6.12"
                }
            };
            cfg.enableMotion = true;
            wait(50);
        }
        function test_commands_panel_back_escape_and_empty_list() {
            core.activeViewMode = "updates";
            core.selectedGenNum = 661;
            cfg.customCommands = "[]";
            const launcher = findChild(app, "commandsButton");
            const view = findChild(app, "commandsView");
            const main = findChild(app, "mainPage");
            mouseClick(launcher);
            tryCompare(view, "visible", true);
            verify(!main.visible);
            compare(view.entries.length, 0);
            verify(findChild(view, "configureCommands").visible);
            mouseClick(findChild(view, "commandsBack"));
            verify(main.visible);
            verify(!view.visible);
            compare(core.activeViewMode, "updates");
            compare(core.selectedGenNum, 661);
            mouseClick(launcher);
            keyClick(Qt.Key_Escape);
            tryCompare(view, "visible", false);
            verify(launcher.activeFocus);
            mouseClick(launcher);
            mouseClick(findChild(view, "commandsClose"));
            tryCompare(view, "visible", false);
        }
        function test_commands_panel_launches_configured_command_once() {
            host.width = 380;
            host.height = 480;
            host.holdTerminal = true;
            const literal = "printf '%s\\n' 'a command with spaces and quotes'";
            cfg.customCommands = JSON.stringify([
                {
                    label: "My command",
                    cmd: literal
                }
            ]);
            core.activeViewMode = "tools";
            wait(20);
            mouseClick(findChild(app, "commandsButton"));
            const view = findChild(app, "commandsView");
            const row = findChild(view, "command-0");
            verify(row);
            compare(row.label, "My command");
            verify(row.stacked, "Long command text wraps underneath its label");
            verify(row.width <= view.width);
            mouseClick(row);
            compare(commandSpy.count, 1);
            compare(commandSpy.signalArguments[0][0], literal);
            compare(commandSpy.signalArguments[0][1], "My command");
            compare(core.activeViewMode, "tools");
            verify(!view.visible);
            verify(core.isBusy);
            compare(host.terminalJobs.length, 1);
            mouseClick(findChild(app, "commandsButton"));
            verify(!row.enabled);
            mouseClick(row);
            compare(commandSpy.count, 1);
            mouseClick(findChild(view, "commandsBack"));
            host.holdTerminal = false;
            host.terminalJobs[0].callback("", "", "", 0);
            tryCompare(core, "isBusy", false);
        }
        function test_timeline_reaches_next_boot_and_realigns() {
            const timeline = findChild(app, "generationTimeline");
            verify(timeline);
            tryCompare(timeline, "travelAvailable", true);
            verify(timeline.travelStart.y > timeline.travelEnd.y);
            const collapsedDistance = timeline.travelStart.y - timeline.travelEnd.y;
            core.selectedGenNum = 661;
            wait(100);
            verify(timeline.travelStart.y - timeline.travelEnd.y > collapsedDistance);
            tryVerify(function () {
                return timeline.travelProgress > .98;
            }, 2000);
            const marker = findChild(timeline, "travelingMarker");
            fuzzyCompare(marker.color.r, UI.Theme.changed.r, .02);
            fuzzyCompare(marker.color.g, UI.Theme.changed.g, .02);
            fuzzyCompare(marker.color.b, UI.Theme.changed.b, .02);
            tryVerify(() => timeline.travelProgress < .02, 2200);
            fuzzyCompare(marker.color.r, UI.Theme.positive.r, .02);
            fuzzyCompare(marker.color.g, UI.Theme.positive.g, .02);
            fuzzyCompare(marker.color.b, UI.Theme.positive.b, .02);
            cfg.enableMotion = false;
            tryCompare(timeline, "travelProgress", 0);
            compare(marker.color, UI.Theme.positive);
            core.activeViewMode = "updates";
            wait(20);
            compare(timeline.travelProgress, 0);
        }
        function test_preview_toggle_click_keeps_cache() {
            core.activeViewMode = "updates";
            core.flakeUpdates = [
                {
                    input: "nixpkgs",
                    oldRev: "abc",
                    newRev: "def",
                    overrideRef: "github:NixOS/nixpkgs/def",
                    url: "https://github.com/NixOS/nixpkgs"
                }
            ];
            core.dryRunCache = {
                nixpkgs: {
                    status: "ok",
                    packages: []
                }
            };
            wait(30);
            const view = findChild(app, "updatesView"), button = findChild(view, "preview-nixpkgs");
            verify(button);
            verify(button.tip.length > 0);
            verify(findChild(view, "update-nixpkgs").tip.indexOf("nixpkgs") >= 0);
            verify(findChild(view, "source-nixpkgs").tip.length > 0);
            mouseClick(button);
            verify(view.openPreviews.nixpkgs);
            core.isDryRunning = true;
            mouseClick(button);
            verify(!view.openPreviews.nixpkgs);
            verify(core.dryRunCache.nixpkgs);
            mouseClick(button);
            verify(view.openPreviews.nixpkgs);
            core.isDryRunning = false;
        }
        function test_release_notes_render_in_open_card() {
            core.activeViewMode = "updates";
            core.flakeUpdates = [
                {
                    input: "hyprland",
                    oldRev: "abc",
                    newRev: "def",
                    overrideRef: "github:hyprwm/Hyprland/def",
                    url: "https://github.com/hyprwm/Hyprland"
                }
            ];
            core.dryRunCache = {
                hyprland: {
                    status: "ok",
                    packages: []
                }
            };
            core.releaseNotesCache = {
                hyprland: {
                    status: "ok",
                    compareUrl: "https://github.com/hyprwm/Hyprland/compare/abc...def",
                    releases: [
                        {
                            tag: "v0.56.0",
                            name: "",
                            date: "2026-07-20T08:36:24Z",
                            url: "https://example.invalid",
                            body: "## New"
                        }
                    ],
                    commits: [
                        {
                            sha: "5a78b5e927345860",
                            message: "keybinds: fix",
                            author: "dev",
                            date: "2026-10-06T13:20:44Z",
                            url: "https://example.invalid"
                        }
                    ],
                    moreCommits: true
                }
            };
            wait(30);
            const view = findChild(app, "updatesView");
            mouseClick(findChild(view, "preview-hyprland"));
            const notes = findChild(view, "notes-hyprland");
            verify(notes);
            tryVerify(() => notes.visible);
            compare(notes.releases.length, 1);
            compare(notes.commits.length, 1);
            verify(findChild(notes, "compareLink").visible);
            core.releaseNotesCache = {};
        }
        function test_compare_selection_preserves_direction() {
            app.openCompareInDiffTab(661, 660);
            compare(core.activeViewMode, "diff");
            compare(core.pairDiffA, 661);
            compare(core.pairDiffB, 660);
        }
        function test_compare_picker_renders_and_selects_generation() {
            host.width = 380;
            host.height = 480;
            core.activeViewMode = "diff";
            wait(30);
            const source = findChild(app, "compare-source");
            const target = findChild(app, "compare-target");
            const selectedText = findChild(source, "generationPickerText");
            source.currentIndex = 1;
            compare(selectedText.text, "#660 · Booted");
            verify(UI.Theme.contrast(selectedText.color, cfg.bgColor) >= 4.5);
            verify(selectedText.width > 0 && selectedText.height > 0);
            fuzzyCompare(source.width, target.width, 1);
            mouseClick(source);
            tryCompare(source.popup, "opened", true);
            tryVerify(() => source.popup.contentItem.itemAtIndex(0) !== null);
            const option = source.popup.contentItem.itemAtIndex(0);
            compare(source.popup.popupType, 0); // Popup.Item stays on the grabbed panel.
            mouseMove(option, option.width / 2, option.height / 2);
            wait(80);
            verify(source.popup.opened);
            verify(option.visible);
            compare(option.contentItem.text, "#661 · Next boot");
            mouseClick(option);
            tryCompare(source.popup, "visible", false);
            compare(source.currentValue, 661);
            compare(selectedText.text, "#661 · Next boot");
            target.currentIndex = 1;
            compare(findChild(target, "generationPickerText").text, "#660 · Booted");
        }
        function test_compare_package_search() {
            core.pairDiffCache = {
                "661_660": {
                    diff: [
                        {
                            name: "codex",
                            type: "upgrade",
                            oldVersion: "1",
                            newVersion: "2"
                        },
                        {
                            name: "firefox",
                            type: "added",
                            newVersion: "1"
                        }
                    ]
                }
            };
            app.openCompareInDiffTab(661, 660);
            const packages = findChild(app, "comparePackages");
            const search = findChild(packages, "packageSearch");
            search.text = "  CoDeX  ";
            compare(packages.filtered.length, 1);
            compare(packages.filtered[0].name, "codex");
            search.text = "missing-app";
            compare(packages.filtered.length, 0);
            search.forceActiveFocus();
            keyClick(Qt.Key_Escape);
            compare(search.text, "");
            compare(packages.filtered.length, 2);
            compare(core.activeViewMode, "diff");
        }
        function test_empty_search_keeps_timeline_rail() {
            const timeline = findChild(app, "generationTimeline");
            const search = findChild(timeline, "generationSearch");
            const rail = findChild(timeline, "emptyTimelineRail");
            search.text = "no-matching-generation";
            wait(30);
            verify(rail.visible);
            verify(rail.height >= 64);
            compare(findChild(timeline, "generationCount").text, "2 generations");
            verify(!timeline.travelAvailable);
            mouseClick(findChild(timeline, "clearGenerationSearch"));
            tryCompare(rail, "visible", false);
            compare(search.text, "");
            tryCompare(timeline, "travelAvailable", true);
        }
        function test_inline_generation_actions_keep_confirmations_and_guards() {
            core.generations = core.generations.concat([
                {
                    number: 659,
                    active: false,
                    booted: false
                }
            ]);
            core.detailsCache = Object.assign({}, core.detailsCache, {
                659: {
                    diff: []
                }
            });
            core.selectedGenNum = 659;
            wait(50);
            const list = findChild(app, "generationList");
            tryVerify(() => list.itemAtIndex(2) !== null);
            const row = list.itemAtIndex(2);
            const activate = findChild(row, "activate-659");
            const boot = findChild(row, "setBoot-659");
            const remove = findChild(row, "delete-659");
            for (const entry of [[activate, "switch"], [boot, "rollback"], [remove, "delete"]]) {
                verify(entry[0].visible && entry[0].enabled);
                mouseClick(entry[0]);
                compare(core.pendingAction, entry[1]);
                compare(core.pendingGenNum, 659);
                compare(core.selectedGenNum, 659);
                verify(!core.isBusy, "Clicking an action must wait for its configured confirmation");
                core.cancelPendingAction();
            }
            verify(!findChild(list.itemAtIndex(0), "delete-661").enabled);
            verify(!findChild(list.itemAtIndex(1), "delete-660").enabled);
            cfg.enableLiveSwitch = false;
            cfg.showDeleteButton = false;
            verify(!activate.visible);
            verify(!remove.visible);
            core.isBusy = true;
            verify(!boot.enabled);
            wait(20);
            mouseClick(boot);
            compare(core.selectedGenNum, 659, "A disabled header action must not collapse the card");
            core.isBusy = false;
            const toggle = findChild(row, "toggleGeneration-659");
            mouseClick(toggle);
            compare(core.selectedGenNum, -1);
            mouseClick(toggle);
            compare(core.selectedGenNum, 659);
        }
        function test_generation_dates_and_counts_keep_their_baseline() {
            const row = findChild(app, "generationList").itemAtIndex(0);
            const today = new Date(2026, 8, 11, 15, 0);
            compare(row.friendlyTimestamp("2026-09-11 10:01:12", today), "Today, 10:01");
            compare(row.friendlyTimestamp("2026-09-10 13:41:00", today), "Yesterday, 13:41");
            compare(row.friendlyTimestamp("2026-12-31 23:59:00", new Date(2027, 0, 1, 0, 5)), "Yesterday, 23:59");
            compare(row.friendlyTimestamp("2026-03-28 10:00:00", new Date(2026, 2, 29, 13)), "Yesterday, 10:00");
            verify(row.friendlyTimestamp("2025-12-20 10:00:00", today).indexOf("2025") >= 0);
            compare(row.friendlyTimestamp("unknown", today), "unknown");
            core.detailsCache = {
                661: {
                    partial: true,
                    diff: []
                }
            };
            compare(row.changeSummary, null, "Partial summaries must not show fake zero counts");
            core.detailsCache = {
                661: {
                    diffMode: "booted",
                    diff: [
                        {
                            type: "added"
                        }
                    ]
                }
            };
            compare(row.changeSummary, null, "A comparison to booted cannot stand in for the previous generation");
            core.generationCounts = {
                661: {
                    status: "ok",
                    added: 2,
                    removed: 4,
                    changed: 3
                }
            };
            compare(row.changeSummary.added, 2);
            compare(row.changeSummary.removed, 4);
            compare(row.changeSummary.changed, 3);
            verify(findChild(row, "generationChanges-661").visible);
        }
        function test_rail_blends_node_colors_and_follows_expansion() {
            const timeline = findChild(app, "generationTimeline");
            tryVerify(() => timeline.railSegments.length === 3);
            let segment = timeline.railSegments[1];
            verify(Qt.colorEqual(segment.startColor, UI.Theme.wash(UI.Theme.changed, .7)));
            verify(Qt.colorEqual(segment.endColor, UI.Theme.wash(UI.Theme.positive, .7)));
            const distance = segment.endY - segment.y;
            core.selectedGenNum = 661;
            tryVerify(() => timeline.railSegments[1].endY - timeline.railSegments[1].y > distance);
            core.selectedGenNum = -1;
            tryCompare(timeline, "travelAvailable", true);
        }
        function test_all_navigation_and_small_geometry() {
            for (const tab of ["timeline", "updates", "diff", "tools", "secrets", "hash"]) {
                core.activeViewMode = tab;
                wait(15);
            }
            host.width = 380;
            host.height = 480;
            wait(30);
            verify(app.width === 380);
            host.width = 700;
            host.height = 1000;
        }
        function test_feedback_and_tools_keep_footer_clear() {
            host.width = 380;
            host.height = 480;
            core.activeViewMode = "tools";
            wait(50);
            const body = findChild(app, "viewBody");
            const footer = findChild(app, "storageFooter");
            const tools = findChild(app, "toolsView");
            const indicator = findChild(app, "feedbackIndicator");
            const popup = findChild(app, "feedbackDetails");
            const commands = findChild(app, "commandsButton");
            const before = {
                y: body.y,
                height: body.height,
                footer: footer.y
            };
            core.isDryRunning = true;
            wait(20);
            compare(body.y, before.y);
            compare(body.height, before.height);
            compare(footer.y, before.footer);
            const status = findChild(app, "footerStatus");
            const progress = findChild(app, "footerProgress");
            compare(status.text, core.busyLabel);
            verify(progress.visible);
            verify(progress.mapToItem(app, 0, 0).y >= footer.y);
            core.isDryRunning = false;
            verify(tools.contentHeight > tools.availableHeight, "Tools must scroll in the short window");
            verify(body.clip && tools.clip);
            verify(body.y + body.height <= footer.y);
            core.pushToast("Could not reach: nixpkgs", true);
            wait(30);
            verify(indicator.visible);
            verify(commands.visible);
            verify(!popup.opened, "Feedback details must never open automatically");
            compare(body.y, before.y);
            compare(body.height, before.height);
            compare(footer.y, before.footer);
            verify(indicator.mapToItem(app, 0, 0).y >= footer.y);
            mouseClick(indicator);
            tryCompare(popup, "opened", true);
            popup.close();
            tryCompare(popup, "visible", false);
        }
        function test_custom_dark_background_with_light_desktop() {
            UI.Theme.systemTextColor = "#000000";
            UI.Theme.systemBackgroundColor = "#eff0f1";
            wait(10);
            const title = findChild(app, "widgetTitle");
            verify(UI.Theme.contrast(title.color, cfg.bgColor) >= 4.5);
            compare(title.font.pixelSize, 16);
            cfg.useSystemTextColor = false;
            cfg.customTextColor = "#ffcc88";
            compare(core.textColor, Qt.color("#ffcc88"));
            UI.Theme.systemTextColor = UI.Theme.textColor;
            UI.Theme.systemBackgroundColor = UI.Theme.backgroundColor;
        }
        function test_header_generation_numbers_follow_system_state() {
            const booted = findChild(app, "bootedGenerationLabel");
            const next = findChild(app, "nextGenerationLabel");
            compare(booted.text, "#660");
            compare(next.text, "#661");
            verify(next.visible);
            core.bootedGenNum = 661;
            wait(10);
            compare(booted.text, "#661");
            verify(!next.visible, "When already booted, show the green generation only");
        }
        function test_header_flags_running_test_build() {
            const label = findChild(app, "testBuildLabel");
            verify(!label.visible);
            core.runningTestBuild = true;
            wait(10);
            verify(label.visible);
            verify(findChild(app, "headerGenerations").description.indexOf("test build") >= 0);
            core.runningTestBuild = false;
        }
        function test_marker_survives_scroll_and_glow_disabled() {
            host.height = 480;
            cfg.enableGlow = false;
            const timeline = findChild(app, "generationTimeline");
            const list = findChild(timeline, "generationList");
            tryCompare(timeline, "travelAvailable", true);
            tryVerify(() => timeline.travelProgress > .2);
            const progress = timeline.travelProgress;
            for (let i = 0; i < 5; i++)
                timeline.updateTravel();
            verify(timeline.travelProgress >= progress, "Geometry updates must not restart travel");
            list.contentY = 30;
            wait(20);
            verify(timeline.travelEnd.y < 0);
            verify(timeline.travelAvailable, "The marker keeps traveling to the clipped next-boot row");
            tryVerify(() => timeline.travelProgress > .98, 2000);
            core.expanded = false;
            tryCompare(timeline, "travelProgress", 0);
            core.expanded = true;
            tryVerify(() => timeline.travelProgress > .1);
            list.contentY = 0;
        }
    }
}
