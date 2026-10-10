# Jev and TypeSafe ecosystem scan, 10 October 2026

Web research only. Nothing here was run against the live API; every number is the cited source's own claim. Scrapkeep's own Jev evidence is in [the Jev Lab retro](../../artifacts/jev-lab-2026-09-25/RETRO.md) and [the jev-player README](../../tools/jev-player/README.md).

## Where Scrapkeep stands

- Jev-as-player is parked (TRACKING EV-0527, EV-0540, EV-0541). It failed the free-cache dominance control in every order and method tried, 216 calls in the pre-registered redesign. The lethal-option control passed every time.
- Jev keeps four advisory test-loop roles (JL-19, JL-20, JL-23, JL-24). `tools/jev-player/decide.mjs` calls `https://api.typesafe.ai/v1/systemone` with raw fetch, model `jev-latest`, key from `~/.config/typesafe/.env`. No `@typesafe-ai/sdk` dependency.
- The installed `typesafe-ai` Claude plugin is 0.5.7 (skill only, no MCP).

## What changed upstream since the lab closed (26 September)

| Item | State on 2026-10-10 | Source |
| --- | --- | --- |
| Model | Still `jev-1.13.0`, the launch build. `jev-latest` and `jev-preview` both point at it. No point release, no model changelog. | [jevreport](https://jevreport.com/posts/what-changed-in-the-latest-jev-release) |
| JS SDK | 0.6.0 since 2026-09-15. Python SDK moved to 0.7.0 (Pydantic, `response_model`). | [JS changelog](https://docs.typesafe.ai/sdk/javascript/changelog.md) |
| Primitives | Choice (up to 255 options), Score (2 to 10 levels), Noul (0 to 1). Unchanged. No streaming, caching or fine-tuning in the docs index. | [llms.txt](https://docs.typesafe.ai/llms.txt) |
| New docs page | "Jev 1.13 jaggedness" lists documented failure modes: literal reading, arithmetic, counting, numeric encodings, weakly calibrated Score levels, dates, double negatives, large or irrelevant state, first-option bias, adversarial content. | [jaggedness](https://docs.typesafe.ai/model-jaggedness/jev-1.13.md) |
| Signup | Open to all 2026-09-20 with $5 credit, paused 2026-09-22 under demand. Gateways (OpenRouter `typesafe/jev-1.13`, Vercel AI Gateway, Netlify, DigitalOcean, Cloudflare AI Gateway) carry it without a waitlist at the same $0.042 per million input tokens. Rate limit 250k tokens and 200 requests. | [jevreport](https://jevreport.com/posts/what-changed-in-the-latest-jev-release), [Vercel](https://vercel.com/changelog/typesafe-ai-jev-now-available-on-ai-gateway) |
| Official coding-agent stance | TypeSafe ships only the agent skill. No official MCP server or hooks. | [coding agents](https://docs.typesafe.ai/introduction/coding-agents.md) |
| Competitor | OpenAI now has a "Decisions API" with the same shape; one repo benchmarks it against Jev as RPG NPCs. | [komzweb/jev-vs-decisions-rpg](https://github.com/komzweb/jev-vs-decisions-rpg) |

The jaggedness page is the most useful upstream change for this repo. It documents exactly the class of question the lab's free-cache control asked (compare two numeric outcomes, prefer the dominant one) as a known weak spot. The lab's park was a correct read of the model, not a harness bug.

## Independent evidence worth knowing

- **JEV-as-a-Judge (arXiv 2609.26550).** Jev within about 1 point of GPT-6 on RewardBench and HaluEval, 14.6 points behind on JudgeBench (reasoning and code), 20 points behind on style-adversarial pairs. Median latency 0.152 s and $0.044 per 1,000 judgments, about 277 times cheaper than GPT-6. Accept when max probability is at or above a threshold, escalate otherwise: at τ = 0.9 the cascade accepted 53.7% of pairs at 57% of the GPT-6 fee with a 0.6 point accuracy cost. Thresholds did not transfer between workloads.
- **Calibration audits.** Near calibrated on public sets, overconfident on unseen rules and contested items (bias-corrected ECE gap 0.264 on disagreed items). Fit thresholds on your own labeled data, about 100 rows minimum ([jevcal](https://github.com/abhixhek/jevcal)). First-option bias confirmed; swap orders.
- **Negative results that matter here.** Jev-judged context pruning dropped information needed later ([pi-jev-context], shadow-only). ORDER BY over Jev probabilities failed four of six human-graded ranking conditions ([jev-orderby-bench](https://github.com/yodablocks/jev-orderby-bench)). A dice-roll calibration check put 82.9% on face 1 at 19% accuracy ([jev-does-not-play-dice](https://github.com/KantaHayashiAI/jev-does-not-play-dice)): numeric probability is not Jev's domain.
- **Survey.** 2,170 public GitHub Jev projects by late September ([Jev in the Wild](https://arxiv.org/abs/2609.30216)); 981 catalogued at [heyjunpenn/awesome-jev](https://github.com/heyjunpenn/awesome-jev).

## The dev-tool landscape, grouped by what it would do for this repo

### A. Claude Code hooks that gate "done" and tool calls

Dozens exist; none official. The most measured:

- [toolgate](https://github.com/RiskAverseTech/toolgate), PreToolUse firewall. Author's window: 1,369 decisions, 21% asked, blind review of 150 allows found no permissive miss.
- [jev-engineering](https://github.com/eugeniughelbur/jev-engineering), deterministic rules then one Jev call. Adversarial kit: 0 of 30 dangerous commands slipped, 10% false denials on safe ones.
- [jev-belay](https://github.com/valentynkit/jev-belay), [claude-referee](https://github.com/ismaildasci/claude-referee), [limpet](https://github.com/noplan-inc/limpet): Stop hooks that check a "done" claim against transcript evidence and send the agent back. Fail open.
- [Canny](https://github.com/qkal/Canny): logs edits and flags done claims with no passing check.

Fit for Scrapkeep: the A stack verdict ladder already demands evidence levels. A Stop hook that asks Jev "does this final reply cite a command receipt for each PASS it claims" is the same check mechanised. The jaggedness page says keep it literal: one claim, one receipt, one yes/no Noul.

### B. Spec and rule drift against docs

- [jevmcp](https://github.com/eaisdevelopment/jevmcp) (Apache-2.0, v1.7.8 on 2026-10-07): `spec-drift` pairs each requirement sentence with its implementing code through a `spec_map.json` and asks a fixed-option Choice with a "cannot tell" option, deciding only when three readings agree above 0.85. `code-audit` screens code against rules approved from CLAUDE.md, AGENTS.md or CONTRIBUTING. `ci-triage` reads a failed run. Author's costs: $0.0013 per spec check after editing two files.
- [prose-check](https://github.com/vgeshel/prose-check): checks the agent's final reply against the project's writing rules.

Fit: Scrapkeep's `check:drift` is hash agreement only, by design. BIBLE, ADR, AGENTS.md and the lightning contract carry semantic rules that only review enforces today (state in `simulation.js`, rendering in `scene.js`, "damage and telegraphs consume the same committed geometry"). A rule map over AGENTS.md's bullets plus the orchard contract is the cheapest new check this repo could add, and jevmcp's design keeps whole files out of the request.

### C. Model and effort routing for Claude Code

[jev-router](https://github.com/dominicrico/jev-router), [claude-router](https://github.com/alexei-led/claude-router), [jev-opus](https://github.com/WXK-AI/jev-opus), [automodel](https://github.com/moukrea/automodel), [jev-pilot](https://github.com/sunu-dev/jev-pilot), and about ten more, all under 20 stars. The A stack already has `agent-router` (Jev-graded tier). Nothing here adds to it; the project pins forbid runtime model switching anyway.

### D. Local, keyless decision models

- [ollaya](https://github.com/ollaya-dev/ollaya) (Apache-2.0, 1,283 stars): serves Laya, Qwen3.5 deciders, NLI and GLiClass behind a wire-identical `/v1/systemone`. Point the SDK or `decide.mjs` at `http://localhost:11435`. Laya 421M answers in a fraction of a second on CPU; `winnow:e4b` scores 0.722 vs hosted Jev 0.738 on their typed-decision suite, GPU needed.
- [SemIf-OpenJev](https://github.com/TheoLeeCJ/SemIf-OpenJev) (4,772 stars), [von](https://github.com/wfzyx/von), [Kev](https://github.com/jaredpalmer/kev), [jeff](https://github.com/logan-markewich/jeff): open re-implementations, each weaker than Jev on reasoning-heavy items.

Fit: the lab's call caps, preflight and signup pause all came from the API being metered and gated. A local endpoint behind the same protocol removes those limits for test-loop roles and lets the harness run in CI with no key. The protocol (`scrapkeep-jev/1`) and `decide.mjs` need only a base URL.

### E. Game AI, the direct comparison

- [reflex-godot](https://github.com/gbesse/reflex-godot) (MIT, alpha, Godot 4.7.2): guarded finite NPC decisions. Runtime lists only legal actions, Jev picks, `apply` rechecks legality and revision, a journal replay verifies state. Live Jev inference untested by the author. Same shape as `jev_io.gd` and `PRECONDITION` in `decide.mjs`; nothing to borrow except the replay-verify idea, which the lab's `trace_hash` already covers.
- [jev-plays-pokemon-red](https://github.com/valentynkit/jev-plays-pokemon-red): scores faint predictions by Brier against emulator RAM. Jev Minecraft, StarCraft, Mario, Snake, HEIST//ONE: all code-enumerates options and Jev picks among semantically labelled ones.
- [komzweb/jev-vs-decisions-rpg](https://github.com/komzweb/jev-vs-decisions-rpg): 240 battles, Jev vs OpenAI Decisions, simulation-scored with calibration.
- Playtesting, balancing, Godot beyond reflex-godot: nothing found.

Fit: confirms the lab's conclusion. Where Jev succeeds in games the options are few and carry words, not numbers. Scrapkeep's unresolved question is whether a player can judge a numeric trade-off, and the ecosystem has not answered it either.

## Ranked recommendations

1. **Rule-drift check over AGENTS.md and the orchard contract (B).** Smallest new capability with a real gap behind it. Build it on `tools/jev-player/decide.mjs`'s existing client, not jevmcp as a dependency: one Noul per (rule, changed hunk) pair, "cannot tell" never passes, advisory in `npm run verify`, off when no key. Score it first on the repo's own review history: pull five past review findings that cite a rule, plus five clean diffs, as the labeled corpus.
2. **Local endpoint for the advisory roles (D).** Add `TYPESAFE_BASE_URL` to `decide.mjs`, run ollaya with `laya:en` on CPU, and rerun the four advisory roles' existing corpora against it. If Laya holds the blind-corpus score (0.913 weighted under q2), the test loop loses its call cap and key dependency. If it does not, that is a one-afternoon negative result worth recording.
3. **Evidence Stop hook (A).** Belongs in the A stack plugin, not this repo. Park here; note it in the astack backlog.
4. **Do not revisit Jev-as-player.** The jaggedness page and the dice study close the question the lab opened. Revisit only on a new model version, which has not shipped.
5. **Skip routing tools (C).** Already covered by `agent-router` and forbidden by project pins.

## Open questions this scan did not settle

- Whether the signup pause still blocks new keys; Andrew's existing key predates it.
- Laya's accuracy on Scrapkeep's own corpora; the 0.722 figure is on ollaya's suite.
- jevmcp's three-reading agreement rule at 0.85: no independent eval found.
