import QtQuick
import QtTest
import "../package/contents/ui" as App
import "../package/contents/ui/shared" as UI

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
            core.autoStart = false;
            core._diskProbeRunning = false;
            core._diskFreeProbeRunning = false;
            core._diskProbeDirty = false;
            core._lastDiskProbeMs = 0;
            core._lastDiskRequestMs = 0;
            core.diskUsageError = "";
            core._impSizesDirty = false;
            core.isMeasuringImpermanence = false;
            core.isBusy = false;
            core.isLoadingHistory = false;
            core.isLoadingGens = false;
            core.isLoadingSecrets = false;
            core.isProbingImpermanence = false;
            core.isListingImpermanence = false;
            core.isScanningImpermanence = false;
            core.isAnalyzingImpermanence = false;
            core.isRemovingImpermanence = false;
            core.impermanenceRemovalStates = ({});
            core.activeJobs = 0;
            core.isLoadingPairDiff = false;
            core.isLoadingDetails = false;
            core.isDryRunning = false;
            core.dryRunCache = {};
            core.flakeUpdates = [];
            core.detailsCache = {};
            core.configDiffCache = {};
            core.storePathCache = {};
            core.shellPackages = {};
            core.pendingIcons = {};
            core.pendingMeta = {};
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
        function test_generation_caches_release_removed_history_and_late_results() {
            core.detailsCache = {
                661: {
                    partial: false
                },
                660: {
                    partial: false
                }
            };
            core.configDiffCache = {
                660: {
                    diff: "old configuration"
                }
            };
            core.generationCounts = {
                660: {
                    status: "ok"
                }
            };
            core.countsQueue = [
                {
                    number: 660
                }
            ];
            core.pairDiffCache = {
                "661_660": {
                    diff: []
                }
            };
            core.loadGenSummaries();
            core.loadConfigDiff(661);
            core.detailsCache = {};
            core.loadGenDetails(660);
            core.pairDiffCache = {};
            core.comparePair(661, 660);
            const pending = jobs.slice();
            core.generations = [];
            pending.forEach(job => job.callback(job.cmd, "661\x1e26.05\x1ekernel\x1d660\x1e26.05\x1ekernel", "", 0));
            compare(Object.keys(core.detailsCache).length, 0);
            compare(Object.keys(core.configDiffCache).length, 0);
            compare(Object.keys(core.generationCounts).length, 0);
            compare(Object.keys(core.pairDiffCache).length, 0);
            compare(core.countsQueue.length, 0);
            verify(!core.isLoadingDetails);
            verify(!core.isLoadingConfigDiff);
            verify(!core.isLoadingPairDiff);
        }
        function test_summaries_retain_only_displayed_generations() {
            core.loadGenSummaries();
            const records = [];
            for (let n = 1; n <= 1000; ++n)
                records.push(n + "\x1e26.05\x1e/nix/store/kernel/linux-6.12/bzImage");
            jobs[0].callback(jobs[0].cmd, records.join("\x1d"), "", 0);
            compare(Object.keys(core.detailsCache).length, 2);
            verify(core.detailsCache[661].partial);
            verify(core.detailsCache[660].partial);
        }
        function test_pair_comparisons_have_a_fixed_retention_limit() {
            for (let n = 1; n <= 100; ++n)
                core.parsePairDiff(n + 1, n, "26.05\x1ekernel\x1e");
            compare(Object.keys(core.pairDiffCache).length, 24);
            verify(core.pairDiffCache["101_100"] !== undefined);
            verify(core.pairDiffCache["2_1"] === undefined);
        }
        function test_package_and_project_caches_are_bounded() {
            cfg.showPackageIcons = true;
            const packages = [], icons = [], meta = [];
            for (let n = 0; n < 4200; ++n) {
                packages.push({
                    name: "pkg-" + n
                });
                icons.push("pkg-" + n + "\tapp-icon");
                meta.push("pkg-" + n + "\thttps://example.org\tnixpkgs");
            }
            core.loadIcons(packages);
            core.loadMeta(packages);
            jobs[0].callback(jobs[0].cmd, icons.join("\n"), "", 0);
            jobs[1].callback(jobs[1].cmd, meta.join("\n"), "", 0);
            compare(Object.keys(core.iconCache).length, 4096);
            compare(Object.keys(core.metaCache).length, 4096);
            compare(core.iconCache["pkg-4199"], "app-icon");
            compare(core.metaCache["pkg-4199"].source, "nixpkgs");
            cfg.showPackageIcons = false;
            for (let n = 0; n < 300; ++n) {
                core.resolveStorePath({
                    name: "pkg-" + n,
                    storeProfile: "/profile",
                    newVersion: "1"
                });
                const job = jobs[jobs.length - 1];
                job.callback(job.cmd, "/nix/store/pkg-" + n, "", 0);
            }
            compare(Object.keys(core.storePathCache).length, 256);
            compare(core.storePathCache["/profile|pkg-299|1"].path, "/nix/store/pkg-299");
            for (let n = 0; n < 50; ++n) {
                core.loadShellPackages("/project-" + n, "default");
                const job = jobs[jobs.length - 1];
                job.callback(job.cmd, "hello\n", "", 0);
            }
            compare(Object.keys(core.shellPackages).length, 32);
            compare(core.shellPackages["/project-49#default"].names[0], "hello");
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
            compare(UI.Theme.unescapePath("a\\\\b\\x41"), "a\\bA");
        }
        function test_impermanence_commands_are_quoted_and_cached() {
            core.impermanence = core.parseImpermanence("volatile\tyes\ttmpfs\npersist\t/persist\tbind\t2\text4\t1\t1\t1\n");
            cfg.impermanencePaths = "/mnt/it's";
            core.listImpermanence("", false);
            compare(jobs.length, 1);
            verify(jobs[0].cmd.indexOf("/run'") > 0);
            verify(jobs[0].cmd.indexOf("cached impermanence 600") > 0);
            verify(jobs[0].cmd.indexOf(" list '/mnt/it'\\''s' '/persist'") > 0);
            core.scanImpermanence(true);
            verify(jobs[1].cmd.indexOf("cached impermanence 0") > 0);
            verify(jobs[1].cmd.indexOf(" scan ") > 0);
            verify(jobs[1].cmd.indexOf("NIXDATIFIER_IMP_ALL") < 0);
            // Data disks are opt-in, and part of the cache key when chosen.
            jobs[1].callback(jobs[1].cmd, "", "", 0);
            cfg.impermanenceAllDisks = true;
            core.scanImpermanence(true);
            verify(jobs[2].cmd.indexOf("-- env NIXDATIFIER_IMP_ALL=1 ") > 0);
            jobs[2].callback(jobs[2].cmd, "", "", 0);
            cfg.impermanenceAllDisks = false;
            core.cancelImpermanenceListing();
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
        function test_impermanence_refresh_replaces_remembered_subfolders() {
            core._impListCache = ({});
            // The child was walked on its own and knows one level more.
            core.listImpermanence("/p/home/u", false);
            jobs[0].callback(jobs[0].cmd, "D\t/p/home/u\t/p\t300\t2\t5\n" + "C\td\t300\t2\t5\t5\t755\tu\t\t\told\n", "", 0);
            core.closeImpermanenceFolder();
            // A refresh of the parent sees the child without "old" any more.
            core.listImpermanence("/p/home", true);
            jobs[jobs.length - 1].callback(jobs[jobs.length - 1].cmd, "D\t/p/home\t/p\t100\t1\t5\n" + "C\td\t100\t1\t5\t5\t755\tu\t\t\tu\n" + "G\tu\tf\t100\t1\t5\t5\t644\tu\t\t\tnew\n", "", 0);
            const count = jobs.length;
            core.listImpermanence("/p/home/u", false);
            compare(jobs.length, count);
            compare(core.impermanenceListing.items.length, 1);
            compare(core.impermanenceListing.items[0].label, "new");
            core._impListCache = ({});
        }
        function test_impermanence_delete_does_not_reopen_a_left_folder() {
            core._impListCache = ({});
            core.expanded = true;
            core.activeViewMode = "impermanence";
            core.listImpermanence("/p/home", false);
            jobs[0].callback(jobs[0].cmd, "D\t/p/home\t/p\t10\t1\t5\n" + "C\td\t10\t1\t5\t5\t755\tu\t\t\tx\n", "", 0);
            core.closeImpermanenceFolder();
            cfg.usePkexec = false;
            core.removeImpermanencePaths([
                {
                    path: "/p/home/x",
                    name: "x"
                }
            ]);
            const removal = jobs.filter(j => j.cmd.indexOf(" remove ") > 0)[0];
            removal.callback(removal.cmd, "removed\n", "", 0);
            const invalidate = jobs.filter(j => j.cmd.indexOf(" invalidate impermanence") > 0)[0];
            const before = jobs.length;
            invalidate.callback(invalidate.cmd, "", "", 0);
            verify(!jobs.slice(before).some(j => j.cmd.indexOf(" list ") > 0));
            cfg.usePkexec = true;
            core.activeViewMode = "timeline";
        }
        function test_impermanence_failed_delete_still_invalidates_caches() {
            core._impListCache = ({
                    "/p/home": {
                        at: Date.now(),
                        listing: {
                            dir: "/p/home",
                            items: [],
                            children: {}
                        }
                    }
                });
            cfg.usePkexec = false;
            core.removeImpermanencePaths([
                {
                    path: "/p/home/half",
                    name: "half"
                }
            ]);
            const removal = jobs.filter(j => j.cmd.indexOf(" remove ") > 0)[0];
            // Part of it went before a permission error stopped the rest.
            removal.callback(removal.cmd, "", "ERROR: could not remove everything", 1);
            compare(Object.keys(core._impListCache).length, 0);
            verify(jobs.some(j => j.cmd.indexOf(" invalidate impermanence") > 0));
            cfg.usePkexec = true;
        }
        function test_impermanence_folder_cache_is_bounded_by_rows() {
            core._impListCache = ({});
            const big = n => {
                let out = "";
                for (let i = 0; i < n; i++)
                    out += "C\tf\t1\t0\t5\t5\t644\tu\t\t\tf" + i + "\n";
                return out;
            };
            // Three folders of 25 000 rows: only two fit in 60 000.
            for (const d of ["/p/a", "/p/b", "/p/c"]) {
                core.listImpermanence(d, true);
                const job = jobs[jobs.length - 1];
                job.callback(job.cmd, "D\t" + d + "\t/p\t1\t1\t1\n" + big(25000), "", 0);
                wait(2);
            }
            const kept = Object.keys(core._impListCache);
            verify(kept.indexOf("/p/c") >= 0, "what was just measured stays");
            verify(kept.indexOf("/p/a") < 0, "the oldest goes first");
            compare(kept.length, 2);
            core.closeImpermanenceFolder();
            core._impListCache = ({});
            // Huge folders say how much is left out.
            const l = core.parseImpermanenceListing("D\t/p\t/p\t1\t1\t1\nR\t5\t123\n");
            compare(l.moreCount, 5);
            compare(l.moreBytes, 123);
        }
        function test_impermanence_failed_removal_states_are_bounded() {
            core.impermanenceRemovalStates = ({});
            for (let i = 0; i < 250; i++)
                core.setImpermanenceRemovalState("/p/x" + i, "failed", "no");
            const keys = Object.keys(core.impermanenceRemovalStates);
            compare(keys.length, 200);
            verify(keys.indexOf("/p/x249") >= 0);
            verify(keys.indexOf("/p/x0") < 0);
            core.impermanenceRemovalStates = ({});
        }
        function test_impermanence_sizes_keep_unknown_apart_from_zero() {
            const s = core.parseImpermanenceSizes("E\td\t0\t0\t/gone\t/p/gone\tfailed\n" + "E\td\t50\t1\t/half\t/p/half\tpartial\n" + "E\td\t9\t1\t/old\t/p/old\n");
            compare(s["/gone"].status, "failed");
            compare(s["/half"].status, "partial");
            // Output of older helpers has no status; it was complete.
            compare(s["/old"].status, "ok");
            const listing = core.parseImpermanenceListing("D\t/p\t/p\t1\t1\t1\nP\t3\n");
            verify(listing.partial);
            const c = core.parseImpermanenceCleanup("M\t1\t180\nT\tApplication cache\t9\t5\t/p/c\tpartial\n", 180);
            verify(c.temp[0].partial);
        }
        function test_impermanence_listing_steps_down_and_back_without_new_walks() {
            core._impListCache = ({});
            core.listImpermanence("/p/home", false);
            compare(jobs.length, 1);
            verify(core.isListingImpermanence);
            jobs[0].callback(jobs[0].cmd, "D\t/p/home\t/p\t300\t3\t5\n" + "C\td\t300\t3\t5\t5\t755\tu\t\t\tu\n" + "G\tu\td\t200\t2\t5\t5\t755\tu\th\t\t.cache\n" + "G\tu\tf\t100\t1\t5\t5\t644\tu\t\t\tnotes\n", "", 0);
            compare(core.impermanenceListing.items.length, 1);
            // One level down comes from the same walk.
            core.listImpermanence("/p/home/u", false);
            compare(jobs.length, 1);
            compare(core.impermanenceListing.dir, "/p/home/u");
            compare(core.impermanenceListing.items.length, 2);
            compare(core.impermanenceListing.items[0].path, "/p/home/u/.cache");
            compare(core.impermanenceListing.total, 300);
            // And back up is remembered.
            core.listImpermanence("/p/home", false);
            compare(jobs.length, 1);
            compare(core.impermanenceListing.dir, "/p/home");
            // Two levels down needs a walk; leaving before it ends stops it.
            core.listImpermanence("/p/home/u/.cache", false);
            compare(jobs.length, 2);
            core.cancelImpermanenceListing();
            verify(!core.isListingImpermanence);
            compare(jobs.length, 3);
            verify(jobs[2].cmd.indexOf(" cancel-list ") > 0);
            // The stopped walk reporting back changes nothing.
            jobs[1].callback(jobs[1].cmd, "", "", 143);
            compare(core.impermanenceListing.dir, "/p/home");
            core._impListCache = ({});
        }
        function test_impermanence_batch_removal_runs_one_after_another() {
            cfg.usePkexec = false;
            core.removeImpermanencePaths([
                {
                    path: "/persist/home/u/.cache/a",
                    name: "a"
                },
                {
                    path: "/persist/home/u/.cache/b",
                    name: "b"
                }
            ]);
            compare(jobs.length, 1);
            verify(core.isRemovingImpermanence);
            compare(core.impermanenceRemovalStates["/persist/home/u/.cache/a"].state, "deleting");
            compare(core.impermanenceRemovalStates["/persist/home/u/.cache/b"].state, "queued");
            // Asking for an already queued path must not delete it twice.
            core.removeImpermanencePaths([
                {
                    path: "/persist/home/u/.cache/b",
                    name: "b"
                }
            ]);
            // Asked for while the first batch runs: joins the queue.
            core.removeImpermanencePaths([
                {
                    path: "/persist/home/u/.cache/c",
                    name: "c"
                }
            ]);
            compare(jobs.length, 1);
            core.impermanenceCleanup = core.parseImpermanenceCleanup("M\t1\t180\nT\tApplication cache\t9\t5\t/persist/home/u/.cache/a\nT\tApplication cache\t9\t5\t/persist/home/u/.cache/z\n", 180);
            jobs[0].callback(jobs[0].cmd, "removed\n", "", 0);
            let removals = jobs.filter(j => j.cmd.indexOf(" remove ") > 0);
            compare(removals.length, 2);
            verify(removals[1].cmd.indexOf(".cache/b") > 0);
            compare(core.impermanenceRemovalStates["/persist/home/u/.cache/a"].state, "deleted");
            compare(core.impermanenceRemovalStates["/persist/home/u/.cache/b"].state, "deleting");
            removals[1].callback(removals[1].cmd, "", "ERROR: already gone", 2);
            verify(core.isRemovingImpermanence);
            removals = jobs.filter(j => j.cmd.indexOf(" remove ") > 0);
            compare(removals.length, 3);
            removals[2].callback(removals[2].cmd, "removed\n", "", 0);
            verify(!core.isRemovingImpermanence);
            compare(core.impermanenceRemovalStates["/persist/home/u/.cache/b"].state, "failed");
            compare(core.impermanenceRemovalStates["/persist/home/u/.cache/b"].message, "already gone");
            verify(core.impermanenceRemovalStates["/persist/home/u/.cache/a"] === undefined);
            const toast = core.toasts[core.toasts.length - 1];
            verify(toast.err);
            verify(toast.msg.indexOf("2 of 3") >= 0);
            // What is gone leaves the analysis without running it again.
            compare(core.impermanenceCleanup.temp.length, 1);
            verify(!jobs.some(j => j.cmd.indexOf(" cleanup ") > 0));
            core.impermanenceCleanup = null;
            cfg.usePkexec = true;
        }
        function test_disk_refresh_during_measurement_discards_old_snapshot() {
            core.diskStoreBytes = 40;
            core.probeDiskUsage(false);
            core.probeDiskUsage(true);
            core.probeDiskUsage(true);
            compare(jobs.length, 1);
            jobs[0].callback(jobs[0].cmd, "100\x1e20\x1e500\x1e1700000000", "", 0);
            compare(core.diskStoreBytes, 40);
            compare(jobs.length, 2);
            verify(jobs[1].cmd.indexOf("cached disk:nar-v1 0") > 0);
            jobs[1].callback(jobs[1].cmd, "80\x1e10\x1e520\x1e" + Math.floor(Date.now() / 1000), "", 0);
            compare(core.diskStoreBytes, 80);
            compare(core.diskReclaimableBytes, 10);
            compare(core.diskFreeBytes, 520);
            verify(!core._diskProbeRunning);
            core.probeDiskUsage(false);
            compare(jobs.length, 2);
        }
        function test_disk_errors_preserve_last_measurement_and_allow_retry() {
            core.diskStoreBytes = 100;
            core.diskReclaimableBytes = 25;
            core.diskFreeBytes = 500;
            core.probeDiskUsage(true);
            jobs[0].callback(jobs[0].cmd, "", "daemon unavailable", 1);
            compare(core.diskReclaimableBytes, 25);
            compare(core.diskFreeBytes, 500);
            compare(core.diskUsageError, "daemon unavailable");
            core.probeDiskUsage(true);
            let probes = jobs.filter(j => j.cmd.indexOf("cached disk:nar-v1") >= 0);
            probes[1].callback(probes[1].cmd, "oops\x1e0\x1e500", "", 0);
            compare(core.diskStoreBytes, 100);
            verify(core.diskUsageError !== "");
            core.probeDiskUsage(true);
            probes = jobs.filter(j => j.cmd.indexOf("cached disk:nar-v1") >= 0);
            probes[2].callback(probes[2].cmd, "100\x1e0\x1e500", "", 0);
            compare(core.diskReclaimableBytes, 0);
            compare(core.diskUsageError, "");
        }
        function test_cached_store_sizes_refresh_free_space_without_another_graph_walk() {
            core.probeDiskUsage(false);
            jobs[0].callback(jobs[0].cmd, "100\x1e25\x1e500\x1e1700000000", "", 0);
            compare(jobs.length, 2);
            verify(jobs[1].cmd.endsWith("/diskusage' --free"));
            jobs[1].callback(jobs[1].cmd, "700", "", 0);
            compare(core.diskFreeBytes, 700);
            compare(core.diskStoreBytes, 100);
            compare(core.diskReclaimableBytes, 25);
        }
        function test_hidden_window_defers_forced_disk_work() {
            core.autoStart = true;
            core.expanded = false;
            core.probeDiskUsage(true);
            compare(jobs.length, 0);
            verify(core._diskProbeDirty);
            core.autoStart = false;
            core.probeDiskUsage(false);
            compare(jobs.length, 1);
            verify(jobs[0].cmd.indexOf("cached disk:nar-v1 0") > 0);
            jobs[0].callback(jobs[0].cmd, "1\x1e0\x1e2", "", 0);
        }
        function test_failed_gc_refreshes_partially_changed_store_and_profiles() {
            core.executeCleanup("gc-14d");
            compare(jobs.length, 1);
            verify(jobs[0].cmd.indexOf("nixdatifier' ") > 0);
            verify(jobs[0].cmd.indexOf("gc --older-than 14d") > 0);
            jobs[0].callback(jobs[0].cmd, "", "collection failed after pruning profiles", 1);
            verify(!core.isBusy);
            verify(jobs.some(j => j.cmd.indexOf("/generations'") > 0));
            verify(jobs.some(j => j.cmd.indexOf("cached disk:nar-v1 0") > 0));
            verify(core.toasts[core.toasts.length - 1].err);
        }
        function test_disk_inspection_busy_request_preserves_result() {
            core.storeUsageResult = {
                isError: false,
                path: "previous"
            };
            core.isProbingStoreUsage = true;
            core.probeStoreUsage("/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-app");
            compare(core.storeUsageResult.path, "previous");
            compare(jobs.length, 0);
            core.isProbingStoreUsage = false;
        }
        function test_folder_measurement_repeats_after_delete_during_probe() {
            core.isMeasuringImpermanence = false;
            core.measureImpermanence(false);
            core.measureImpermanence(true);
            jobs[0].callback(jobs[0].cmd, "E\td\t100\t1\t/home/u\t/p/home/u\n", "", 0);
            compare(jobs.length, 2);
            verify(jobs[1].cmd.indexOf("cached impermanence 0") > 0);
            jobs[1].callback(jobs[1].cmd, "E\td\t40\t2\t/home/u\t/p/home/u\n", "", 0);
            compare(core.impermanenceSizes["/home/u"].size, 40);
        }
        function test_folder_disk_cache_hit_still_stops_previous_walk() {
            core._impListCache = ({});
            core.listImpermanence("/persist/a", false);
            core.listImpermanence("/persist/b", false);
            compare(jobs.length, 2);
            verify(jobs[1].cmd.indexOf(" cancel-list ") < jobs[1].cmd.indexOf(" cached impermanence "));
            verify(jobs[1].cmd.indexOf(" && ") > 0);
            jobs[0].callback(jobs[0].cmd, "", "cancelled", 143);
            verify(core.isListingImpermanence);
            jobs[1].callback(jobs[1].cmd, "D\t/persist/b\t/persist\t0\t0\t0\n", "", 0);
            compare(core.impermanenceListing.dir, "/persist/b");
        }
        function test_folder_snapshot_cache_is_bounded_after_large_listing() {
            core._impListCache = ({});
            const listing = {
                dir: "/persist",
                area: "/persist",
                items: [],
                children: {}
            };
            for (let i = 0; i < 400; ++i) {
                listing.items.push({
                    kind: "d",
                    label: "f" + i,
                    path: "/persist/f" + i,
                    size: 0,
                    count: 0,
                    newest: 0
                });
                listing.children["f" + i] = [];
            }
            core._rememberListing(listing);
            compare(Object.keys(core._impListCache).length, 300);
            core._rememberListing({
                dir: "/persist/another",
                area: "/persist",
                items: [],
                children: {}
            });
            compare(Object.keys(core._impListCache).length, 300);
            verify(core._impListCache["/persist/another"] !== undefined);
        }
        function test_idle_widget_releases_remembered_folders() {
            core._impListCache = ({});
            const listing = {
                isError: false,
                dir: "/persist",
                area: "/persist",
                items: [
                    {
                        kind: "d",
                        label: "a",
                        path: "/persist/a",
                        size: 5,
                        count: 1,
                        newest: 1
                    }
                ],
                children: {
                    a: [
                        {
                            kind: "f",
                            label: "x",
                            path: "/persist/a/x",
                            size: 1
                        }
                    ]
                }
            };
            core._rememberListing(listing);
            core.impermanenceListing = listing;
            const timer = findChild(core, "impermanenceReleaseTimer");
            core.expanded = true;
            verify(!timer.running, "A popup that is open keeps what it shows");
            core.expanded = false;
            verify(timer.running, "A closed popup lets the remembered folders go after a while");
            core.releaseImpermanenceMemory();
            compare(Object.keys(core._impListCache).length, 0);
            compare(core.impermanenceListing.items.length, 1, "The folder on screen keeps its own rows");
            compare(Object.keys(core.impermanenceListing.children).length, 0);
            verify(!timer.running, "Nothing is left to release");
        }
        function test_hash_error_is_not_success() {
            core.runHashProbe("url", "https://example.invalid");
            jobs[0].callback(jobs[0].cmd, "", "network error", 1);
            verify(core.hashResult.isError);
            verify(!core.isProbingHash);
        }
    }
}
