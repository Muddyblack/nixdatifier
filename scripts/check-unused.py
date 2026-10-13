#!/usr/bin/env python3
"""Find QML/JS code that nothing uses, the way ruff flags unused names.

qmllint reports unused imports but not unused properties, functions, signals,
ids or local variables. This closes that gap with a token scan. It favours
no false alarms over catching everything: a name counts as used when it appears
anywhere it could be reached from, including inside a string or the C++ hosts.

  scripts/check-unused.py            report, exit 1 when something is found
  scripts/check-unused.py --tests    also list names only the tests use
"""

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRODUCTION = ["package", "hyprland", "standalone", "shell.qml"]
HOST_SOURCES = ["standalone", "tray"]

PROPERTY = re.compile(
    r"^[ \t]*(?:readonly[ \t]+|required[ \t]+)*property[ \t]+[\w.<>]+[ \t]+(\w+)[ \t]*(?::|$)",
    re.M,
)
SIGNAL = re.compile(r"^[ \t]*signal[ \t]+(\w+)", re.M)
FUNCTION = re.compile(r"^[ \t]*function[ \t]+(\w+)[ \t]*\(", re.M)
ID = re.compile(r"^[ \t]*id[ \t]*:[ \t]*(\w+)[ \t]*$", re.M)
LOCAL = re.compile(r"\b(?:const|let|var)\s+(\w+)\s*(?:=|;|\bof\b|\bin\b)")
DESTRUCTURE = re.compile(r"\b(?:const|let|var)\s*[\[{]([^\]}=]*)[\]}]\s*=")
WORD = re.compile(r"[A-Za-z_]\w*")
# A `/` after one of these starts a regex literal, not a division.
REGEX_PREFIX = set("(,=:[!&|?{};+-*%<>~^") | {""}


def scan(text):
    """Return (code, strings): `code` with comments, string bodies and regex
    literals blanked (newlines kept so line numbers still match), and the text
    of every string literal."""
    out, strings = [], []
    i, n = 0, len(text)
    last = ""

    def blank(chunk):
        return re.sub(r"[^\n]", " ", chunk)

    while i < n:
        ch, two = text[i], text[i : i + 2]
        if two == "//":
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(blank(text[i:j]))
            i = j
        elif two == "/*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(blank(text[i:j]))
            i = j
        elif ch in "\"'":
            j = i + 1
            while j < n and text[j] != ch and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            strings.append(text[i + 1 : j])
            out.append(ch + blank(text[i + 1 : j]) + (ch if j < n and text[j] == ch else ""))
            i, last = j + 1, ch
        elif ch == "`":
            j = i + 1
            out.append("`")
            while j < n and text[j] != "`":
                if text[j] == "\\":
                    out.append("  ")
                    j += 2
                elif text[j : j + 2] == "${":
                    depth, k = 1, j + 2
                    while k < n and depth:
                        depth += {"{": 1, "}": -1}.get(text[k], 0)
                        k += 1
                    out.append("  " + text[j + 2 : k - 1] + " ")
                    j = k
                else:
                    out.append("\n" if text[j] == "\n" else " ")
                    j += 1
            out.append("`")
            i, last = j + 1, "`"
        elif ch == "/" and last in REGEX_PREFIX:
            j, in_class = i + 1, False
            while j < n and text[j] != "\n":
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == "[":
                    in_class = True
                elif text[j] == "]":
                    in_class = False
                elif text[j] == "/" and not in_class:
                    break
                j += 1
            out.append(blank(text[i : j + 1]))
            i, last = j + 1, "/"
        else:
            out.append(ch)
            if not ch.isspace():
                last = ch
            i += 1
    return "".join(out), strings


def sources(paths):
    for entry in paths:
        base = ROOT / entry
        if base.is_file():
            yield base
        elif base.is_dir():
            yield from sorted(p for p in base.rglob("*") if p.suffix in {".qml", ".js"})


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


def handler_names(name):
    """`foo` is also reached as onFooChanged / onFoo."""
    cap = name[0].upper() + name[1:]
    return (f"on{cap}Changed", f"on{cap}")


def block_pairs(code):
    stack, pairs = [], {}
    for i, ch in enumerate(code):
        if ch == "{":
            stack.append(i)
        elif ch == "}" and stack:
            pairs[stack.pop()] = i
    return pairs


def innermost_block(pairs, offset):
    best = None
    for start, end in pairs.items():
        if start < offset < end and (best is None or start > best[0]):
            best = (start, end)
    return best


def unused_locals(code):
    """Declared inside a block, never mentioned again before that block ends."""
    pairs = block_pairs(code)
    declared = [(m.group(1), m.start(1)) for m in LOCAL.finditer(code)]
    for m in DESTRUCTURE.finditer(code):
        declared += [(p.group(1), m.start(1) + p.start(1)) for p in re.finditer(r"\w+", m.group(1))]
    for name, offset in declared:
        block = innermost_block(pairs, offset)
        if block and not re.search(rf"\b{re.escape(name)}\b", code[offset + len(name) : block[1]]):
            yield name, offset


def declarations_in(path, code):
    patterns = [("function", FUNCTION)]
    if path.suffix == ".qml":
        patterns += [("property", PROPERTY), ("signal", SIGNAL), ("id", ID)]
    for kind, rx in patterns:
        for m in rx.finditer(code):
            yield kind, m.group(1), m.start(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--tests", action="store_true", help="also list names only tests use")
    args = parser.parse_args()

    scanned = {p: scan(p.read_text()) for p in sources(PRODUCTION)}
    words = Counter(w for code, _ in scanned.values() for w in WORD.findall(code))
    # A name held in a string (a dynamic lookup) or used by a C++ host is in use.
    reachable = {w for _, strings in scanned.values() for s in strings for w in WORD.findall(s)}
    for host in HOST_SOURCES:
        for p in (ROOT / host).rglob("*"):
            if p.suffix in {".cpp", ".h"}:
                reachable.update(WORD.findall(p.read_text()))

    tests = Counter()
    for p in sources(["tests"]):
        code, strings = scan(p.read_text())
        tests.update(WORD.findall(code))
        tests.update(w for s in strings for w in WORD.findall(s))

    # The same name declared in several files must not keep itself alive.
    declared = Counter(name for p, (code, _) in scanned.items() for _, name, _ in declarations_in(p, code))

    findings = set()
    for path, (code, _) in scanned.items():
        for kind, name, offset in declarations_in(path, code):
            # Plasma fills in cfg_* from the config dialog; `default property`
            # takes the children written inside the component.
            if name in reachable or name.startswith("cfg_"):
                continue
            line_start = code.rfind("\n", 0, offset) + 1
            if re.match(r"\s*default\b", code[line_start:offset]):
                continue
            if kind == "function" and re.fullmatch(r"on[A-Z]\w*", name):
                continue  # a signal handler written as a function
            uses = words[name] - declared[name] + sum(words[h] for h in handler_names(name))
            if uses > 0:
                continue
            only_tests = tests[name] > 0
            if only_tests and not args.tests:
                continue
            findings.add((path, line_of(code, offset), kind + (" (tests only)" if only_tests else ""), name))
        for name, offset in unused_locals(code):
            findings.add((path, line_of(code, offset), "local", name))

    for path, line, kind, name in sorted(findings, key=lambda f: (str(f[0]), f[1], f[3])):
        print(f"{path.relative_to(ROOT)}:{line}: unused {kind} '{name}'")
    if findings:
        print(f"\n{len(findings)} unused name(s).", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
