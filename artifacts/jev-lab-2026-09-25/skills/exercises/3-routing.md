# JL-30 exercise 3: skill routing (scrapkeep-explorer, Sonnet 5; verbatim)

Runtime model: Sonnet 5 (model ID `claude-sonnet-5`), per the explicit system-reminder in this session — not inferred.

Files read: frontmatter (`name`/`description`) of all five `SKILL.md` files under `/home/andrew/Projects/scrapkeep-wt-JL-coord/.agents/skills/*/`, plus lines 1-20 of `/home/andrew/Projects/scrapkeep-wt-JL-coord/.agents/skills/README.md`.

## Per-request routing

**A. "Plan what the lab should work on next, including whether to start a new instrument epoch."**
Tie, and worth flagging explicitly rather than picking silently.
- `scrapkeep-lab` (`.agents/skills/scrapkeep-lab/SKILL.md:3`) names the exact action: "...or start an instrument epoch." and "Use for lab, harness, scenario, arm, pin, gate or epoch work."
- `plan-session` (`.agents/skills/plan-session/SKILL.md:3`) covers the framing verb: "Plan the next Scrapkeep scope or discuss its unresolved decisions."
- The tie isn't purely descriptive guesswork — `plan-session`'s own procedure step 1 (`.agents/skills/plan-session/SKILL.md:12`) says "For lab or Jev scope, read `.agents/skills/scrapkeep-lab/references/lessons.md` and the current epoch state before proposing work," i.e., `plan-session` is designed as the entry point that then pulls in lab context. So: load `plan-session` first when the ask is framed as planning/deciding ("what should we work on"); load `scrapkeep-lab` first when the ask is already the specific epoch action itself. This request's "Plan what the lab should work on next" phrasing leans `plan-session`, but a router matching on "instrument epoch" alone would land on `scrapkeep-lab` — genuine ambiguity.

**B. "Verify this diff to scripts/lab/harness.mjs before admission."**
`scrapkeep-verify` — description: "Verify a Scrapkeep artifact or change using its documented checks and evidence limits. Use for game verification, regression checks..." (`.agents/skills/scrapkeep-verify/SKILL.md:3`). Confirmed by `scrapkeep-lab`'s own disclaimer: "verification rows stay in scrapkeep-verify and admission in scrapkeep-task" (`.agents/skills/scrapkeep-lab/SKILL.md:3`) — the harness file lives under lab scope but the requested action (verify) is explicitly routed elsewhere by the lab skill itself.

**C. "Bring the headless lab to a new stage sketch whose enemies have HP."**
`scrapkeep-lab` — description literally contains "...or bring the lab to a new stage." (`.agents/skills/scrapkeep-lab/SKILL.md:3`). Clean, unambiguous match.

**D. "We're adding a fast model to route support tickets every few seconds; how do we know its choices are trustworthy?"**
`reactive-model-loop` — description: "Design, control, evaluate, cache and cost a fast model that makes reaction-based decisions inside a running system (a game tick, a triage step, a router)." (`.agents/skills/reactive-model-loop/SKILL.md:3`). "route support tickets every few seconds" = "a router" on the hot path; "how do we know its choices are trustworthy" = "evaluate." Also confirmed portable/non-Scrapkeep-specific by the README: "design and evaluate a fast model that decides inside a running system" (`README.md:11`), so it correctly fits a non-game routing use case.

**E. "Implement the approved card JL-28."**
`scrapkeep-task` — description: "Execute an authorized Scrapkeep task card with isolated work, independent review and serial admission. Use when asked to implement or continue an approved Scrapkeep card or bounded scope." (`.agents/skills/scrapkeep-task/SKILL.md:3`). Exact match on "approved" + "card."

## Wording that could misroute

- `plan-session`'s trigger phrase "what should we decide" (`.agents/skills/plan-session/SKILL.md:3`) is generic enough to pull in requests that are actually lab-epoch or verify-scope decisions, not just open planning — this is the direct cause of the A tie.
- `scrapkeep-lab`'s description lists "gate" and "read a gate exit" (`.agents/skills/scrapkeep-lab/SKILL.md:3`) alongside `scrapkeep-verify`'s "regression checks" (`.agents/skills/scrapkeep-verify/SKILL.md:3`) — a router matching only on "gate" could load `scrapkeep-lab` for what's actually a verification-read task, even though the two skills otherwise cross-reference to disambiguate.
- `reactive-model-loop` proactively excludes look-alikes ("Not for choosing where a model could help (jevify) or for the TypeSafe API (typesafe-ai)," `.agents/skills/reactive-model-loop/SKILL.md:3`) — this is the one skill that guards against its own misrouting in the description itself; the other four don't carry equivalent exclusions.
