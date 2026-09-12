#!/usr/bin/env python3
"""HF-04b paper checks. Usage: check_patterns.py <repository-root>.

Reads the admitted sources and the HF-04b section; never executes a proof,
editor or engine. Writes patterns-report.json beside this script.
"""
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SECTION = "docs/tech/sections/HF-04b-runtime-patterns.md"
PROOF_COMMIT = "1d631946ffaabaadc4d998b557a9a5f2af80dfef"
MARKER = "unparsed: no editor run in this card; scene replacement and scoped teardown await a later authorized proof"
MODULES = ["Session", "Encounter", "CollisionQueries", "ContentAdmission", "Persistence", "InputAdapter", "Presentation"]
PATTERNS = ["PT-LOOP", "PT-STATE", "PT-SIGNAL", "PT-SCENE"]
HEADINGS = ["Sources", "Contract", "Scenarios", "Unresolved questions", "Re-verification triggers", "Procedure performed", "Evidence limits"]

HASHES = {
    "native/proofs/tadr-002/encounter_coordinator.gd": "12fbe3ffae55cc28e3eb76b5f4c676097dbdfe37aee68e53259496dc2e21e06a",
    "native/proofs/tadr-002/encounter_state.gd": "edcaa69aec05a9122f7a8e43f653a94a0a2151a745edb956de16e0e5f1b4b1fc",
    "native/proofs/tadr-002/input_adapter.gd": "4cfd73130161089a57e29196bade8c73757cc7c771242c6ab9b631c0fcac86c9",
    "native/proofs/tadr-002/intruder.gd": "6acda6f23a8ed6171918fb6ed37d710dea167ab989d46d5e20c157755d26445d",
    "native/proofs/tadr-002/menu_probe.gd": "7d977c48f08cf8844b50d61f1dfdb76d27f454d70136ae21fb7c548fbc35461c",
    "native/proofs/tadr-002/proof_runner.gd": "26951707b179ac5105d474dbe1a266c730da5fe88bc05c2b3a69eab82d5b6ede",
    "native/proofs/tadr-002/session_owner.gd": "0ce10bca17c03e84d8dbabf9a9d07e94f670ce676424a25a95a915e53c71e889",
    "artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt": "06df793046406c3f15e73a2e8bf5c60d564b8c534ee11e12999fd5768d6a3ad8",
    "artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt": "8d4a7289821c5622c7159a364ed5a7ba1f6715a1ce76af4faa3e4cc86f11ab98",
    "docs/tech/sections/HF-04a-runtime-lifecycle.md": "7eb7ad2c909b715e62051d2d73e353f445b96270f3140b38c1c38c4c3fc171fb",
    "docs/tech/sections/HF-03a-module-map.md": "95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc",
    "docs/tech/proofs/S0-04-runtime-ownership.md": "c8c223d5e147c099b9291dc422b0c832b81ac7f0a4f9fcfc973d4e8a045d466d",
    "native/project.godot": "4af482fbc0489396ea4b2ab2906987f4805d60e12a5eb2ee651296926edaa409",
    "scripts/native-smoke.mjs": "301d67c2457fbb962d31f49e7b77e9731f1df5e3308a16c7c096badbc22d5979",
    "adr/TADR-002-runtime-model.md": "dc021675c68ab1b750b1c0e6dc1f8f17a7f5627d32a00c36c5423b4b39a2c696",
    "adr/TADR-001-engine-language-platforms.md": "84d0873543acb547d6ffd860ab51659b3a634ab0429f310bc41c7951c822f4e9",
}

