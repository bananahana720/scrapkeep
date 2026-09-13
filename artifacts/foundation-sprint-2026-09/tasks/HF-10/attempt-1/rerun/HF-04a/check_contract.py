#!/usr/bin/env python3
"""HF-04a source and paper checks. Optional repository root; outputs beside script.
These assertions inspect a prose contract, not an engine or gameplay model.
"""
import hashlib, json, re, subprocess, sys
from pathlib import Path
root = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path.cwd()
out = Path(__file__).resolve().parent
base = "7a73c5b5f44806c83924661b054051818174f07e"
section = "docs/tech/sections/HF-04a-runtime-lifecycle.md"
doc = (root/section).read_text()
checks=[]
def check(name,condition,detail):
    checks.append(dict(name=name,status="pass" if condition else "fail",detail=detail))
def sha(data): return hashlib.sha256(data).hexdigest()
def git(*args): return subprocess.check_output(["git","-C",str(root),*args],text=True).strip()
def basebytes(path): return subprocess.check_output(["git","-C",str(root),"show",base+":"+path])
def rows(prefix):
    return [[cell.strip() for cell in line.split("|")[1:-1]] for line in doc.splitlines() if re.match(r"\| "+prefix,line)]
def extract_heading(text, heading):
    lines=text.splitlines(); start=lines.index(heading); level=len(heading)-len(heading.lstrip("#"))
    end=next((i for i in range(start+1,len(lines)) if re.match(r"^#{1,"+str(level)+r"} ",lines[i])),len(lines))
    return "\n".join(lines[start:end]).strip()
def exact_card(text):
    # Cut at the next card anchor, not the next entire BACKLOG revision.
    return text.split("### HF-04a: Specify tick, pause and scene lifecycle",1)[1].split('<a id="hf-04b"></a>',1)[0].strip()
required=["Sources","Contract","Scenarios","Unresolved questions","Re-verification triggers","Procedure performed","Evidence limits"]
check("required-headings",all("## "+heading in doc for heading in required),required)
ticking=rows("C-TICK")
check("one-ticking-callback",len(ticking)==1 and len(ticking[0])==4 and ticking[0][2]=="Encounter" and "_physics_process(delta)" in ticking[0][1],ticking)
forbidden=rows("F-")
ids={row[0] for row in forbidden}
expected={"F-PROCESS","F-PHYSICS","F-INPUT","F-CONTROL","F-LIFECYCLE","F-SIGNAL","F-ASYNC","F-OTHER"}
check("default-deny-callback-coverage",ids==expected and len(forbidden)==8 and "### Forbidden" in doc and "Every callback other than C-TICK" in doc,sorted(ids))
phases=rows("P[0-6]:")
check("ordered-phases",[row[0][:2] for row in phases]==["P"+str(i) for i in range(7)],phases)
operations=rows("O[1-4]:")
check("four-separate-operations",len(operations)==4 and [row[0][:2] for row in operations]==["O1","O2","O3","O4"],operations)
for number,owner in [(1,"InputAdapter"),(2,"Encounter"),(3,"Session"),(4,"Session")]:
    check("operation-owner-O"+str(number),operations[number-1][1].startswith(owner),operations[number-1][1])
scenario=rows(r"T[1-5]\.")
expected_counts={1:5,2:6,3:5,4:5,5:8}
for n,count in expected_counts.items():
    found=[row for row in scenario if row[0].startswith("T"+str(n)+".")]
    check("scenario-T"+str(n),[row[0] for row in found]==["T%d.%d"%(n,i) for i in range(1,count+1)] and all(len(row)==5 for row in found),len(found))
for row in scenario:
    check("callback-"+row[0],row[2] in ids|{"C-TICK"} and (row[2]!="C-TICK" or row[1].startswith("Encounter")),dict(owner=row[1],callback=row[2]))
