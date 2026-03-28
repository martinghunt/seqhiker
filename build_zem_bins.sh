#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZEM_DIR="${ROOT_DIR}/zem"
OUT_DIR="${ROOT_DIR}/bin"
TARGETS_DIR="${OUT_DIR}/targets"

TARGET=""
BUILD_ALL=0
VERSION=""

usage() {
	cat <<'EOF'
Usage:
  ./build_zem_bins.sh
  ./build_zem_bins.sh --target <os>/<arch>
  ./build_zem_bins.sh --version <version>
  ./build_zem_bins.sh --all

Examples:
  ./build_zem_bins.sh
  ./build_zem_bins.sh --target darwin/arm64
  ./build_zem_bins.sh --version 0.0.1
  ./build_zem_bins.sh --target linux/amd64
  ./build_zem_bins.sh --all

Notes:
  - Default version source is project.godot application/config/version.
  - Default (no args) builds for current host and writes:
      bin/seqhiker-zem
      bin/seqhiker-zem.exe (on Windows target)
  - --target builds one target and writes canonical bundle filename above.
  - --all writes multiple artifacts to:
      bin/targets/seqhiker-zem_<os>_<arch>[.exe]
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
		--all)
			BUILD_ALL=1
			shift
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

if [[ ! -d "${ZEM_DIR}" ]]; then
	echo "Missing zem directory: ${ZEM_DIR}" >&2
	exit 1
fi

mkdir -p "${OUT_DIR}"

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

build_one() {
	local goos="$1"
	local goarch="$2"
	local out="$3"
	echo "Building zem ${VERSION} for ${goos}/${goarch} -> ${out}"
	(
		cd "${ZEM_DIR}"
		GOOS="${goos}" GOARCH="${goarch}" CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.ZemVersion=${VERSION}" -o "${out}" .
	)
}

host_goos="$(go env GOOS)"
host_goarch="$(go env GOARCH)"

if [[ "${BUILD_ALL}" -eq 1 ]]; then
	mkdir -p "${TARGETS_DIR}"
	target_matrix=(
		"darwin/amd64"
		"darwin/arm64"
		"linux/amd64"
		"linux/arm64"
		"windows/amd64"
		"windows/arm64"
	)
	for t in "${target_matrix[@]}"; do
		goos="${t%%/*}"
		goarch="${t##*/}"
		ext=""
		if [[ "${goos}" == "windows" ]]; then
			ext=".exe"
		fi
		out="${TARGETS_DIR}/seqhiker-zem_${goos}_${goarch}${ext}"
		build_one "${goos}" "${goarch}" "${out}"
	done
	echo "Done. Artifacts in: ${TARGETS_DIR}"
	exit 0
fi

if [[ -n "${TARGET}" ]]; then
	host_goos="${TARGET%%/*}"
	host_goarch="${TARGET##*/}"
	if [[ "${host_goos}" == "${host_goarch}" ]]; then
		echo "Invalid --target '${TARGET}'. Expected os/arch." >&2
		exit 1
	fi
fi

out_name="seqhiker-zem"
if [[ "${host_goos}" == "windows" ]]; then
	out_name="seqhiker-zem.exe"
fi
build_one "${host_goos}" "${host_goarch}" "${OUT_DIR}/${out_name}"
echo "Done. Bundled binary: ${OUT_DIR}/${out_name}"