# (file, 1-based line, required substring)
CITED_LINES = [
    ("native/proofs/tadr-002/proof_runner.gd", 59, 'check("A", state.tick - tick0 == N'),
    ("native/proofs/tadr-002/proof_runner.gd", 60, 'check("A", session.run_id == run_id'),
    ("native/proofs/tadr-002/proof_runner.gd", 72, 'check("B", coordinator.rejected_out_of_phase >= 2 and coordinator.accepted_in_phase == 0'),
    ("native/proofs/tadr-002/proof_runner.gd", 73, 'check("B", state.tick == coordinator.physics_calls'),
    ("native/proofs/tadr-002/proof_runner.gd", 74, 'check("B", intruder.copy.casts_committed >= 2'),
    ("native/proofs/tadr-002/proof_runner.gd", 88, 'check("C", held.prepared == "cast" and held.casts_committed == 0 and state.casts_committed == 1'),
    ("native/proofs/tadr-002/proof_runner.gd", 102, 'check("D", paused and state.tick == tick0'),
    ("native/proofs/tadr-002/proof_runner.gd", 103, 'check("D", menu.process_calls > menu0'),
    ("native/proofs/tadr-002/proof_runner.gd", 104, 'check("D", state.prepared == "cast"'),
    ("native/proofs/tadr-002/proof_runner.gd", 120, 'check("E", paused and not session.input.any_held() and during.tick == tick0'),
    ("native/proofs/tadr-002/proof_runner.gd", 125, 'check("E", state.prepared == "" and state.casts_committed == casts_before and state.casts_committed == 1'),
    ("native/proofs/tadr-002/proof_runner.gd", 126, 'check("E", state.tick == tick0 + N and state.tick == coordinator.physics_calls'),
    ("native/proofs/tadr-002/proof_runner.gd", 33, "PLACEHOLDER_TICK_RATE"),
    ("native/proofs/tadr-002/proof_runner.gd", 154, "func check(phase: String, ok: bool, detail: String) -> void:"),
    ("native/proofs/tadr-002/encounter_coordinator.gd", 18, "func submit(command: String) -> void:"),
    ("native/proofs/tadr-002/encounter_coordinator.gd", 31, "if not (Engine.is_in_physics_frame() and _in_phase):"),
    ("native/proofs/tadr-002/encounter_coordinator.gd", 39, "func _physics_process(_delta: float) -> void:"),
    ("native/proofs/tadr-002/encounter_coordinator.gd", 47, "for command: String in _queue:"),
    ("native/proofs/tadr-002/encounter_coordinator.gd", 51, 'if frame.released["cast"] and _state.prepared != "":'),
    ("native/proofs/tadr-002/encounter_coordinator.gd", 54, "_state.tick += 1"),
    ("native/proofs/tadr-002/encounter_coordinator.gd", 59, "CMD_PREPARE_CAST:"),
    ("native/proofs/tadr-002/encounter_coordinator.gd", 61, "CMD_CANCEL_PREPARED:"),
    ("native/proofs/tadr-002/encounter_state.gd", 10, "func snapshot() -> EncounterState:"),
    ("native/proofs/tadr-002/input_adapter.gd", 31, "result.released[action] = _previous[action] and not _held[action]"),
    ("native/proofs/tadr-002/input_adapter.gd", 36, "func clear_held() -> void:"),
    ("native/proofs/tadr-002/input_adapter.gd", 42, "func any_held() -> bool:"),
    ("native/proofs/tadr-002/session_owner.gd", 18, "func pause() -> void:"),
    ("native/proofs/tadr-002/session_owner.gd", 22, "func resume() -> void:"),
    ("native/proofs/tadr-002/session_owner.gd", 26, "func on_focus_lost() -> void:"),
    ("native/proofs/tadr-002/session_owner.gd", 28, "coordinator.submit(EncounterCoordinator.CMD_CANCEL_PREPARED)"),
    ("native/proofs/tadr-002/session_owner.gd", 34, "propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)"),
    ("native/proofs/tadr-002/session_owner.gd", 42, "if what == NOTIFICATION_APPLICATION_FOCUS_OUT:"),
    ("native/proofs/tadr-002/menu_probe.gd", 7, "process_mode = Node.PROCESS_MODE_ALWAYS"),
    ("native/proofs/tadr-002/intruder.gd", 17, "get_tree().create_timer(0.05).timeout.connect(_on_timeout)"),
    ("native/proofs/tadr-002/intruder.gd", 24, "func _process(_delta: float) -> void:"),
    ("native/proofs/tadr-002/intruder.gd", 31, "func _on_timeout() -> void:"),
    ("native/proofs/tadr-002/intruder.gd", 37, "coordinator.advance_external()"),
    ("native/proofs/tadr-002/intruder.gd", 42, "coordinator._state.tick += 1"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 1, "Godot Engine v4.7.2.stable.official.ed1daf0bf"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 3, "S0-04 PLACEHOLDER_TICK_RATE 60"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 4, "S0-04 A PASS tick 10 physics_calls 10 after 10 frames"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 5, "S0-04 A PASS run_id run-0001 unchanged"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 6, "S0-04 B PASS rejected_out_of_phase 35 accepted_in_phase 0 (process 34 timer 1)"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 7, "S0-04 B PASS tick 24 physics_calls 24"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 8, 'S0-04 B PASS intruder copy casts 35 prepared intruder; coordinator casts 0 prepared ""'),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 9, 'S0-04 C PASS prepared while held "cast"; casts_committed 1 after release'),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 10, "S0-04 D PASS tick 29 constant across 10 frames while paused"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 11, "S0-04 D PASS menu probe _process 74 -> 98"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 12, 'S0-04 D PASS prepared "cast" untouched by pause'),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 13, "S0-04 focus trigger notification"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 14, "S0-04 E PASS held all false, tick 31 constant"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 15, 'S0-04 E PASS prepared "" casts_committed 1 after resume'),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 16, "S0-04 E PASS tick 41 advancing after resume"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 17, '"exit_code":0'),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt", 18, "direct exit=0"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt", 1, "Godot Engine v4.7.2.stable.official.ed1daf0bf"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt", 6, "S0-04 B PASS rejected_out_of_phase 35 accepted_in_phase 0"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt", 7, "S0-04 B FAIL tick 59 physics_calls 24"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt", 8, "S0-04 B PASS intruder copy casts 35"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt", 9, "S0-04 C PASS"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt", 15, 'S0-04 E PASS prepared "" casts_committed 1 after resume'),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt", 16, "S0-04 E FAIL tick 76 advancing after resume"),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt", 17, '"failures":2'),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt", 17, '"exit_code":1'),
    ("artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-fault.txt", 18, "direct exit=1"),
    ("native/project.godot", 11, "gdscript/warnings/untyped_declaration=2"),
    ("native/project.godot", 12, "gdscript/warnings/inferred_declaration=2"),
    ("native/project.godot", 13, "gdscript/warnings/unsafe_property_access=2"),
    ("native/project.godot", 14, "gdscript/warnings/unsafe_method_access=2"),
    ("native/project.godot", 15, "gdscript/warnings/unsafe_cast=2"),
    ("native/project.godot", 16, "gdscript/warnings/unsafe_call_argument=2"),
    ("scripts/native-smoke.mjs", 264, "async function discoverProofs() {"),
    ("scripts/native-smoke.mjs", 279, 'script: "res://proofs/" + item.name + "/" + proofRunner,'),
    ("scripts/native-smoke.mjs", 297, "function proofRun(binary, proof) {"),
    ("scripts/native-smoke.mjs", 314, "function proofFaultRun(binary, proof) {"),
    ("docs/tech/sections/HF-04a-runtime-lifecycle.md", 20, "Encounter is the only gameplay-time owner."),
    ("docs/tech/sections/HF-04a-runtime-lifecycle.md", 34, "| C-TICK"),
    ("docs/tech/sections/HF-04a-runtime-lifecycle.md", 88, "| O2: cancel prepared actions"),
    ("docs/tech/sections/HF-04a-runtime-lifecycle.md", 94, "A pure internal pause remains separable, as S0-04 phase D demonstrates"),
    ("docs/tech/sections/HF-04a-runtime-lifecycle.md", 110, "Session disconnects each scoped subscription it established."),
    ("docs/tech/sections/HF-03a-module-map.md", 55, "1. Commands request a mutation from its owner."),
    ("docs/tech/sections/HF-03a-module-map.md", 61, "7. Scoped signals publish committed results or user requests."),
    ("docs/tech/proofs/S0-04-runtime-ownership.md", 86, "HF-04b revision 2, which replaces its sketches with links to this source"),
]

