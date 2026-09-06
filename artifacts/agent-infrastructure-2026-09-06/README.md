# Preserved Linux controller source

Captured 6 September 2026 after game-player commit `3077799`. This record preserves the installed source dependency that lives outside the game repository. The live controller remains the implementation imported by the player. The archive is a recovery copy, not another active controller.

## Contents and provenance

The [archive](controller-source.tar.gz) contains the named-desktop controller, its tests and fixture source, the shared stop wrapper, CLI launchers, and the installed Hypruse source with its MIT license and lockfile. The [manifest](manifest.json) records each file's original path, mode and SHA-256, the archive hash, installed Python packages and selected host package versions. It also records references for the three MCP registrations, their enabled tools and approval modes, and the one emergency-stop binding. It excludes full configuration, profiles, leases, journals, backups, virtual environments and compiled fixtures.

All 94 archived files passed a read-back hash check and still matched their installed originals at capture completion. Every controller hash recorded in the [accepted native batch](../agent-recovery-2026-09-06/stationary-live/report.json) matched. Capturing this archive did not operate desktop input or change the installation.

Installed package metadata identifies Hypruse 0.10.0. The installed operations guide records upstream commit `7dd11acae0a5631825907f0ba8340dd4088998c4`; its source directory has no Git metadata. Per-file hashes establish the bytes preserved here. The locked dependencies and installed package inventory describe this host, not a tested portable installation.

## Inspect or recover the source

From the project root, verify the archive before extracting it into an empty staging directory:

```sh
python3 - <<'PY'
import hashlib, json
from pathlib import Path
p = Path('artifacts/agent-infrastructure-2026-09-06')
m = json.loads((p / 'manifest.json').read_text())
assert hashlib.sha256((p / m['archive']).read_bytes()).hexdigest() == m['archive_sha256']
print('Archive hash matches')
PY
```

Compare the staged files with the installation paths in the manifest. Restore only the intended files after reviewing differences. The launchers and registration references contain this host's absolute paths. Recreate required environments from the preserved dependency metadata, then validate the installed controller checks and the project's [native smoke command](../../tools/agent-player/README.md#commands). Reapply only the selected registrations and stop binding when they are missing. Existing host policy still controls tool calls.

A clean-machine restore, dependency reinstall and physical stop shortcut were not tested in this closeout. The manifest marks `restore_verified` as false. This local archive also does not establish off-machine backup.

## Capture a later qualified version

The [capture script](capture.py) requires Python 3.11 or newer and a new output directory. It reads a narrow source/configuration selection, checks every archived member, and refuses an existing archive or manifest. Run it from the project root. Its controller comparison deliberately names this session's acceptance report; update that reference only when preserving a newly qualified controller version.

The [engineering guide](../../docs/project/AGENT-PLAYTEST-ENGINEERING.md) owns remaining scope. The [workspace ADR](../../docs/adr/0006-agent-playtest-workspaces.md) owns the architecture.
