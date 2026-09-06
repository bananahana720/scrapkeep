import hashlib
import io
import json
import subprocess
import sys
import tarfile
import tomllib
from datetime import datetime, timezone
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
archive = output / "controller-source.tar.gz"
manifest_path = output / "manifest.json"
assert not archive.exists() and not manifest_path.exists(), "Use a new output directory"
installed = Path.home() / ".local/share/codex-native-input"
sources = {}
for name in ("control.py", "native-server.py", "README.md"):
    sources["native-input/" + name] = installed / name
controller = installed / "agent-desktop"
for path in sorted(controller.glob("*.py")) + [controller / "README.md"]:
    sources["native-input/agent-desktop/" + path.name] = path
for path in sorted((controller / "fixtures").iterdir()):
    if path.suffix in (".c", ".html"):
        sources["native-input/agent-desktop/fixtures/" + path.name] = path
upstream = installed / "hypruse"
for path in sorted(upstream.rglob("*")):
    relative = path.relative_to(upstream)
    if any(
        part in (".venv", ".git", "__pycache__", ".pytest_cache", ".ruff_cache")
        for part in relative.parts
    ):
        continue
    if path.is_file() and path.suffix != ".pyc" and relative.parts[0] != "assets":
        sources["native-input/hypruse/" + relative.as_posix()] = path
for name in ("codex-agent-desktop", "codex-desktop"):
    sources["bin/" + name] = Path.home() / ".local/bin" / name

files = {}
with tarfile.open(archive, "w:gz") as bundle:
    for name, path in sorted(sources.items()):
        assert path.is_file() and not path.is_symlink(), path
        data = path.read_bytes()
        mode = path.stat().st_mode & 0o777
        entry = tarfile.TarInfo(name)
        entry.size = len(data)
        entry.mode = mode
        bundle.addfile(entry, io.BytesIO(data))
        files[name] = {
            "source": str(path),
            "sha256": digest(data),
            "bytes": len(data),
            "mode": oct(mode),
        }

config = tomllib.loads((Path.home() / ".codex/config.toml").read_text())
registrations = {}
for name in ("native_desktop", "agent_desktop", "agent_studio"):
    value = config["mcp_servers"][name]
    registrations[name] = {
        key: value[key]
        for key in (
            "command",
            "args",
            "enabled",
            "startup_timeout_sec",
            "tool_timeout_sec",
            "default_tools_approval_mode",
            "enabled_tools",
            "disabled_tools",
        )
        if key in value
    }
    registrations[name]["env"] = {
        key: value
        for key, value in value.get("env", {}).items()
        if key in ("CODEX_AGENT_DESKTOP_STATE", "CODEX_AGENT_WORKSPACE_NAME")
    }
bindings = (Path.home() / ".config/hypr/bindings.lua").read_text().splitlines()
stop_binding = [
    line
    for line in bindings
    if '"Stop Codex desktop control"' in line and "codex-desktop stop" in line
]
assert len(stop_binding) == 1
python = installed / "hypruse/.venv/bin/python"
packages = json.loads(
    subprocess.check_output(
        [
            str(python),
            "-c",
            "import importlib.metadata as m,json,sys; print(json.dumps(dict(python=sys.version,packages=sorted([(d.metadata['Name'],d.version) for d in m.distributions()]))))",
        ],
        text=True,
    )
)
host_packages = subprocess.run(
    [
        "pacman",
        "-Q",
        "hyprland",
        "chromium",
        "grim",
        "libxkbcommon",
        "at-spi2-core",
        "gtk4",
    ],
    capture_output=True,
    text=True,
)
qualified = json.loads(
    (
        Path.cwd() / "artifacts/agent-recovery-2026-09-06/stationary-live/report.json"
    ).read_text()
)
differences = [
    name
    for name, sha in qualified["controller_hashes"].items()
    if digest((controller / name).read_bytes()) != sha
]
assert not differences, differences
with tarfile.open(archive, "r:gz") as bundle:
    members = bundle.getmembers()
    assert len(members) == len(files)
    for member in members:
        assert member.isfile() and member.name in files
        assert digest(bundle.extractfile(member).read()) == files[member.name]["sha256"]
source_differences = [
    name
    for name, item in files.items()
    if digest(Path(item["source"]).read_bytes()) != item["sha256"]
]
assert not source_differences, source_differences
manifest = {
    "captured_at": datetime.now(timezone.utc).isoformat(),
    "project_commit": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], text=True
    ).strip(),
    "archive": archive.name,
    "archive_sha256": digest(archive.read_bytes()),
    "archive_bytes": archive.stat().st_size,
    "files": files,
    "registrations_reference_only": registrations,
    "stop_binding_reference_only": stop_binding[0],
    "controller_runtime": packages,
    "host_packages": {
        "returncode": host_packages.returncode,
        "stdout": host_packages.stdout,
        "stderr": host_packages.stderr,
    },
    "qualification_controller_differences": differences,
    "source_changed_during_capture": source_differences,
    "archive_roundtrip_passed": True,
    "restore_verified": False,
    "excluded": [
        "browser profiles",
        "workspace state and leases",
        "journals",
        "backups",
        "full Codex and Hyprland configuration",
        "virtual environments",
        "compiled GTK fixtures",
        "upstream demo media",
    ],
}
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(
    json.dumps(
        {
            "files": len(files),
            "bytes": manifest["archive_bytes"],
            "archive_roundtrip_passed": True,
            "qualification_controller_differences": differences,
        }
    )
)
