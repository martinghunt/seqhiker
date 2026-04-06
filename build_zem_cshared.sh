#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZEM_DIR="${ROOT_DIR}/zem"
OUT_DIR="${ROOT_DIR}/bin/cshared"
TARGET=""
VERSION=""

usage() {
	cat <<'EOF'
Usage:
  ./build_zem_cshared.sh
  ./build_zem_cshared.sh --target <os>/<arch>
  ./build_zem_cshared.sh --out-dir <dir>
  ./build_zem_cshared.sh --version <version>

Notes:
  - Builds a zem shared library for the requested target or current host.
  - Output includes both the shared library and generated C header.
  - Default version source is project.godot application/config/version.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--target)
			if [[ $# -lt 2 ]]; then
				echo "Missing value for --target" >&2
				exit 1
			fi
			TARGET="$2"
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
		--version)
			if [[ $# -lt 2 ]]; then
				echo "Missing value for --version" >&2
				exit 1
			fi
			VERSION="$2"
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

project_version() {
	local version
	version="$(sed -n 's/^config\/version="\([^"]*\)"/\1/p' "${ROOT_DIR}/project.godot" | head -n1)"
	if [[ -z "${version}" ]]; then
		echo "Failed to read application/config/version from ${ROOT_DIR}/project.godot" >&2
		exit 1
	fi
	printf '%s\n' "${version}"
}

if [[ -z "${VERSION}" ]]; then
	VERSION="$(project_version)"
fi

mkdir -p "${OUT_DIR}"

goos="$(go env GOOS)"
goarch="$(go env GOARCH)"
if [[ -n "${TARGET}" ]]; then
	goos="${TARGET%%/*}"
	goarch="${TARGET##*/}"
	if [[ "${goos}" == "${goarch}" ]]; then
		echo "Invalid --target '${TARGET}'. Expected os/arch." >&2
		exit 1
	fi
fi

if [[ "${goos}" == "macos" ]]; then
	goos="darwin"
fi

if [[ "${goarch}" == "x86_64" ]]; then
	goarch="amd64"
elif [[ "${goarch}" == "x86_32" ]]; then
	goarch="386"
fi

lib_name="libzem.so"
if [[ "${goos}" == "darwin" ]]; then
	lib_name="libzem.dylib"
elif [[ "${goos}" == "windows" ]]; then
	lib_name="libzem.dll"
fi

echo "Building zem c-shared ${VERSION} for ${goos}/${goarch} -> ${OUT_DIR}/${lib_name}"
(
	cd "${ZEM_DIR}"
	GOOS="${goos}" GOARCH="${goarch}" go build -buildmode=c-shared -trimpath -ldflags="-s -w -X seqhiker/zem.ZemVersion=${VERSION}" -o "${OUT_DIR}/${lib_name}" ./cmd/zemcshared
)

if [[ "${goos}" == "darwin" ]]; then
	install_name_tool -id "@rpath/${lib_name}" "${OUT_DIR}/${lib_name}"
fi

echo "Done. Outputs:"
echo "  ${OUT_DIR}/${lib_name}"
echo "  ${OUT_DIR}/libzem.h"
