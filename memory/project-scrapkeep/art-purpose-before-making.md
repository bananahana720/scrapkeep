---
name: art-purpose-before-making
description: "Andrew 2026-10-21 — for all digital art and modeling, agents state why a thing exists and why it will work before making it, never guess, and log every caught mistake in project-guide/handoff/ART-MISTAKES.md"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 99053a69-80bd-4be5-8d1c-7c0c8c13e9bc
  modified: 2026-10-22T02:27:50.474Z
---

Andrew's rule (21 Oct 2026, typed): for digital art and modeling (models, textures, lighting, grading, animation, effects, props), Claude agents must think through why something exists and why it will work before making anything. No guessing: research first. Record every mistake so it isn't repeated.

The record is DECISIONS.md section 10. The log is `project-guide/handoff/ART-MISTAKES.md`: append only, one line per mistake with date, lane, PR, mistake, root cause and preventing rule. Each unit reads it first, and its PR names the entries it checked.

**Why:** art agents were making things on assumption and repeating the same errors across units and lanes.

**How to apply:**
- Every art brief carries the three clauses: a purpose note in the plan and the PR body, cited numbers and styles, and the mistakes log.
- Reviewers fail an art PR that has no purpose note or cites no evidence.
- The coordinator logs its own process mistakes there too. Seeded with six from 21 Oct.

**Reference before making (22 Oct 2026, typed).** Andrew approved the 71 Codex concept boards as the shared point of reference for every asset class, big or small. They live in `docs/art/reference/` (one folder per set, index with purpose notes; main 373f609e, #282). Every art unit cites its board and says how it matches. No board for a class means generate one first: Codex/Astra, matched to the eight style boards in `docs/art/reference/style/`, then build. Effort scales with scope. Families (a park, a mob set, a boss, an event set) get one set brief with members, the shared board, shared rules and lane ownership, so several agents build one family. Reviewers compare side by side, and a drift is a FAIL. Boards settle look only. His worry is consistency across lanes, not the quality of the boards themselves.

**Boards grounded in gameplay (22 Oct 2026).** Every gameplay idea a board suggests (UI, mechanics, mobs, neutral AI, landforms, map flow, cycles) must trace to the game or the roadmap. The record is `docs/art/reference/GROUNDING.md` (#288); conflicts mean don't copy, ungrounded ideas need a ROADMAP "Board grounding cards" row or are cut. New boards get grounded the same way before lanes build from them (the grounding workflow script is reusable: ground-mood-boards in the session's workflows folder).

Related: [[alpha-coordinator-handoff]], [[scrapkeep-design-principles]], [[creative-charge-alpha]].
