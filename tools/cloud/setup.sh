#!/bin/bash
# Installs the pinned Scrapkeep cloud toolchain: Godot 4.7.2, its Linux export templates and
# Blender 5.2.2 LTS (the PyPI bpy wheel). Idempotent: a second run only checks hashes.
# Two callers: paste this file into the cloud environment's Setup script field so the
# environment cache keeps the toolchain, and .claude/hooks/session-start.sh, which runs it
# every session as a backstop. Godot URLs and hashes match the pinned Godot 4.7.2 release.
# The setup-script field fails the session on a non-zero exit, so a failure here only warns
# unless SCRAPKEEP_SETUP_STRICT=1 (the hook sets it and reports the error).
set -euo pipefail
if [ "${SCRAPKEEP_SETUP_STRICT:-}" != "1" ]; then
  trap 'echo "scrapkeep setup: line $LINENO failed; the SessionStart hook retries it" >&2; exit 0' ERR
fi

toolchain="${SCRAPKEEP_TOOLCHAIN:-/opt/scrapkeep-toolchain}"
godot="$toolchain/Godot_v4.7.2-stable_linux.x86_64"
templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.2.stable"
release=https://github.com/godotengine/godot/releases/download/4.7.2-stable

mkdir -p "$toolchain"

if ! printf '%s  %s\n' 8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e "$godot" | sha256sum --check --status 2>/dev/null; then
  curl --fail --silent --show-error --location --retry 3 --output "$toolchain/editor.zip" "$release/Godot_v4.7.2-stable_linux.x86_64.zip"
  printf '%s  %s\n' 9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65 "$toolchain/editor.zip" | sha512sum --check --quiet
  python3 -I -c 'import sys, zipfile; from pathlib import Path; p = Path(sys.argv[2]); p.write_bytes(zipfile.ZipFile(sys.argv[1]).read(p.name)); p.chmod(0o755)' "$toolchain/editor.zip" "$godot"
  rm -f "$toolchain/editor.zip"
  printf '%s  %s\n' 8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e "$godot" | sha256sum --check --quiet
fi

if [ ! -x "$templates/linux_release.x86_64" ] || [ ! -x "$templates/linux_debug.x86_64" ]; then
  curl --fail --silent --show-error --location --retry 3 --output "$toolchain/templates.tpz" "$release/Godot_v4.7.2-stable_export_templates.tpz"
  printf '%s  %s\n' ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079 "$toolchain/templates.tpz" | sha512sum --check --quiet
  mkdir -p "$templates"
  python3 -I -c '
import sys, zipfile
from pathlib import Path
out = Path(sys.argv[2])
with zipfile.ZipFile(sys.argv[1]) as archive:
    for name in ["version.txt", "linux_debug.x86_64", "linux_release.x86_64"]:
        (out / name).write_bytes(archive.read("templates/" + name))
        (out / name).chmod(0o755)
' "$toolchain/templates.tpz" "$templates"
  rm -f "$toolchain/templates.tpz"
fi

if ! python3 -I -c 'import bpy, sys; sys.exit(bpy.app.version_string != "5.2.2 LTS")' 2>/dev/null; then
  python3 -m pip install --quiet --disable-pip-version-check --root-user-action=ignore bpy==5.2.2
fi
