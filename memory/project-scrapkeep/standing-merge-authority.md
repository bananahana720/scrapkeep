---
name: standing-merge-authority
description: "Andrew restated 2026-10-18 (first given 17 Oct 19:41Z): merge gate-passed PRs into the stage, merge the stage PR to main, push stage/cand/scratch branches, git housekeeping, without asking"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 4a2277c3-040b-4307-a006-0aaff95dc0a3
  modified: 2026-10-18T20:53:55.468Z
---

Andrew restated his standing authority in the local coordinator session on 2026-10-18 (structured answer "Yes, all of it"): merge gate-passed PRs into `stage/alpha-w<N>`, merge the stage PR into main, push `stage/*`, `cand/*` and `scratch/*`, and do git housekeeping, without asking. It continues the 17 Oct 19:41Z authority from the old project.

**Why:** high velocity; per-merge asks were the slowest step in the old project.

**How to apply:** promote on a clean full gate plus red team persona on the exact stage head; report promotions in the check-in summary, not as asks. Force-push, history rewrites and waiving a proof still need his typed words. His typed line on 2026-10-18 in the local coordinator session: "you may merge gatepass PRs to stage and main. You have full authority for that." The auto-mode classifier refused a merge on the structured answer alone ([Self-Approval]) and accepted it after this typed line; cite it when a check wants his words. Related: [[alpha-coordinator-handoff]], [[creative-charge-alpha]].
