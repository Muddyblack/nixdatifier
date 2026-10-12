import QtQuick
import QtTest
import "../package/contents/ui" as App

Item {
    width: 600
    height: 740
    App.Settings {
        id: cfg
        showNotifications: false
        showPackageIcons: false
    }
    Component {
        id: executor
        QtObject {
            function exec(cmd, cb) {
                jobs.push({
                    cmd: cmd,
                    callback: cb
                });
            }
        }
    }
    property var jobs: []
    App.Engine {
        id: core
        settings: cfg
        executor: executor
        autoStart: false
    }
    App.UpdatesTab {
        id: updates
        width: 550
        height: 550
        activeViewMode: "updates"
        accentColor: "#91bcff"
        textColor: "white"
        fs: 1
        isCheckingFlake: false
        lastFlakeCheckTime: ""
        iconStyle: "colored"
        flakeUpdates: core.flakeUpdates
        dryRunCache: core.dryRunCache
        isDryRunning: core.isDryRunning
        onDryRunRequested: (name, ref) => core.runDryPreview(name, ref)
    }
    TestCase {
        name: "SharedEngine"
        when: windowShown
        function init() {
            core.isNixOS = true;
            core.systemDetected = true;
            jobs = [];
            core.isBusy = false;
            core.isLoadingHistory = false;
            core.isLoadingGens = false;
            core.isLoadingSecrets = false;
            core.isProbingImpermanence = false;
            core.isListingImpermanence = false;
            core.isScanningImpermanence = false;
            core.isAnalyzingImpermanence = false;
            core.isRemovingImpermanence = false;
            core.activeJobs = 0;
            core.isLoadingPairDiff = false;
            core.isLoadingDetails = false;
            core.isDryRunning = false;
            core.dryRunCache = {};
            core.flakeUpdates = [];
            core.detailsCache = {};
            core.expanded = false;
            core.countingChanges = false;
            core.countsQueue = [];
            core.generationCounts = {};
            core.pairDiffCache = {};
            core.toasts = [];
            core.flakeEpoch = 0;
            core.resolvedFlakePath = "/tmp/test flake's dir";
            core.lockFingerprint = "lock-a";
            core.iconCache = {};
            core.metaCache = {};
            updates.openPreviews = {};
            core.generations = [
                {
                    number: 661,
                    active: true,
                    booted: false
                },
                {
                    number: 660,
                    active: false,
                    booted: true
                }
            ];
            core.activeGenNum = 661;
            core.bootedGenNum = 660;
        }
        function test_non_nixos_startup_and_guards() {
            core.isNixOS = false;
            core.systemDetected = false;
            core.activeViewMode = "tools";
            core.start();
            compare(jobs.length, 3); // sysinfo, history and the persistent-folder check
            verify(jobs[0].cmd.indexOf("/sysinfo'") >= 0);
            jobs[0].callback(jobs[0].cmd, "ubuntu--- ---1h--- --- ---0", "", 0);
            compare(core.isNixOS, false);
            compare(core.systemDetected, true);
            compare(core.activeViewMode, "tools");
            compare(jobs.length, 3);
            core.refreshGenerations();
            core.probeSecrets();
            core.refreshFlakeContext();
            core.checkFlakeUpdates();
            core.executeAction(661, "delete");
            core.executeCleanup("gc-all");
            core.runDryPreview("nixpkgs", "");
            core.runCustomCommand("nixos-rebuild switch", "Rebuild");
            compare(jobs.length, 3);
            core.activeViewMode = "health";
            core.parseSysInfo("ubuntu--- ---2h--- --- ---0");
            compare(core.activeViewMode, "health");
        }
        function test_nixos_startup_waits_for_detection() {
            core.isNixOS = false;
            core.systemDetected = false;
            core.start();
            compare(jobs.length, 3);
            jobs[0].callback(jobs[0].cmd, "host---26.05---1h---today--- ---1", "", 0);
            compare(core.isNixOS, true);
            compare(core.activeViewMode, cfg.defaultView || "timeline");
            verify(jobs.some(j => j.cmd.indexOf("/generations'") >= 0));
            verify(jobs.some(j => j.cmd.indexOf("/secrets'") >= 0));
            verify(jobs.some(j => j.cmd.indexOf("/flake-context'") >= 0));
            core.isLoadingGens = false;
            core.isLoadingSecrets = false;
        }
        function test_failed_detection_keeps_system_actions_disabled() {
            core.isNixOS = false;
            core.systemDetected = false;
            core.start();
            jobs[0].callback(jobs[0].cmd, "", "failed", 1);
            compare(core.isNixOS, false);
            compare(core.systemDetected, false);
            compare(jobs.length, 3);
            verify(core.toasts.length > 0);
        }
        function fixtureInput() {
            return {
                input: "nixpkgs",
                oldRev: "abc",
                newRev: "def",
                revisionKey: "abc\ndef",
                overrideRef: "github:NixOS/nixpkgs/def",
                url: "https://github.com/NixOS/nixpkgs"
            };
        }
        function test_package_lookups_share_pending_work_and_retry_errors() {
            cfg.showPackageIcons = true;
            const packages = [
                {
                    name: "test-package"
                },
                {
                    name: "test-package"
                }
            ];
            core.loadIcons(packages);
            core.loadIcons(packages);
            core.loadMeta(packages);
            core.loadMeta(packages);
            compare(jobs.length, 2);
            jobs[0].callback(jobs[0].cmd, "", "failed", 1);
            jobs[1].callback(jobs[1].cmd, "", "failed", 1);
            core.loadIcons(packages);
            core.loadMeta(packages);
            compare(jobs.length, 4);
            jobs[2].callback(jobs[2].cmd, "test-package\tapp-icon", "", 0);
            jobs[3].callback(jobs[3].cmd, "test-package\thttps://example.org\tnixpkgs", "", 0);
            core.loadIcons(packages);
            core.loadMeta(packages);
            compare(jobs.length, 4);
            compare(core.iconCache["test-package"], "app-icon");
            compare(core.metaCache["test-package"].url, "https://example.org");
            compare(Object.keys(core.pendingIcons).length, 0);
            compare(Object.keys(core.pendingMeta).length, 0);
            cfg.showPackageIcons = false;
        }
        function test_flake_failure_notice_includes_reason() {
            core.parseFlakeProbe("nixpkgs\tunreachable\told\t\t0\turl\t\tDNS lookup failed", true, true);
            compare(core.toasts.length, 1);
            verify(core.toasts[0].msg.includes("nixpkgs (DNS lookup failed)"));
        }
        function test_generation_counts_deduplicate_and_reject_stale_results() {
            core.activeViewMode = "timeline";
            core.generations = [
                {
                    number: 661,
                    storePath: "/nix/store/new"
                },
                {
                    number: 660,
                    storePath: "/nix/store/old"
                }
            ];
            core.requestGenerationCounts(661);
            core.requestGenerationCounts(661);
            compare(core.countsQueue.length, 1);
            core.loadNextGenerationCounts();
            compare(jobs.length, 0, "Counts wait while the popup is closed");
            core.expanded = true;
            core.isBusy = true;
            core.loadNextGenerationCounts();
            compare(jobs.length, 0, "User mutations take priority");
            core.isBusy = false;
            core.loadNextGenerationCounts();
            compare(jobs.length, 1);
            verify(core.countingChanges);
            core.loadNextGenerationCounts();
            compare(jobs.length, 1);
            const oldJob = jobs[0];
            core.generations = [
                {
                    number: 661,
                    storePath: "/nix/store/replaced"
                },
                core.generations[1]];
            core.requestGenerationCounts(661);
            oldJob.callback(oldJob.cmd, '{"added":99,"removed":0,"changed":0}', "", 0);
            compare(core.generationCounts[661].status, "loading");
            core.loadNextGenerationCounts();
            const newJob = jobs[1];
            newJob.callback(newJob.cmd, '{"added":2,"removed":4,"changed":3}', "", 0);
            compare(core.generationCounts[661].added, 2);
            compare(core.generationCounts[661].removed, 4);
            compare(core.generationCounts[661].changed, 3);
            core.requestGenerationCounts(661);
            compare(core.countsQueue.length, 0);
            compare(core.activeJobs, 0);
            core.expanded = false;
        }
        function test_generation_count_errors_stay_unknown_and_pause_retries() {
            core.activeViewMode = "timeline";
            core.generations = [
                {
                    number: 661,
                    storePath: "/nix/store/new",
                    previousNumber: 660,
                    previousStorePath: "/nix/store/old"
                }
            ];
            compare(core.countPair(661).baseNum, 660, "The last displayed generation keeps its earlier baseline");
            compare(core.getPreviousGen(661), 660, "Expanded details use the same baseline as the header counts");
            core.expanded = true;
            core.requestGenerationCounts(661);
            core.loadNextGenerationCounts();
            const job = jobs[0];
            job.callback(job.cmd, '{"added":-1,"removed":0,"changed":0}', "", 0);
            compare(core.generationCounts[661].status, "error");
            verify(core.generationCounts[661].added === undefined);
            core.requestGenerationCounts(661);
            compare(core.countsQueue.length, 0);
            compare(core.toasts.length, 0);
            core.expanded = false;
        }
        function test_pair_diff_first_record_and_direction() {
            core.parsePairDiff(661, 660, "26.05\x1ekernel\x1eone: ∅ → 1.0, +2 KiB\ntwo: 2.0 → ∅, -3 MiB\nthree: 1.0 → 2.0, +1 MiB\x1e123");
            const diff = core.pairDiffCache["661_660"].diff;
            compare(diff.length, 3);
            compare(diff[0].name, "one");
            compare(diff[0].type, "added");
            compare(diff[1].type, "removed");
            compare(diff[2].type, "upgrade");
            compare(diff[1].storeProfile, "/nix/var/nix/profiles/system-660-link");
        }
        function test_summary_cache_still_loads_details() {
            core.detailsCache = {
                661: {
                    partial: true,
                    nixosVer: "26.05"
                }
            };
            core.loadGenDetails(661);
            verify(jobs.some(job => job.cmd.indexOf("/details'") >= 0));
            verify(core.isLoadingDetails);
        }
        function test_collapse_preserves_preview_and_does_not_relaunch() {
            const input = fixtureInput();
            core.flakeUpdates = [input];
            core.dryRunCache = {
                nixpkgs: {
                    status: "ok",
                    packages: []
                }
            };
            updates.togglePreview(input);
            verify(updates.openPreviews.nixpkgs);
            core.isDryRunning = true;
            updates.togglePreview(input);
            verify(!updates.openPreviews.nixpkgs);
            verify(core.dryRunCache.nixpkgs.status === "ok");
            updates.togglePreview(input);
            verify(updates.openPreviews.nixpkgs);
            compare(jobs.length, 0);
        }
        function test_preview_timeout_clears_busy_state_and_allows_retry() {
            const input = fixtureInput();
            core.flakeUpdates = [input];
            core.runDryPreview(input.input, input.overrideRef);
            compare(jobs.length, 1);
            verify(jobs[0].cmd.startsWith("timeout --kill-after=5s 180s "));
            jobs[0].callback(jobs[0].cmd, "", "", 124);
            verify(!core.isDryRunning);
            verify(!core.isSpinning);
            compare(core.dryRunCache[input.input].status, "error");
            verify(core.dryRunCache[input.input].errorMsg.includes("timed out"));
            core.runDryPreview(input.input, input.overrideRef);
            compare(jobs.length, 2);
            jobs[1].callback(jobs[1].cmd, "OK: already up to date", "", 0);
            compare(core.dryRunCache[input.input].status, "ok");
        }

        function test_stale_preview_is_not_applied() {
            const input = fixtureInput();
            core.flakeUpdates = [input];
            core.runDryPreview(input.input, input.overrideRef);
            compare(jobs.length, 1);
            verify(core.isSpinning);
            const job = jobs[0];
            core.flakeEpoch++;
            core.dryRunCache = {};
            job.callback(job.cmd, "fetch\tapp\t1\t2", "", 0);
            compare(Object.keys(core.dryRunCache).length, 0);
            verify(!core.isDryRunning);
            verify(!core.isSpinning);
        }
        function test_new_revisions_invalidate_only_changed_previews() {
            core.flakeUpdates = [fixtureInput()];
            core.dryRunCache = {
                nixpkgs: {
                    status: "ok",
                    packages: []
                }
            };
            core.parseFlakeProbe("nixpkgs\tok\tabc\tghi\t0\thttps://github.com/NixOS/nixpkgs\tgithub:NixOS/nixpkgs/ghi", true);
            verify(!core.dryRunCache.nixpkgs);
        }
        function test_input_update_is_quoted_and_exits() {
            core.runFlakeUpdateInput("input's name");
            compare(jobs.length, 1);
            verify(jobs[0].cmd.indexOf(" mutate -- bash -c ") >= 0);
            verify(core.isBusy);
            compare(core.updatingInput, "input's name");
            jobs[0].callback(jobs[0].cmd, "", "failure", 1);
            verify(!core.isBusy);
            compare(core.updatingInput, "");
            verify(core.toasts[0].err);
        }
        function test_parse_generations_detects_unregistered_test_build() {
            const stat = n => "2026-10-11 12:39:05.133214540 -0400 '/nix/var/nix/profiles/system-" + n + "-link' -> '/nix/store/" + n + "-sys'";
            core.parseGenerations(["/nix/store/162-sys", "/nix/store/161-sys", stat(162), stat(161), "current /nix/store/x-test-sys"].join("\n"));
            compare(core.activeGenNum, 162);
            compare(core.bootedGenNum, 161);
            verify(core.runningTestBuild, "current-system matching no generation is a test build");
            core.parseGenerations(["/nix/store/162-sys", "/nix/store/161-sys", stat(162), stat(161), "current /nix/store/162-sys"].join("\n"));
            verify(!core.runningTestBuild);
            core.parseGenerations(["/nix/store/162-sys", stat(162), stat(161)].join("\n"));
            compare(core.activeGenNum, 162);
            compare(core.bootedGenNum, -1);
            verify(!core.runningTestBuild, "An unresolvable current-system is not a test build");
        }
        function test_terminal_completion_tracks_exit_not_generations() {
            core.runCustomCommand("false", "Test");
            verify(core.isBusy);
            verify(core.isSpinning);
            jobs[0].callback(jobs[0].cmd, "", "command failed", 7);
            verify(!core.isBusy);
            verify(core.toasts[0].err);
            verify(core.toasts[0].msg.indexOf("7") >= 0);
        }
        function test_protected_generations_and_disabled_live_switch() {
            core.executeAction(660, "delete");
            core.executeAction(661, "delete");
            cfg.enableLiveSwitch = false;
            core.executeAction(659, "switch");
            cfg.enableLiveSwitch = true;
            compare(jobs.length, 0);
        }
        function test_devenv_output_is_parsed() {
            const text = "dir=/p/app\nname=app\ndirenv=2.37.1\nenvrc_path=/p/app/.envrc\nenvrc_state=blocked\n" + "envrc_uses=use flake,dotenv\ncache_dir=\ncache_mtime=\ncache_size=\nfiles=flake.nix,.envrc\n" + "description=Demo\nlock_inputs=1\nlock_oldest=100\nlock_newest=100\ndevshells=ok\n" + "\x1euse flake\x1enixpkgs\tgithub\tNixOS/nixpkgs\tnixos-unstable\tabc1234\t100\t\x1edefault\nci";
            const r = core.parseDevEnv(text);
            compare(r.name, "app");
            compare(r.envrcState, "blocked");
            compare(r.envrcUses, ["use flake", "dotenv"]);
            compare(r.files, ["flake.nix", ".envrc"]);
            compare(r.cacheTime, 0);
            compare(r.inputs.length, 1);
            compare(r.inputs[0].source, "NixOS/nixpkgs");
            compare(r.inputs[0].rev, "abc1234");
            compare(r.inputs[0].modified, 100);
            compare(r.shells, ["default", "ci"]);
            compare(r.shellsState, "loading");
        }
        function test_devenv_shows_result_before_shells_arrive() {
            core.isProbingDevEnv = false;
            core.probeDevEnv("/p/app");
            const meta = "dir=/p/app\nname=app\nenvrc_state=allowed\nfiles=flake.nix\n";
            jobs[0].callback(jobs[0].cmd, meta + "\x1e\x1e\x1e", "", 0);
            // The fast result is already visible while the flake evaluates.
            compare(core.devEnvResult.name, "app");
            compare(core.devEnvResult.shellsState, "loading");
            compare(jobs.length, 2);
            verify(jobs[1].cmd.indexOf("shells") >= 0);
            jobs[1].callback(jobs[1].cmd, "default\nci\n", "", 0);
            compare(core.devEnvResult.shellsState, "ok");
            compare(core.devEnvResult.shells, ["default", "ci"]);
        }
        function test_devenv_shells_failure_is_not_an_empty_list() {
            core.isProbingDevEnv = false;
            core.probeDevEnv("/p/app");
            jobs[0].callback(jobs[0].cmd, "dir=/p/app\nname=app\nfiles=flake.nix\n\x1e\x1e\x1e", "", 0);
            jobs[1].callback(jobs[1].cmd, "", "", 3);
            compare(core.devEnvResult.shellsState, "unavailable");
        }
        function test_devenv_without_a_flake_skips_shell_evaluation() {
            core.isProbingDevEnv = false;
            core.probeDevEnv("/p/plain");
            jobs[0].callback(jobs[0].cmd, "dir=/p/plain\nname=plain\nfiles=.envrc\n\x1e\x1e\x1e", "", 0);
            compare(jobs.length, 1);
            compare(core.devEnvResult.shellsState, "none");
        }
        function test_health_output_is_parsed() {
            const text = "nixos=1\nrelease=26.05\neol=2026-12-31\nreboot_required=1\nkernel_running=7.2.7\nkernel_next=7.2.8\n" + "boot_total_kb=1000\nboot_avail_kb=100\nnix=nix (Nix) 2.34.0\nhm_generations=3\nhm_newest=100\n" + "\x1esystem\tsshd.service\nuser\tmine.service\n\x1ehttps://a.example\tok\t120\nhttps://b.example\tunreachable\t3000";
            const h = core.parseHealth(text);
            verify(h.nixos);
            verify(h.rebootRequired);
            compare(h.bootEntries, -1);
            compare(h.bootAvailKb, 100);
            compare(h.hmGenerations, 3);
            compare(h.failedUnits.length, 2);
            compare(h.failedUnits[1].scope, "user");
            compare(h.caches[1].status, "unreachable");
            compare(h.caches[0].ms, 120);
        }
        function test_failed_path_and_service_are_one_problem() {
            const text = "nixos=1\n\x1euser\tw.path\tunit-start-limit-hit\tStart request repeated too quickly.\n" + "user\tw.service\tstart-limit-hit\tFailed to start W\n" + "user\tother.service\texit-code\tUnable to acquire bus name\n" + "system\tw.path\tsuccess\t\n\x1e";
            const units = core.parseHealth(text).failedUnits;
            // user w.path folds into user w.service; the system w.path has no service and stays.
            compare(units.length, 3);
            compare(units[0].name, "w.service");
            verify(units[0].paired);
            compare(units[0].result, "start-limit-hit");
            compare(units[0].command, "systemctl --user status w.service");
            compare(units[1].name, "other.service");
            verify(!units[1].paired);
            compare(units[2].command, "systemctl status w.path");
        }
        function test_devenv_actions_run_the_right_commands() {
            core.devEnvAction("allow", "/p/it's");
            verify(jobs[0].cmd.indexOf("direnv allow") === 0);
            verify(jobs[0].cmd.indexOf("'/p/it'\\''s'") > 0);
            jobs[0].callback(jobs[0].cmd, "", "", 0);
            core.isProbingDevEnv = false;
            jobs = [];
            core.devEnvAction("update", "/p/app");
            verify(jobs[0].cmd.indexOf("nix flake update") > 0);
            jobs = [];
            core.devEnvAction("rm-rf", "/p/app");
            compare(jobs.length, 0);
        }
        function test_devenv_probe_failure_is_an_error() {
            core.isProbingDevEnv = false;
            core.probeDevEnv("/nope");
            verify(core.isProbingDevEnv);
            jobs[0].callback(jobs[0].cmd, "", "ERROR: not a directory", 2);
            verify(core.devEnvResult.isError);
            verify(core.devEnvResult.value.indexOf("not a directory") >= 0);
            verify(!core.isProbingDevEnv);
        }
        function test_devenv_discovery_lists_projects() {
            core.discoverDevEnvs();
            jobs[0].callback(jobs[0].cmd, "/home/me/app\tallowed\n/home/me/other\tdenied\n", "", 0);
            compare(core.devEnvProjects.length, 2);
            compare(core.devEnvProjects[0].name, "app");
            compare(core.devEnvProjects[1].state, "denied");
        }
        function test_impermanence_detection_output_is_parsed() {
            const text = "volatile\tyes\tfresh\nrootfs\tbtrfs\npersist\t/persist\tbind\t3\tbtrfs\t1000\t400\t600\n" + "mount\t/home\tbtrfs\t2000\t100\t1900\nentry\td\t/var/lib/bluetooth\t/persist/var/lib/bluetooth\n";
            const r = core.parseImpermanence(text);
            verify(r.detected);
            verify(r.volatile);
            compare(r.volatileWhy, "fresh");
            compare(r.areas.length, 2);
            compare(r.areas[0].binds, 3);
            compare(r.areas[0].avail, 600);
            compare(r.areas[1].kind, "mount");
            compare(r.entries[0].source, "/persist/var/lib/bluetooth");
            verify(!core.parseImpermanence("volatile\tno\t\nrootfs\text4\n").detected);
        }
        function test_impermanence_listing_keeps_escaped_paths_for_actions() {
            const text = "D\t/persist/home/u\t/persist\t5000\t12\t1700000000\n" + "C\td\t4000\t10\t1700000000\t1690000000\t755\tu\th\t\t.cache\n" + "C\tf\t1000\t1\t1600000000\t1600000000\t644\tu\tc\t\tbad\\x0aname\n";
            const l = core.parseImpermanenceListing(text);
            compare(l.dir, "/persist/home/u");
            compare(l.items.length, 2);
            compare(l.items[0].name, ".cache");
            compare(l.items[1].name, "bad\nname");
            // The path handed back to the helper stays in its escaped form.
            compare(l.items[1].path, "/persist/home/u/bad\\x0aname");
            compare(core.unescapePath("a\\\\b\\x41"), "a\\bA");
        }
        function test_impermanence_commands_are_quoted_and_cached() {
            core.impermanence = core.parseImpermanence("volatile\tyes\ttmpfs\npersist\t/persist\tbind\t2\text4\t1\t1\t1\n");
            cfg.impermanencePaths = "/mnt/it's";
            core.listImpermanence("", false);
            compare(jobs.length, 1);
            verify(jobs[0].cmd.indexOf("/run'") > 0);
            verify(jobs[0].cmd.indexOf("cached impermanence 120") > 0);
            verify(jobs[0].cmd.indexOf(" list '/mnt/it'\\''s' '/persist'") > 0);
            core.scanImpermanence(true);
            verify(jobs[1].cmd.indexOf("cached impermanence 0") > 0);
            verify(jobs[1].cmd.indexOf(" scan ") > 0);
            cfg.impermanencePaths = "";
        }
        function test_impermanence_scan_and_cleanup_output_is_parsed() {
            const scan = core.parseImpermanenceScan("meta\tscope\t\t/persist,/home\nmeta\tclamav\t/usr/bin/clamscan\tavailable\n" + "high\tSuspicious command\t/persist/a.desktop\tExec=curl x | sh\nlow\tRuns automatically\t\t\n");
            verify(scan.clamav);
            compare(scan.scope, "/persist,/home");
            compare(scan.findings.length, 2);
            compare(scan.findings[0].severity, "high");
            compare(scan.findings[0].detail, "Exec=curl x | sh");
            const c = core.parseImpermanenceCleanup("M\t1000\t180\nT\tRotated log\t10\t5\t/p/a.gz\nT\tApplication cache\t900\t5\t/p/.cache/x\n" + "S\td\t500\t3\t10\t/p/old\n", 180);
            compare(c.cutoff, 1000);
            compare(c.temp[0].size, 900);
            compare(c.stale[0].count, 3);
        }
        function test_impermanence_removal_retries_with_pkexec_only_when_asked() {
            cfg.usePkexec = true;
            core.removeImpermanencePath("/persist/home/u/x", "x");
            compare(jobs.length, 1);
            verify(jobs[0].cmd.indexOf(" remove ") > 0);
            verify(jobs[0].cmd.indexOf("pkexec") < 0);
            jobs[0].callback(jobs[0].cmd, "", "", 77);
            compare(jobs.length, 2);
            verify(jobs[1].cmd.indexOf("pkexec ") === 0);
            jobs[1].callback(jobs[1].cmd, "removed\n", "", 0);
            verify(!core.isRemovingImpermanence);
            cfg.usePkexec = false;
            jobs = [];
            core.removeImpermanencePath("/persist/home/u/y", "y");
            jobs[0].callback(jobs[0].cmd, "", "", 77);
            verify(!core.isRemovingImpermanence);
            compare(core.toasts[core.toasts.length - 1].err, true);
            cfg.usePkexec = true;
        }
        function test_hash_error_is_not_success() {
            core.runHashProbe("url", "https://example.invalid");
            jobs[0].callback(jobs[0].cmd, "", "network error", 1);
            verify(core.hashResult.isError);
            verify(!core.isProbingHash);
        }
    }
}
