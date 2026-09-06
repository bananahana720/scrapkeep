#!/usr/bin/env python3
"""Paper/source checks only. Optional arg is the repository being checked.
Receipts are written beside this script so the directory is portable.
"""
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
out = Path(__file__).resolve().parent
base = "9cb8f51f901a6944428a7dcbea964ac0d4fc7634"
section = "docs/tech/sections/HF-03a-module-map.md"
doc = (root / section).read_text()
checks = []
def check(name, passed, detail):
    checks.append(dict(name=name, status="pass" if passed else "fail", detail=detail))

def git(*args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()

def sha(data):
    return hashlib.sha256(data).hexdigest()

expected = {
    "Session": "SessionControl RunState ProfileState EffectiveBuild PendingTransition".split(),
    "Encounter": "EncounterState TickState AttackLedger EncounterRandomState EncounterInbox".split(),
    "CollisionQueries": "CollisionWorldState QueryBatchState".split(),
    "ContentAdmission": "CatalogueAdmissionState CatalogueRegistry".split(),
    "Persistence": "SaveTransactionState DurableAggregate PreferencesRecord RecoveryState".split(),
    "InputAdapter": "PhysicalInputState InputContextState".split(),
    "Presentation": "PresentationState FeedbackState".split(),
}
table = doc.split("### Module table",1)[1].split("### Record meanings",1)[0]
rows = [line.split("|")[1:-1] for line in table.splitlines() if line.startswith("| ") and "---" not in line and "Owned mutable records" not in line]
check("five-column-seven-module-table", len(rows) == 7 and all(len(row)==5 for row in rows), str(len(rows)))
actual = {}
for row in rows:
    module = row[0].strip().split(".",1)[0]
    records = re.findall(r"`(\w+)`", row[1])
    actual[module] = records
    check("owner-row-"+module, module in expected and records == expected[module] and all(cell.strip() for cell in row) and "TADR-" in row[0], records)
counts = Counter(record for records in actual.values() for record in records)
check("unique-record-owners", len(counts)==22 and all(count==1 for count in counts.values()) and set(actual)==set(expected), dict(counts))
for record in counts:
    check("record-described-"+record, doc.count("`"+record+"`")>=2, "table plus record meaning")
clauses = {
    "adr/TADR-002-runtime-model.md": {24:"explicit encounter/run/profile records",26:"One application/session owner",28:"One collision-query owner",30:"resolves the attack once",32:"rebuilds effective effects",34:"clears held physical input"},
    "adr/TADR-003-content-pipeline.md": {25:"stable ID",27:"admission of one versioned catalogue",29:"Treat admitted definitions as immutable",31:"Missing content or an unsupported version",33:"A failed reload keeps the current catalogue"},
    "adr/TADR-004-persistence.md": {24:"under one persistence owner",26:"Persist actual offered options",28:"only then acknowledges",30:"Terminal defeat commits",32:"hold the transition",34:"validate the migrated result",40:"refuse automatic resumption"},
}
sources = ["BIBLE.md", "BACKLOG.md", "docs/tech/sections/HF-01-production-conventions.md", "native/project.godot", "native/tests/smoke_boot.gd", "docs/tech/proofs/S0-04-runtime-ownership.md", *clauses]
for name, lines in clauses.items():
    text = (root/name).read_text().splitlines()
    for line, snippet in lines.items():
        check(name+":"+str(line), snippet in text[line-1], snippet)
for task in ("S0-01", "S0-04"):
    path = "artifacts/prepare-stage-2026-09-06/tasks/"+task+"/native-smoke-report.json"
    sources.append(path)
    report = json.loads((root/path).read_text())
    check(task+"-historical-pass", report["verdict"] == "pass", report["generatedAt"])
    if task == "S0-04":
        proofs = sorted((root/"native/proofs/tadr-002").glob("*.gd"))
        check("S0-04-seven-script-receipt",len(proofs)==7,"historical hash equality; not execution")
        for proof in proofs:
            name = str(proof.relative_to(root)); sources.append(name)
            check("historical-source-"+proof.name,sha(proof.read_bytes())==report["files"][name],report["files"][name])
        check("no-class-name-in-S0-04", all(not re.search(r"^class_name\s", p.read_text(), re.M) for p in proofs), "explicit preloads only")
    else:
        original = subprocess.check_output(["git","-C",str(root),"show","7aaea699582c188eb2b1e3723bbb946e4b2c8f37:native/project.godot"],text=True)
        check("no-S0-01-autoload", "[autoload]" not in original,"admitted project settings")
        smoke = (root/"native/tests/smoke_boot.gd").read_text()
        check("no-S0-01-import-mechanism", all(token not in smoke for token in ("class_name", "preload(", "autoload")),"boot script source")
check("no-current-autoload", "[autoload]" not in (root/"native/project.godot").read_text(), "current settings")
scenario_rows = [line.split("|")[1:-1] for line in doc.splitlines() if re.match(r"\| M\d\d\s",line)]
check("eleven-paper-scenarios",[row[0].strip() for row in scenario_rows] == ["M%02d"%i for i in range(1,12)],"source-linked scenarios; human reasoning required")
check("scenario-source-and-result",all("PASS:" in row[2] and "TADR-" in row[2] for row in scenario_rows),"no engine result implied")
check("proof-limit-separation",all(term in doc for term in ("No proof was rerun", "not language-enforced privacy", "nested snapshot alias isolation", "bootstrap uniqueness", "placeholder", "no `class_name`", "HF-03a's S0-01 re-verification trigger is consumed now")),"required limits present")
manifest = {}
for name in sorted(set(sources)):
    data = (root/name).read_bytes()
    at_base = subprocess.check_output(["git","-C",str(root),"show",base+":"+name])
    manifest[name] = sha(data)
    check("base-source-"+name,data==at_base,manifest[name])
result = dict(method="paper structure and source inspection; no engine execution",base=base,head=git("rev-parse","HEAD"),section=section,section_sha256=sha((root/section).read_bytes()),source_manifest=manifest,checks=checks,scenarios=[dict(id=r[0].strip(),route=r[1].strip(),paper_result=r[2].strip()) for r in scenario_rows],status="pass" if all(c["status"]=="pass" for c in checks) else "fail")
(out/"contract-report.json").write_text(json.dumps(result,indent=2)+"\n")
for c in checks:
    if c["status"] != "pass":
        print("FAIL",c["name"],c["detail"])
print(result["status"].upper(),len(checks),"paper/source checks; report:",out/"contract-report.json")
sys.exit(0 if result["status"]=="pass" else 1)
