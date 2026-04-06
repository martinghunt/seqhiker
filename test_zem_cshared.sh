#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZEM_DIR="${ROOT_DIR}/zem"
BUILD_DIR="${ROOT_DIR}/bin/cshared"
SMOKETEST_BIN="${BUILD_DIR}/zemcshared-smoketest"

"${ROOT_DIR}/build_zem_cshared.sh" --out-dir "${BUILD_DIR}"

echo "Compiling native smoke test -> ${SMOKETEST_BIN}"
clang -I "${BUILD_DIR}" -L "${BUILD_DIR}" -lzem -o "${SMOKETEST_BIN}" "${ZEM_DIR}/cmd/zemcshared_smoketest/main.c"

echo "Running native smoke test"
goos="$(go env GOOS)"
if [[ "${goos}" == "darwin" ]]; then
	DYLD_LIBRARY_PATH="${BUILD_DIR}" "${SMOKETEST_BIN}"
elif [[ "${goos}" == "linux" ]]; then
	LD_LIBRARY_PATH="${BUILD_DIR}" "${SMOKETEST_BIN}"
else
	"${SMOKETEST_BIN}"
fi
