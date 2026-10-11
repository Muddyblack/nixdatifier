#!/usr/bin/env bash
set -euo pipefail
project_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /tmp/nixdatifier-checks.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
export XDG_RUNTIME_DIR="$test_dir/runtime"
export XDG_CACHE_HOME="$test_dir/cache"
export XDG_CONFIG_HOME="$test_dir/config"
mkdir -m 700 "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=
export QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software
python3 "$project_dir/tests/test_helpers.py"
"${QML_TEST_RUNNER:-qmltestrunner}" -input "$project_dir/tests" -o -,txt
