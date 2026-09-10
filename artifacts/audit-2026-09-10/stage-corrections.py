#!/usr/bin/env python3
"""Build staged canonical corrections for the 2026-09-10 deslop audit.

Reads the repo working copies, applies exact-string corrections in a scratch tree
under artifacts/local/audit-2026-09-10/staged/work/, and emits a unified patch.
Never modifies the repository. Every edit asserts exactly one match.
"""
import os
import shutil
import subprocess
import sys

REPO = "/home/andrew/Projects/scrapkeep"
STAGE = os.path.join(REPO, "artifacts/local/audit-2026-09-10/staged")
WORK = os.path.join(STAGE, "work")

# (relative path, finding IDs, old, new)
EDITS = [
    # ---- L3-01: start-here doc contradicts the authorized scope
    ("README.md", "L3-01",
     "The foundation-contract sprint is proposed and has not started; the complete engineering Bible remains future work.",
     "The fourteen-card foundation sprint is authorized as documentation-only work and is in progress "
     "([program authorization](TRACKING.md#program-authorization)); the complete engineering Bible remains future work."),

    # ---- L3-02: live scope authority says the sprint is unauthorized
    ("docs/project/sprint-0/AUTHORIZATION.md", "L3-02",
     "Keep Q-E06 open and the fourteen-card foundation sprint awaiting_review.",
     "Keep Q-E06 open. Superseded 2026-09-06: the fourteen-card foundation sprint was subsequently authorized "
     "as documentation-only work (`TRACKING.md` EV-0078); this scope statement is retained as history and no "
     "longer describes the current authorization."),

    # ---- L2-02 / L3-06: state token outside the board's own enum
    ("TRACKING.md", "L2-02,L3-06",
     "| [HF-04a](BACKLOG.md#hf-04a) | 1 | 5 | IN_REVIEW | none | none | EV-0091 |",
     "| [HF-04a](BACKLOG.md#hf-04a) | 1 | 5 | review | none | none | EV-0091 |"),

    # ---- L2-06 / L3-08: summary contradicts the index it summarizes
    ("TRACKING.md", "L2-06,L3-08",
     "Last reported event: EV-0087. Latest admitted checkpoint: 3/14 done (HF-01, HF-02, HF-03a); no active writer after the first handoff.",
     "Last reported event: EV-0092. Latest admitted checkpoint: 3/14 done (HF-01, HF-02, HF-03a). "
     "HF-04a is in review (handoff recorded at EV-0091); HF-05 was delivered but its handoff is not yet recorded."),

    # ---- L2-04 / L2-11: wrong check count and glued text in the uncommitted rows
    ("TRACKING.md", "L2-04,L2-11",
     "inspected;118 paper/source checks reported, docs/project pass.",
     "inspected; 126 paper/source checks PASS in the final receipt, docs/project pass."),
    ("TRACKING.md", "L2-11,F-P5",
     "Observed leased HF04a draft, one C-TICK owner,8 forbidden callback families,P0-P6 fixed phases,O1-O4 control operations and5 tabletop tables. Source review distinguishes S004 queued cancellation",
     "Observed leased HF-04a draft: one C-TICK owner, 8 forbidden callback families, P0-P6 fixed phases, "
     "O1-O4 control operations and 5 tabletop tables. Source review distinguishes S0-04 queued cancellation"),
    ("TRACKING.md", "L2-11,F-P5",
     "candidate72178cf58a39e9ca1c70922eca830776573f3ce8; sole sectionsha7eb7ad2c909b715e62051d2d73e353f445b96270f3140b38c1c38c4c3fc171fb; original100 paper/source",
     "candidate 72178cf58a39e9ca1c70922eca830776573f3ce8; sole section sha256 "
     "7eb7ad2c909b715e62051d2d73e353f445b96270f3140b38c1c38c4c3fc171fb; original 100 paper/source"),
    ("TRACKING.md", "L2-11,F-P5",
     "actual draft inspected,5 scenario tables and single-owner callback contract; next exact-card/source checks and handoff.",
     "actual draft inspected, 5 scenario tables and single-owner callback contract; handoff completed "
     "(candidate produced, checks run, lease closed, review pending)."),

    # ---- L3-12b / L3-18: definitions file presenting itself as the authority
    ("BACKLOG.md", "L3-12b,L3-18",
     "The fourteen-card foundation set below is a dependency programme, not a dispatch authorization. TRACKING selects the current bounded proposal under ORCHESTRATOR's maximum-four-card rule.",
     "The fourteen-card foundation set below is a dependency programme, not a dispatch authorization; it was "
     "authorized as documentation-only work on 6 September 2026. Authorization lives in `TRACKING.md` "
     "([program authorization](TRACKING.md#program-authorization)); this file never grants it."),

    # ---- L3-27 / H-11: historical closeout asserting a state that changed
    ("docs/project/HOUSEKEEPING.md", "L3-27,H-11",
     "No remote is configured yet, so there is still no off-machine backup until Andrew authorizes one and it is published.",
     "Superseded 2026-09-06: a private remote is now configured and was verified (`TRACKING.md` EV-0018), so this "
     "historical note no longer describes the current state; work committed since the last published tip remains unpushed."),

    # ---- L3-09 / H-11: coordinator-owned disposition table carrying resolved questions as open
    ("docs/project/SOURCE-DISPOSITIONS.md", "L3-09",
     "Local Git history exists; no remote publication is authorized by preparation. CONTRIBUTING.md records baseline 4db9b31 and explicit remote gate.",
     "Local Git history exists; CONTRIBUTING.md records baseline 4db9b31 and the explicit remote gate. "
     "Answered 2026-09-06: a private remote was authorized and verified (`TRACKING.md` EV-0007, EV-0018)."),
    ("docs/project/SOURCE-DISPOSITIONS.md", "L3-09",
     "Exact remote and upload authorization remain open. Source: docs/project/DECISION-REGISTER.md row D04.",
     "Resolved 2026-09-06: the private `bananahana720/scrapkeep` repository is the remote, default branch `main` "
     "(`TRACKING.md` Q-E07, EV-0018). Historical row retained."),
    ("docs/project/SOURCE-DISPOSITIONS.md", "L3-09",
     "Off-machine publication is still Q-E07, not completed backup.",
     "Off-machine publication was Q-E07 at this record's date; answered 2026-09-06 (`TRACKING.md` EV-0007, EV-0018)."),

    # ---- L3-10: decision register still answers D04 with a superseded option
    ("docs/project/DECISION-REGISTER.md", "L3-10",
     "Option (a). No remote publication without explicit authorization",
     "Superseded 2026-09-06 by Q-E07 / PUB-01: private remote `bananahana720/scrapkeep` authorized and verified "
     "(`TRACKING.md` EV-0018). Historical answer (a) retained"),
]

