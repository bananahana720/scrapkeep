---
name: fun-gate-before-alpha
description: "Don't call a Scrapkeep build alpha-ready on tests, stills and coherence reviews; the loop must pass a measurable \"map matters\" check first (2026-09-28)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: f0249c87-50b2-4937-b0b8-78f0fe66d1ba
  modified: 2026-09-28T10:30:25.961Z
---

Playtest entry 8 (2026-09-28): I handed Andrew core-loop v2 as "ready to play" for the alpha after 171 green tests, rendered stills and a vision-coherence review. He won the whole demo in about 10 minutes by beelining to each Warden, with 0 deaths and 0 events. He called it "a half-baked attempt" that isn't close to alpha.

The balance bots had already shown it. The skipper policy cleared every stage with no deaths, and the completionist was only 1.6 to 2.9 times faster. Eight tuning passes moved the numbers but never the structure.

**Why:** tests prove behaviour, stills prove looks and a coherence review proves consistency. None of them measures whether the loop is engaging, and a skipper bot that wins is a structural red flag, not a tuning note.

**How to apply:**
- Before calling any Scrapkeep build alpha or playable-for-verdict, check the loop against measurable engagement criteria: the skipper loses or pays a steep cost, the completionist has a clear advantage band, the share of time off the fall line, and the Warden's legible windows.
- When a bot or metric says the structure is off, escalate it to Andrew as a design question instead of tuning around it.
- Frame hand-offs as "ready for your verdict on X", not "alpha ready".

Related: [[scrapkeep-design-principles]], [[natural-progression-storyboard-gate]].
