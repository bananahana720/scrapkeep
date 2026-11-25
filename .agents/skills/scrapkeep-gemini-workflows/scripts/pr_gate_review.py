"""Run scoped PR verification and an independent read-only Gemini review."""

import json
import os
import re
import shlex
import subprocess


def default_base_from_state():
    state_path = "project-guide/handoff/STATE.md"
    if os.path.exists(state_path):
        with open(state_path, encoding="utf8") as fh:
            m = re.search(r"\|\s*Open stage\s*\|\s*(stage/alpha-w\d+)\s*\|", fh.read())
            if m:
                return f"origin/{m.group(1)}"
    return "origin/main"


def run_cmd(argv, clip=8000):
    proc = subprocess.run(argv, capture_output=True, text=True)
    combined = proc.stdout
    if proc.stderr:
        combined = f"{combined}\n{proc.stderr}".strip() if combined else proc.stderr
    if len(combined) > clip:
        head_len = min(2500, clip // 2)
        tail_len = clip - head_len
        combined = (
            combined[:head_len]
            + f"\n...[truncated {len(combined) - clip} chars]...\n"
            + combined[-tail_len:]
        )
    return {
        "command": " ".join(shlex.quote(a) for a in argv),
        "exit_code": proc.returncode,
        "ok": proc.returncode == 0,
        "output": combined.strip(),
    }


base = args.get("base") or default_base_from_state()
candidate = args.get("candidate", "HEAD")
consequential = bool(args.get("consequential", False))
acceptance = args.get(
    "acceptance",
    "Verify correctness, scope, and adherence to AGENTS.md / LEGIBILITY.md §13.",
)

phase("Scope and diff")
scope_res = run_cmd(["node", "scripts/check-scope.mjs", base, candidate])
diff_stat_res = run_cmd(["git", "diff", "--stat", f"{base}..{candidate}"])
diff_body_res = run_cmd(["git", "diff", f"{base}..{candidate}"], clip=85000)

phase("Scoped verification checks")
changed_files_proc = subprocess.run(
    ["git", "diff", "--name-only", f"{base}..{candidate}"],
    capture_output=True,
    text=True,
)
changed_tests = [
    p for p in changed_files_proc.stdout.splitlines()
    if re.search(r"\.test\.(?:js|mjs)$", p) and os.path.exists(p)
]

executable_argv = [
    ["npm", "run", "check:agents"],
    ["npm", "run", "check:skills"],
]
if changed_tests:
    executable_argv.append(["node", "--test", *changed_tests])
in_required = False
for raw_line in scope_res["output"].splitlines():
    line = raw_line.strip()
    if line == "required commands:":
        in_required = True
        continue
    if in_required:
        if not raw_line.startswith("  "):
            in_required = False
            continue
        if line.startswith("npm run sketch:smoke"):
            argv = ["npm", "run", "sketch:fast", "--", "--base", base]
        elif line == "npm test":
            argv = ["npm", "test"]
        elif line.startswith("npm run ") and "(reserved" not in line:
            argv = shlex.split(line)
        else:
            continue
        if argv not in executable_argv:
            executable_argv.append(argv)

checks = [run_cmd(argv) for argv in executable_argv]
for c in checks:
    log(f"{c['command']} -> exit {c['exit_code']}")

phase("Independent review")
# AGENTS.md Rules 4 & 11 (ruling ej): every independent admission review must run on a fresh
# Gemini 4 Neon session at high effort. Defaulting model="inherit" preserves the caller's Neon-high
# session; an explicit fallback model (e.g. "pro") is advisory only and does not admit a unit.
reviewer_type = "scrapkeep-reviewer" if consequential else "scrapkeep-reviewer-medium"
reviewer_model = args.get("reviewer_model") or "inherit"
review_schema = {
    "type": "object",
    "properties": {
        "verdict": {"type": "string", "enum": ["PASS", "PASS+NOTES", "FAIL", "BLOCKED", "INCONCLUSIVE"]},
        "evidence_level": {"type": "string"},
        "findings": {"type": "array", "items": {"type": "string"}},
        "summary": {"type": "string"},
    },
    "required": ["verdict", "evidence_level", "findings", "summary"],
}

prompt = (
    f"Independently review {base}..{candidate}.\n"
    f"Acceptance criteria: {acceptance}\n\n"
    f"Scope output (exit {scope_res['exit_code']}):\n{scope_res['output']}\n\n"
    f"Verification receipts:\n{json.dumps(checks, indent=2)}\n\n"
    f"Diff stat:\n{diff_stat_res['output']}\n\n"
    f"Diff:\n{diff_body_res['output']}\n"
)

review = await agent(
    prompt,
    schema=review_schema,
    role=f"Independent {reviewer_type}",
    type_name=reviewer_type,
    workspace="inherit",
    model=reviewer_model,
)

result = {
    "base": base,
    "candidate": candidate,
    "reviewer": reviewer_type,
    "checks": [{"command": c["command"], "exit_code": c["exit_code"], "ok": c["ok"]} for c in checks],
    "review": review,
}
log(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
