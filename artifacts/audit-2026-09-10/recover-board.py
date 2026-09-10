#!/usr/bin/env python3
"""Recovery board edits: record the coordination transfer, the HF-05 handoff that the
cut-off session never recorded, and the fresh review assignment.

Every replacement asserts exactly one match; a mismatch aborts before writing.
Run from the repo root. This is coordinator-owned board work (ORCHESTRATOR.md).
"""
import sys

P = "TRACKING.md"
text = open(P, encoding="utf-8").read()
edits = []

EV93 = ("| EV-0093 | 2026-09-10T16:42:05+00:00 | Coordinator / ownership recovery | (record) | "
        "Coordination transfer after the cut-off session, authorized by Andrew on 2026-09-10. No writer or "
        "coordinator process survives (process and /proc cwd scan). Reconciled event sequence EV-0001..EV-0092 "
        "is contiguous with no gaps or duplicates; the final board write (EV-0090..EV-0092 plus the HF-04a row "
        "and two attempt records) was uncommitted and is admitted by this transfer. Recorded substitution: "
        "TRACKING.md:15 names `/root/foundation_coordinator` at gpt-6-astra xhigh while the active host map "
        "selects high, and this session cannot verify its own runtime model from inside; the pair is reported "
        "as unverified rather than silently chosen. No lease state is changed by this event. |")

EV94 = ("| EV-0094 | 2026-09-10T16:42:05+00:00 | Coordinator / handoff | HF-05 | "
        "HF-05-A1/L1 writer stopped; the delivered candidate was never recorded before the cut-off. Candidate "
        "ea522c3eac2cb12c44d9918910a3ec0b10a604c0 (branch wt/HF-05, base 7a73c5b5f44806c83924661b054051818174f07e); "
        "delivered section docs/tech/sections/HF-05-content-admission.md, 202 lines, blob "
        "8ceb841d535cc78a94d1b9024d93bc544c91028f, sha256 "
        "7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6. Retained receipts: "
        "artifacts/foundation-sprint-2026-09/tasks/HF-05/attempt-1/ (21 files, byte-identical to the worktree "
        "evidence and to the pre-cleanup audit archive). Final paper/source receipt 126 checks PASS; "
        "docs/project and scope checks exit 0; handoff records stopped_writer true. HF-05-L1 closed. Row set to "
        "review at record revision 5. Correction: EV-0092's count of 118 has no supporting artifact. |")

EV95 = ("| EV-0095 | 2026-09-10T16:42:05+00:00 | Coordinator / assignment | HF-04a, HF-05 | "
        "One fresh independent reviewer assigned to the disjoint wave: HF-04a candidate 72178cf "
        "(section sha256 7eb7ad2c909b715e62051d2d73e353f445b96270f3140b38c1c38c4c3fc171fb) and HF-05 candidate "
        "ea522c3 (section sha256 7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6), per the "
        "wave-review rule. The reviewer wrote neither candidate and holds no write lease. Review scope includes "
        "each card's acceptance, Bible/ADR boundaries, and the reproduction hazard where run_checks.py rewrites "
        "handoff.json from the passed repository HEAD, so retained attempt-1 receipts are immutable evidence. "
        "Neither candidate may be integrated before an independent PASS; HF-04b and HF-06a stay locked on done. |")

edits.append((
    "| [HF-05](BACKLOG.md#hf-05) | 2 | 4 | in_progress | none | none | EV-0089 |",
    "| [HF-05](BACKLOG.md#hf-05) | 2 | 5 | review | none | none | EV-0094 |",
))

edits.append((
    "\n\n## Preparation checkpoint",
    "\n" + EV93 + "\n" + EV94 + "\n" + EV95 + "\n\n## Preparation checkpoint",
))

# --- HF-05 attempt record: reconcile with the delivered candidate
edits.append((
    "- Assignee: /root/foundation_trigger_review, gpt-6-astra high requested; card revision 2; attempt HF-05-A1; exclusive lease HF-05-L1 active.",
    "- Assignee: /root/foundation_trigger_review, gpt-6-astra high requested; card revision 2; attempt HF-05-A1; "
    "exclusive lease HF-05-L1 closed, writer stopped.",
))
edits.append((
    "- Candidate identity: null. Integrated identity: null.\n"
    "- Latest checkpoint: 2026-09-06T22:56:27.951198+00:00; actual draft/state traces inspected; final prefix/locked-slot refinement and candidate checks next.",
    "- Candidate identity: `ea522c3eac2cb12c44d9918910a3ec0b10a604c0`. Integrated identity: null.\n"
    "- Latest checkpoint: handoff recorded at EV-0094; candidate committed, final paper/source receipt 126 checks PASS, "
    "docs/project and scope checks clean, writer stopped; independent review pending.",
))
edits.append((
    "- Evidence: [assignment packet](artifacts/foundation-sprint-2026-09/tasks/HF-05/assignment.md).\n- Review: not_run.",
    "- Evidence: [assignment packet](artifacts/foundation-sprint-2026-09/tasks/HF-05/assignment.md); "
    "[attempt-1 receipts](artifacts/foundation-sprint-2026-09/tasks/HF-05/attempt-1/handoff.json).\n"
    "- Review: fresh independent wave review pending (EV-0095).",
))

# --- summary block: advance to the reconciled sequence and repair the glued text
edits.append((
    "Last reported event: EV-0092. Latest admitted checkpoint: 3/14 done (HF-01, HF-02, HF-03a). "
    "HF-04a is in review (handoff recorded at EV-0091); HF-05 was delivered but its handoff is not yet recorded. "
    "Since EV-0077: full scope authorized, HF04b factual revision2 admitted, HF03a admitted; HF04a/HF05/HF03b input-ready. "
    "Compute counts from the task index on every poke. Only admitted DONE states count; candidate work does not. "
    "Session execution and manual pokes only.",
    "Last reported event: EV-0095. Latest admitted checkpoint: 3/14 done (HF-01, HF-02, HF-03a). "
    "HF-04a (EV-0091) and HF-05 (EV-0094) are both in review; one fresh independent reviewer is assigned to the "
    "disjoint wave at EV-0095. Since EV-0077: full scope authorized, HF-04b factual revision 2 admitted, "
    "HF-03a admitted; HF-03b remains input-ready. Compute counts from the task index on every poke. Only admitted "
    "DONE states count; candidate work does not. Session execution and manual pokes only.",
))

fails = []
for old, new in edits:
    n = text.count(old)
    if n != 1:
        fails.append(f"expected 1 match, found {n}: {old[:90]!r}")
        continue
    text = text.replace(old, new, 1)

if fails:
    print("ASSERTION FAILURES:")
    for f in fails:
        print("  -", f)
    sys.exit(1)

open(P, "w", encoding="utf-8").write(text)
print(f"applied {len(edits)} board edits")
