#!/usr/bin/env bash
set -euo pipefail

godot_bin="${GODOT_BIN:-godot}"
log_file="${GODOT_TEST_LOG_FILE:-/tmp/seqhiker-godot-tests.log}"

set +e
output="$("${godot_bin}" --headless --disable-crash-handler --log-file "${log_file}" --path . --script res://tests/godot/run_tests.gd 2>&1)"
status=$?
set -e

printf '%s\n' "${output}"

if printf '%s\n' "${output}" | grep -E "(SCRIPT ERROR|ERROR: Failed to load script|Godot tests failed|handle_crash|Program crashed)" >/dev/null; then
	exit 1
fi

exit "${status}"
