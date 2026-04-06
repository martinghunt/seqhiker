#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_CPP_DIR="${GODOT_CPP_DIR:-/tmp/godot-cpp-4.4}"
PLATFORM="${PLATFORM:-}"
ARCH="${ARCH:-}"
TARGET="${TARGET:-template_debug}"
OUT_DIR="${OUT_DIR:-}"

usage() {
	cat <<'EOF'
Usage:
  ./build_zem_gdextension.sh
  ./build_zem_gdextension.sh --target <os>/<arch>
  ./build_zem_gdextension.sh --platform <platform> --arch <arch>
  ./build_zem_gdextension.sh --out-dir <dir>

Notes:
  - Builds both the zem c-shared library and the Godot GDExtension wrapper.
  - If --out-dir is provided, writes:
      <out-dir>/cshared/*
      <out-dir>/gdextension/*
  - Platform names follow godot-cpp: macos, linux, windows.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--target)
			if [[ $# -lt 2 ]]; then
				echo "Missing value for --target" >&2
				exit 1
			fi
			PLATFORM="${2%%/*}"
			ARCH="${2##*/}"
			shift 2
			;;
		--platform)
			if [[ $# -lt 2 ]]; then
				echo "Missing value for --platform" >&2
				exit 1
			fi
			PLATFORM="$2"
			shift 2
			;;
		--arch)
			if [[ $# -lt 2 ]]; then
				echo "Missing value for --arch" >&2
				exit 1
			fi
			ARCH="$2"
			shift 2
			;;
		--out-dir)
			if [[ $# -lt 2 ]]; then
				echo "Missing value for --out-dir" >&2
				exit 1
			fi
			OUT_DIR="$2"
			shift 2
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

if [[ -z "${PLATFORM}" ]]; then
	PLATFORM="$(go env GOOS)"
fi
if [[ -z "${ARCH}" ]]; then
	ARCH="$(go env GOARCH)"
fi

if [[ "${PLATFORM}" == "darwin" ]]; then
	PLATFORM="macos"
elif [[ "${PLATFORM}" == "amd64" || "${PLATFORM}" == "arm64" ]]; then
	echo "Invalid --target or --platform value." >&2
	exit 1
fi

if [[ "${ARCH}" == "amd64" ]]; then
	ARCH="x86_64"
elif [[ "${ARCH}" == "386" ]]; then
	ARCH="x86_32"
fi

if ! command -v scons >/dev/null 2>&1; then
	echo "scons is required to build the GDExtension." >&2
	exit 1
fi

if [[ ! -d "${GODOT_CPP_DIR}" ]]; then
	echo "GODOT_CPP_DIR not found: ${GODOT_CPP_DIR}" >&2
	exit 1
fi

cshared_dir="${ROOT_DIR}/bin/cshared"
gdextension_out_dir="${ROOT_DIR}/native/zem_bridge/bin"
bridge_rpath="@loader_path/../../../bin/cshared"
if [[ -n "${OUT_DIR}" ]]; then
	cshared_dir="${OUT_DIR}/cshared"
	gdextension_out_dir="${OUT_DIR}/gdextension"
	bridge_rpath="@loader_path/../cshared"
fi

"${ROOT_DIR}/build_zem_cshared.sh" --target "${PLATFORM}/${ARCH}" --out-dir "${cshared_dir}"

echo "Building seqhiker_zem_bridge with godot-cpp from ${GODOT_CPP_DIR}"
(
	cd "${ROOT_DIR}/native/zem_bridge"
	GODOT_CPP_DIR="${GODOT_CPP_DIR}" \
	ZEM_CSHARED_DIR="${cshared_dir}" \
	BRIDGE_OUT_DIR="${gdextension_out_dir}" \
	BRIDGE_RPATH="${bridge_rpath}" \
	scons platform="${PLATFORM}" arch="${ARCH}" target="${TARGET}"
)