def main():
    if os.path.isdir(STAGE):
        shutil.rmtree(STAGE)
    os.makedirs(WORK)
    touched = {}
    failures = []

    for rel, fids, old, new in EDITS:
        src = os.path.join(REPO, rel)
        dst = os.path.join(WORK, rel)
        if not os.path.exists(dst):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
        text = open(dst, encoding="utf-8").read()
        n = text.count(old)
        if n != 1:
            failures.append(f"{rel} [{fids}]: expected 1 match, found {n} :: {old[:70]!r}")
            continue
        open(dst, "w", encoding="utf-8").write(text.replace(old, new, 1))
        touched.setdefault(rel, []).append(fids)

    if failures:
        print("ASSERTION FAILURES:")
        for f in failures:
            print("  -", f)
        sys.exit(1)

    # emit the combined patch with a/ b/ prefixes so `git apply -p1` works from the repo root
    patch_lines = []
    for rel in sorted(touched):
        p = subprocess.run(
            ["diff", "-u", "--label", f"a/{rel}", "--label", f"b/{rel}",
             os.path.join(REPO, rel), os.path.join(WORK, rel)],
            capture_output=True, text=True)
        if p.returncode not in (0, 1):
            print("diff failed for", rel, p.stderr)
            sys.exit(1)
        patch_lines.append(p.stdout)
    patch = "".join(patch_lines)
    open(os.path.join(STAGE, "canonical-corrections.patch"), "w", encoding="utf-8").write(patch)

    print("edited files:")
    for rel, fids in sorted(touched.items()):
        added = sum(1 for l in patch.splitlines() if l.startswith("+") and not l.startswith("+++"))
        removed = sum(1 for l in patch.splitlines() if l.startswith("-") and not l.startswith("---"))
        print(f"  {rel:52s} findings={','.join(fids)}")
    print(f"patch: {len(patch.splitlines())} lines "
          f"(+{sum(1 for l in patch.splitlines() if l.startswith('+') and not l.startswith('+++'))} "
          f"-{sum(1 for l in patch.splitlines() if l.startswith('-') and not l.startswith('---'))})")

if __name__ == "__main__":
    main()
