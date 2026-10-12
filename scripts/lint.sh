#!/usr/bin/env bash
# Every static check the project has, in one place. CI, `make lint` and the flake's
# `checks.lint` all run this, so they cannot drift apart.
#
# On PATH: qmllint qmlformat ruff shellcheck python3
# QML_IMPORT_PATH lists the Qt and KDE QML modules (the dev shell sets it);
# without them qmllint cannot resolve Kirigami or Plasma types and reports nothing useful.
#
# All checks run even when one fails, so one run shows everything to fix.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

failed=()
step() {
    local name=$1
    shift
    printf '\n── %s\n' "$name"
    "$@" || failed+=("$name")
}

qml_files() { find "$@" -name '*.qml' -type f | sort; }
shell_lint() {
    local files
    mapfile -t files < <({ find package/contents/tools/sh -type f; find . -maxdepth 2 -name '*.sh' -not -path './.git/*'; } | sort)
    shellcheck --severity=warning "${files[@]}"
}

qml_format() {
    local f bad=0
    while read -r f; do
        if ! qmlformat "$f" | cmp -s - "$f"; then
            echo "needs formatting: $f"
            bad=1
        fi
    done < <(qml_files package hyprland shell.qml standalone tests)
    [ "$bad" -eq 0 ] || echo "Run: make fmt"
    return "$bad"
}

qml_lint() {
    # The widget is held to a clean result. The Quickshell host is checked
    # with its own settings (hyprland/.qmllint.ini), because qmllint cannot see
    # Quickshell's types.
    local rc=0
    qml_files package/contents | xargs qmllint -E -W 0 || rc=1
    qml_files hyprland shell.qml | xargs qmllint -E -W 0 || rc=1
    return "$rc"
}

# A well-formed manifest and config schema; a typo here breaks the widget at install time.
manifests() {
    python3 -I - <<'EOF'
import json
import sys
import xml.dom.minidom

try:
    meta = json.load(open("package/metadata.json"))
    xml.dom.minidom.parse("package/contents/config/main.xml")
except Exception as err:
    sys.exit(f"invalid manifest: {err}")
for key in ("Id", "Version"):
    if not meta.get("KPlugin", {}).get(key):
        sys.exit(f"package/metadata.json: KPlugin.{key} is missing")
EOF
}

step "ruff: lint (unused imports and variables, likely bugs)" ruff check .
step "ruff: format" ruff format --check .
step "shellcheck: helper scripts" shell_lint
step "qmlformat" qml_format
step "qmllint" qml_lint
step "unused QML properties, functions, signals, ids and locals" python3 -I scripts/check-unused.py
step "manifests" manifests

printf '\n'
if [ "${#failed[@]}" -gt 0 ]; then
    printf 'FAILED: %s\n' "${failed[@]}"
    exit 1
fi
echo "All checks passed."