check("no-reverse-owner-chain",all(bad not in row[1] for row in scenario for bad in ("Presentation →", "InputAdapter →", "CollisionQueries →", "ContentAdmission →")),"owner text checked; narrative route requires review")
# Explicit paper trace of calls actually described by each scenario; return values use same edges.
S="Session"; E="Encounter"; C="CollisionQueries"; I="InputAdapter"; P="Presentation"; A="ContentAdmission"; D="Persistence"
allowed={(S,target) for target in (E,C,I,P,A,D)}|{(E,C),(E,I),(D,A)}
edges={
"T1.1":[(S,A),(S,D)],"T1.2":[(S,E),(E,C)],"T1.3":[(S,P),(S,I)],"T1.4":[(E,I),(E,C)],"T1.5":[(S,E),(S,P)],
"T2.1":[],"T2.2":[(S,I)],"T2.3":[(S,E)],"T2.4":[(S,P)],"T2.5":[(S,I)],"T2.6":[],
"T3.1":[(S,P)],"T3.2":[(S,I),(S,E)],"T3.3":[(S,P)],"T3.4":[(S,I)],"T3.5":[],
"T4.1":[],"T4.2":[],"T4.3":[(E,I)],"T4.4":[(E,C)],"T4.5":[(S,E),(S,I),(S,P)],
"T5.1":[],"T5.2":[(S,I),(S,E)],"T5.3":[(S,E),(E,C)],"T5.4":[(S,P)],"T5.5":[(S,E)],"T5.6":[(S,A),(S,E),(E,C)],"T5.7":[(S,I)],"T5.8":[]}
check("paper-edge-map-complete",set(edges)=={r[0] for r in scenario},"manually traced calls, not runtime import analysis")
for key, calls in edges.items(): check("edges-"+key,all(tuple(edge) in allowed for edge in calls),calls)
for label,terms in {
"cancel-before-pause":["O1 → O2 → O3","Return only after the cancellation is applied","non-advancing"],
"no-input-replay":["neutral","input-context generation","Regaining focus alone never resumes"],
"world-sync-and-error":["post-movement query world","last complete gameplay result","restored to that committed state"],
"stale-replacement":["already queued calls","retire","RunState, ProfileState and PendingTransition alive"],
"unresolved-rate":["B-frame","N-frame","proposed:Q-E03","currently unset","600-frame test ceiling"],
"proof-limit":["the assertion does not test the pending queue","It has not been executed","positive committed-result delivery","No historical source was changed or rerun"],
}.items(): check(label,all(term in doc for term in terms),terms)
full=["docs/tech/sections/HF-02-constraints-evidence.md","docs/tech/sections/HF-03a-module-map.md","docs/adr/0005-caster-input-and-dashboard.md","docs/tech/proofs/S0-04-runtime-ownership.md","native/project.godot","artifacts/prepare-stage-2026-09-06/tasks/S0-04/native-smoke-report.json"]
sources={}
for name in full:
    current=(root/name).read_bytes(); pinned=basebytes(name)
    sources[name]=dict(current_sha256=sha(current),base_sha256=sha(pinned),classification="identical" if current==pinned else "relevant-drift")
    check("source-"+name,current==pinned,sources[name])
for name,headings in {"BIBLE.md":["### Movement, camera and active aim","### HUD, dashboard and settings"],"adr/TADR-002-runtime-model.md":["## Decision","## Later qualification and reconsideration"]}.items():
    current=(root/name).read_text(); pinned=basebytes(name).decode()
    same=all(extract_heading(current,h)==extract_heading(pinned,h) for h in headings)
    sources[name]=dict(current_sha256=sha(current.encode()),base_sha256=sha(pinned.encode()),classification="identical" if current==pinned else "unrelated-drift" if same else "relevant-drift",sections=headings)
    check("scoped-source-"+name,same,sources[name])
name="BACKLOG.md"; current=(root/name).read_text(); pinned=basebytes(name).decode()
same=exact_card(current)==exact_card(pinned)
sources[name]=dict(current_sha256=sha(current.encode()),base_sha256=sha(pinned.encode()),exact_card_sha256=sha(exact_card(current).encode()),base_card_sha256=sha(exact_card(pinned).encode()),classification="identical" if current==pinned else "unrelated-drift" if same else "relevant-drift")
check("exact-card-HF-04a",same,sources[name])
report=json.loads((root/full[-1]).read_text())
check("historical-report-pass",report["verdict"]=="pass",report["generatedAt"])
proofs=sorted((root/"native/proofs/tadr-002").glob("*.gd"))
check("seven-proof-sources",len(proofs)==7,"historical source reconciliation")
for proof in proofs:
    name=str(proof.relative_to(root)); digest=sha(proof.read_bytes())
    sources[name]=dict(current_sha256=digest,historical_report_sha256=report["files"].get(name))
    check("historical-hash-"+proof.name,digest==report["files"].get(name),sources[name])
runner=(root/"native/proofs/tadr-002/proof_runner.gd").read_text()
eline=next(line for line in runner.splitlines() if '"held all false, tick' in line)
check("pending-printed-not-asserted","pending" not in eline.split(', "held all false')[0] and "coordinator.pending()" in eline,eline.strip())
session=(root/"native/proofs/tadr-002/session_owner.gd").read_text().split("func on_focus_lost()",1)[1].split("func lose_focus()",1)[0]
check("historical-queue-before-pause",session.index("input.clear_held()")<session.index("coordinator.submit")<session.index("pause()"),"synthetic source order; not new execution")
result=dict(method="paper/source inspection only",base=base,candidate=git("rev-parse","HEAD"),section_sha256=sha((root/section).read_bytes()),source_manifest=sources,checks=checks,scenario_steps=[dict(id=row[0],owner=row[1],callback=row[2],order=row[3],paper_result=row[4],listed_edges=edges[row[0]]) for row in scenario],status="pass" if all(c["status"]=="pass" for c in checks) else "fail")
(out/"contract-report.json").write_text(json.dumps(result,indent=2)+"\n")
for c in checks:
    if c["status"]!="pass": print("FAIL",c["name"],c["detail"])
print(result["status"].upper(),len(checks),"paper/source checks;",len(scenario),"scenario steps")
sys.exit(0 if result["status"]=="pass" else 1)