NON_PROOF_STATEMENTS = [
    "These examples do not prove a complete production state machine.",
    "They do not prove positive committed-result signal delivery.",
    "They do not prove scoped connection teardown.",
]

TYPED_VAR = re.compile(r"^\s*var\s+\w+\s*:\s*[A-Za-z_][\w\[\], ]*(\s*=\s*.+)?$")
TYPED_FUNC = re.compile(r"^\s*func\s+\w+\((.*)\)\s*->\s*[A-Za-z_]\w*\s*:$")
TYPED_FOR = re.compile(r"^\s*for\s+\w+\s*:\s*[A-Za-z_]\w*\s+in\s+.+:$")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_patterns.py <repository-root>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1]).resolve()
    here = Path(__file__).resolve().parent
    findings: list[dict] = []
    checks: list[dict] = []

    def record(name: str, ok: bool, detail: str) -> None:
        checks.append({"check": name, "result": "pass" if ok else "fail", "detail": detail})
        if not ok:
            findings.append({"check": name, "detail": detail})

    head = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], capture_output=True, text=True, check=False)
    branch = subprocess.run(["git", "-C", str(root), "branch", "--show-current"], capture_output=True, text=True, check=False)
    dirty = subprocess.run(["git", "-C", str(root), "status", "--porcelain"], capture_output=True, text=True, check=False)

    section_path = root / SECTION
    record("section-exists", section_path.is_file(), SECTION)
    if not section_path.is_file():
        return finish(here, root, head, branch, dirty, checks, findings)
    text = section_path.read_text(encoding="utf-8")
    lines = text.split("\n")

    present = {m.group(1).strip() for m in (re.match(r"^##\s+(.+?)\s*$", l) for l in lines) if m}
    for heading in HEADINGS:
        record("heading:" + heading, heading in present, "required section heading")

    manifest: dict[str, str] = {}
    for rel, expected in HASHES.items():
        path = root / rel
        exists = path.is_file()
        actual = sha256(path) if exists else ""
        manifest[rel] = actual
        record("exists:" + rel, exists, "linked source or receipt present")
        record("hash:" + rel, actual == expected, f"expected {expected} actual {actual}")
        if rel.endswith(".gd") or rel.endswith(".txt") or rel.endswith("HF-04a-runtime-lifecycle.md") or rel.endswith("HF-03a-module-map.md"):
            record("cited-in-section:" + rel, expected in text, "hash quoted in the section")

    for rel in HASHES:
        if not rel.startswith("native/proofs/tadr-002/"):
            continue
        log = subprocess.run(["git", "-C", str(root), "log", "--format=%H", "--", rel], capture_output=True, text=True, check=False)
        commits = [c for c in log.stdout.split() if c]
        record("pinned-commit:" + rel, commits == [PROOF_COMMIT], f"git log commits {commits}")

    cache: dict[str, list[str]] = {}
    for rel, number, needle in CITED_LINES:
        if rel not in cache:
            path = root / rel
            cache[rel] = path.read_text(encoding="utf-8").split("\n") if path.is_file() else []
        source = cache[rel]
        line = source[number - 1] if number - 1 < len(source) else ""
        record(f"cited-line:{rel}:{number}", needle in line, f"expected substring {needle!r}; actual {line.strip()!r}")

    fenced: list[tuple[int, list[str]]] = []
    inside = False
    start = 0
    block: list[str] = []
    for index, line in enumerate(lines, start=1):
        if line.startswith("```"):
            if inside:
                fenced.append((start, block))
                block = []
                inside = False
            else:
                inside = True
                start = index
                block = []
            continue
        if inside:
            block.append(line)
    record("fenced-blocks", len(fenced) == 1, f"{len(fenced)} fenced block(s); the card allows one retained inline sketch")
    for start, block in fenced:
        first = block[0] if block else ""
        record(f"marker-inside:{start}", MARKER in first, "first line of the fence carries the unparsed marker")
        preceding = "\n".join(lines[max(0, start - 12):start - 1])
        record(f"marker-before:{start}", MARKER in preceding, "unparsed marker appears in the prose before the fence")
        untyped: list[str] = []
        for code in block:
            stripped = code.strip()
            if not stripped or stripped.startswith("#") or stripped.startswith("extends"):
                continue
            if ":=" in code:
                untyped.append(code)
            elif stripped.startswith("var ") and not TYPED_VAR.match(code):
                untyped.append(code)
            elif stripped.startswith("func ") and not TYPED_FUNC.match(code):
                untyped.append(code)
            elif stripped.startswith("for ") and not TYPED_FOR.match(code):
                untyped.append(code)
        record(f"typed-form:{start}", not untyped, "untyped or inferred declarations: " + json.dumps(untyped))
        func_params = [m.group(1) for m in (TYPED_FUNC.match(c) for c in block) if m]
        bad_params = [p for p in func_params if p.strip() and any(":" not in part for part in p.split(","))]
        record(f"typed-params:{start}", not bad_params, "parameters without types: " + json.dumps(bad_params))

    owner_rows = [l for l in lines if l.startswith("| PT-")]
    for pattern in PATTERNS:
        rows = [l for l in owner_rows if l.startswith("| " + pattern)]
        named = any(any(m in row for m in MODULES) for row in rows)
        record("owner:" + pattern, bool(rows) and named, f"{len(rows)} owner/catalogue row(s) naming an HF-03a module")

    for statement in NON_PROOF_STATEMENTS:
        record("non-proof:" + statement[:40], statement in text, "explicit non-proof statement present")

    for needle in ["X1", "X2", "X3", "X4", "S0-04-int-proof-run.txt", "S0-04-int-proof-fault.txt", PROOF_COMMIT]:
        record("example-ref:" + needle, needle in text, "example identity present")

    rate_lines = [l for l in lines if re.search(r"\b60\s*(Hz|ticks)|PLACEHOLDER_TICK_RATE|60 and printed", l)]
    unqualified = [l for l in rate_lines if not re.search(r"placeholder|Placeholder|default|unset|no production|supplies no", l)]
    record("no-rate-adoption", not unqualified, "every 60 Hz mention is labelled placeholder/default: " + json.dumps([l[:80] for l in unqualified]))

    for phrase in ["satisfied by this source and retained-evidence review", "No native execution occurred for this card"]:
        record("trigger:" + phrase[:30], phrase in text, "S0-04 trigger disposition present")

    return finish(here, root, head, branch, dirty, checks, findings, manifest)


def finish(here, root, head, branch, dirty, checks, findings, manifest=None) -> int:
    report = {
        "task": "HF-04b",
        "attempt": "HF-04b-A1",
        "generated": datetime.now(timezone.utc).isoformat(),
        "root": str(root),
        "head": head.stdout.strip(),
        "branch": branch.stdout.strip(),
        "dirty": [l for l in dirty.stdout.split("\n") if l],
        "result": "pass" if not findings else "fail",
        "checks": len(checks),
        "failures": len(findings),
        "findings": findings,
        "manifest": manifest or {},
        "details": checks,
        "limits": "Paper checks over admitted bytes: presence, hashes, pinned commits, cited lines, unparsed marker and typed form by regex, owner naming. No proof, editor, engine or build was run; typed form is not a parse result.",
    }
    (here / "patterns-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for finding in findings:
        print("FAIL", finding["check"], finding["detail"])
    print(f"check_patterns {report['result']}: {len(checks)} checks, {len(findings)} failures. Report: {here / 'patterns-report.json'}")
    print(report["limits"])
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
