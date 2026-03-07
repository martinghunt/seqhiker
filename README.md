# seqhiker
Genome browser

## zem runtime location

On startup, seqhiker now installs `zem` into Godot user data:

- macOS/Linux: `~/Library/Application Support/seqhiker/bin/zem` (or equivalent `OS.get_user_data_dir()/bin/zem`)
- Windows: `%APPDATA%\\seqhiker\\bin\\zem.exe`

Startup install source order:

1. `res://bin/zem` (or `zem.exe`) for packaged builds
2. `../zem/zem` (or `zem.exe`) when running from the repo

When connecting to `localhost`/`127.0.0.1`, seqhiker will auto-start the installed local `zem` if not already running.

## Building bundled zem binaries

From repo root:

- Build one bundled binary for an export target:
  - `./build_zem_bins.sh --target darwin/arm64`
  - `./build_zem_bins.sh --target darwin/amd64`
  - `./build_zem_bins.sh --target linux/arm64`
  - `./build_zem_bins.sh --target linux/amd64`
  - `./build_zem_bins.sh --target windows/arm64`
  - `./build_zem_bins.sh --target windows/amd64`

This writes the canonical bundle file that seqhiker expects:

- `seqhiker/bin/zem`
- `seqhiker/bin/zem.exe` (Windows target)

You should run the matching `--target` command before exporting each platform preset.

- Build all common targets at once:
  - `./build_zem_bins.sh --all`

This writes matrix artifacts into `seqhiker/bin/targets/` as:

- `zem_<os>_<arch>` or `zem_<os>_<arch>.exe`

## Scripted app export

You can script full release builds (zem + Godot export) from repo root:

- `./build_release.sh --target darwin/arm64 --preset "macOS" --out /tmp/seqhiker-macos-arm64.zip`
- `./build_release.sh --target linux/amd64 --preset "Linux/X11" --out /tmp/seqhiker-linux-amd64.x86_64`
- `./build_release.sh --target windows/amd64 --preset "Windows Desktop" --out /tmp/seqhiker-win-amd64.exe`

Notes:

- Requires `seqhiker/export_presets.cfg` to exist with matching preset names.
- By default this also builds bundled `zem` for the provided target.
- Use `--skip-zem` to export without rebuilding `zem`.
