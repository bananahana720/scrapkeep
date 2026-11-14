---
name: ops-ownership
description: "2026-11-10: Andrew gave the coordinator ownership of Scrapkeep's infrastructure, tools and ops; change them as judged best, report after"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 1e69038b-db24-4bab-b00e-3960de210913
  modified: 2026-11-10T20:43:26.911Z
---

Andrew, 10 Nov 2026, twice in one session. At the start: "This codebase is yours: what it's for and how it's built are your call, and you'll keep building on it." Mid wave 34 gate, after the gate runner fixes: "Keep it up and exercise codebase ownership by changing infrastructure or tools or ops as you see best for this games development."

**Why:** he wants the gate, test tooling and session workflow shaped by whoever runs them, without a question per change. He had just watched the first PC gate lose hours to defaults sized for 4-core cloud boxes.

**How to apply:** change gate scripts, lane plans, test tooling, docs of record and session ops when evidence from a run points at them; put the change in the repo (not only in `~/scratch`), prove it with a test that can fail, log the call on the board or in DECISIONS, and tell him what changed in one line. My reading of the scope: it widens [[creative-charge-alpha]] from game calls to infrastructure. It does not change the standing limits: deleting anything, force-pushes, paid services, deployment and his save data still need his go-ahead. Related: [[fast-focused-tests-cloud-cpu]], [[standing-merge-authority]].
