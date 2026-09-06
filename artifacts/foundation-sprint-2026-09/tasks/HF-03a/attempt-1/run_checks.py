#!/usr/bin/env python3
"""Run the HF-03a documentation gate; optional arg is candidate repo path.
All receipt paths resolve beside this script, including after retention.
"""
import hashlib, json, subprocess, sys
from pathlib import Path
root = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path.cwd()
out = Path(__file__).resolve().parent
base = "9cb8f51f901a6944428a7dcbea964ac0d4fc7634"
def git(*args):
    return subprocess.check_output(["git","-C",str(root),*args],text=True).strip()
candidate = git("rev-parse","HEAD")
checks = [
    ("scope", ["npm","run","check:scope","--",base,candidate,"--no-build"]),
    ("docs", ["npm","run","check:docs","--","--report",str(out/"check-docs.json")]),
    ("project", ["npm","run","check:project"]),
    ("contract", [sys.executable,str(out/"check_contract.py"),str(root)]),
    ("whitespace", ["git","diff","--check",base,candidate]),
]
results = []
for name,command in checks:
    result = subprocess.run(command,cwd=root,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    (out/(name+".log")).write_text(result.stdout)
    results.append(dict(name=name,command=command,cwd=str(root),exit_code=result.returncode,log=name+".log"))
    print(name, "PASS" if result.returncode==0 else "FAIL", "exit",result.returncode)
    if result.returncode:
        print(result.stdout)
section="docs/tech/sections/HF-03a-module-map.md"
report=dict(base=base,candidate=candidate,branch=git("branch","--show-current"),worktree=str(root),changed_paths=git("diff","--name-only",base,candidate).splitlines(),tracked_status=git("status","--short","--untracked-files=no"),output_sha256={section:hashlib.sha256((root/section).read_bytes()).hexdigest()},model=dict(requested="gpt-6-astra",effort="high",evidence="Coordinator reported successful host dispatch with explicit model=gpt-6-astra, reasoning_effort=high, fork_turns=none; no substitution reported. Worker has no introspection metadata."),checks=results,limits="documentation structure, source inspection and paper scenarios only; no engine or browser execution, build, publication or runtime qualification")
(out/"handoff.json").write_text(json.dumps(report,indent=2)+"\n")
sys.exit(0 if all(result["exit_code"]==0 for result in results) else 1)
