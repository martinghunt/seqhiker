#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${ROOT_DIR}"
BUILD_ZEM_SCRIPT="${ROOT_DIR}/build_zem_bins.sh"
DEFAULT_GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"

TARGET=""
PRESET=""
OUTFILE=""
GODOT_BIN="${DEFAULT_GODOT_BIN}"
EXPORT_MODE="release"
SKIP_ZEM=0

usage() {
	cat <<'EOF'
Usage:
  ./build_release.sh --target <os>/<arch> --preset "<Godot Preset Name>" --out <artifact_path> [options]

Required:
  --target   Target used to build bundled zem, e.g. darwin/arm64, linux/amd64, windows/arm64
  --preset   Godot export preset name from export_presets.cfg
  --out      Output artifact path for Godot export

Options:
  --godot-bin <path>   Godot executable path
                       (default: /Applications/Godot.app/Contents/MacOS/Godot)
  --mode <release|debug>
  --skip-zem
  -h, --help

Example:
  ./build_release.sh \
    --target darwin/arm64 \
    --preset "macOS arm64" \
    --out /tmp/seqhiker-macos-arm64.dmg
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--target)
			[[ $# -ge 2 ]] || { echo "Missing value for --target" >&2; exit 1; }
			TARGET="$2"
			shift 2
			;;
		--preset)
			[[ $# -ge 2 ]] || { echo "Missing value for --preset" >&2; exit 1; }
			PRESET="$2"
			shift 2
			;;
		--out)
			[[ $# -ge 2 ]] || { echo "Missing value for --out" >&2; exit 1; }
			OUTFILE="$2"
			shift 2
			;;
		--godot-bin)
			[[ $# -ge 2 ]] || { echo "Missing value for --godot-bin" >&2; exit 1; }
			GODOT_BIN="$2"
			shift 2
			;;
		--mode)
			[[ $# -ge 2 ]] || { echo "Missing value for --mode" >&2; exit 1; }
			EXPORT_MODE="$2"
			shift 2
			;;
		--skip-zem)
			SKIP_ZEM=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage
			exit 1
			;;
	esac
done

[[ -n "${TARGET}" ]] || { echo "--target is required" >&2; exit 1; }
[[ -n "${PRESET}" ]] || { echo "--preset is required" >&2; exit 1; }
[[ -n "${OUTFILE}" ]] || { echo "--out is required" >&2; exit 1; }
[[ "${EXPORT_MODE}" == "release" || "${EXPORT_MODE}" == "debug" ]] || {
	echo "--mode must be release or debug" >&2
	exit 1
}

if [[ ! -x "${BUILD_ZEM_SCRIPT}" ]]; then
	echo "Missing or non-executable: ${BUILD_ZEM_SCRIPT}" >&2
	exit 1
fi

if [[ ! -x "${GODOT_BIN}" ]]; then
	echo "Godot executable not found or not executable: ${GODOT_BIN}" >&2
	exit 1
fi

if [[ ! -f "${APP_DIR}/project.godot" ]]; then
	echo "Missing project.godot in ${APP_DIR}" >&2
	exit 1
fi

if [[ ! -f "${APP_DIR}/export_presets.cfg" ]]; then
	echo "Missing ${APP_DIR}/export_presets.cfg" >&2
	echo "Create export presets in Godot Editor first, then re-run." >&2
	exit 1
fi

if ! grep -q "name=\"${PRESET}\"" "${APP_DIR}/export_presets.cfg"; then
	echo "Preset not found in export_presets.cfg: ${PRESET}" >&2
	exit 1
fi

if [[ "${SKIP_ZEM}" -eq 0 ]]; then
	echo "[1/2] Building bundled zem for ${TARGET}"
	"${BUILD_ZEM_SCRIPT}" --target "${TARGET}"
else
	echo "[1/2] Skipping bundled zem build (--skip-zem)"
fi

echo "[2/2] Exporting seqhiker (${EXPORT_MODE}) preset='${PRESET}' -> ${OUTFILE}"
mkdir -p "$(dirname "${OUTFILE}")"
"${GODOT_BIN}" --headless --path "${APP_DIR}" "--export-${EXPORT_MODE}" "${PRESET}" "${OUTFILE}"
echo "Done: ${OUTFILE}"
