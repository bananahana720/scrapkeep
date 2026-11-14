---
name: mid-flight-direction-harmonize
description: "When Andrew adds direction while writers are running, don't restart them; resume each one after hand-back to consolidate and harmonize the new input with what it built"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 843df1db-1f22-408a-875e-e5c6e3efae36
  modified: 2026-09-27T18:09:08.009Z
---

On 2026-09-27, during the core-loop v2 round, Andrew kept adding direction (contraptions, reinforcements, lore) while four writers were already running. He said: "If agents have started, then I feel like they're still learning what they've created, and they can just um, remediate coalesce and consolidate and, and harmonize with whatever they have and whatever we're giving them."

**Why:** He works generatively and adds ideas in bursts. Restarting agents throws away what they learned about their own code, and the new input usually refines the work rather than invalidating it.

**How to apply:**
- Record each new direction in the spec (`DESIGN-V2.md` or its successor) right away.
- Let the running writers finish.
- On each hand-back, resume the same agent (SendMessage to its id) with a short delta: the new spec sections that touch its files, and the instruction to harmonize with what it built rather than rebuild.
- Only stop a writer if the new direction makes its current work wrong, not merely incomplete.

Related: [[scrapkeep-design-principles]].
