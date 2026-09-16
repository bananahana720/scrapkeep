# AM-H8-003 advisory result

Run through codex:codex-rescue with --model gpt-6-astra --effort high, read-only. Codex session 01a0abb9-5156-7273-a586-6990bfcc1382; its rollout log ~/.codex/sessions/2026/09/16/rollout-2026-09-16T12-37-24-01a0abb9-5156-7273-a586-6990bfcc1382.jsonl records model gpt-6-astra and reasoning effort high (read by the coordinator). Result retained verbatim from the forwarder's transcript.

**Classification: (b), architecture choice.** I recommend that all four kit actions reference N-021 ability definitions, which may commit F-02 attacks. However, the named admitted sources do not establish that reference chain conclusively enough to classify the change as factual alignment. Andrew should choose it before the coordinator folds it into FR-07.

This classification is my inference from the evidence below. I inspected `main` at `6d01b34df4c79a70e2a725a892560fa09721b9cd`, identified with `git branch --show-current` and `git rev-parse HEAD`. All commands were read-only; no files were written, no builds ran, and no write flag was passed.

### 1. Why this remains a choice

The distinction is between **an action's runtime behavior** and **the family its authored kit reference must name**. TH-04 establishes the former without explicitly replacing HF-06a's latter rule.

| Observed evidence | What it establishes |
|---|---|
| HF-06a line 36 makes sibling references part of the rationale. F-01 at line 66 explicitly references kit actions as F-02 "by ID and expected family." N-007 at line 80 repeats that assignment; N-008 and N-009 at lines 81–82 inherit its reference shape. N-019 at line 92 explicitly makes mobility actions F-02 definitions. | The F-02 assignment is an admitted reference constraint. [HF-06a:36](/home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06a-schema-inventory.md:36), [66](/home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06a-schema-inventory.md:66), [80–84](/home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06a-schema-inventory.md:80), [92](/home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06a-schema-inventory.md:92). |
| HF-06a N-021 at line 94 separately provides ability and ultimate definitions with availability, cooldown, charge-source and effect references. | A separate ability definition already exists, but this row does not say that every kit action references it. [HF-06a:94](/home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06a-schema-inventory.md:94). |
| TH-04 AS-01 through AS-04 distinguish weapon commitments, skill interaction, mobility, and ultimate. AS-03 specifically assigns mobility's movement contract to TH-02 and its availability, cooldown and lifetime to TH-04. AI-25 resolves slot, node, ability, ultimate and device definitions. | Strong support for separating action behavior from attack geometry, but no explicit kit-field expected family. [TH-04:39–42](/home/andrew/Projects/scrapkeep/docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md:39), [150](/home/andrew/Projects/scrapkeep/docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md:150). |
| TH-04 EL-04 governs an effect's own attacks. Seam 1 says an activation **that produces an attack** obeys TH-03 and fixes what surrounds that commitment. | Supports an ability producing an attack, but not whether the kit directly references the ability, an attack linked to the ability, or another arrangement. [TH-04:114](/home/andrew/Projects/scrapkeep/docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md:114), [313](/home/andrew/Projects/scrapkeep/docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md:313). |
| TH-03, TH-07, TH-08, HF-06b, HF-07a | None supplies the missing rule that every kit action must reference `ability`. [TH-03:241, 265](/home/andrew/Projects/scrapkeep/docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md:241), [TH-07:358–362](/home/andrew/Projects/scrapkeep/docs/tech/sections/TH-07-four-slots-and-milestone-progression.md:358), [TH-08:308](/home/andrew/Projects/scrapkeep/docs/tech/sections/TH-08-inventory-equipment-and-transformations.md:308), [HF-06b:112, 139](/home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06b-persistence-projection.md:112), [HF-07a:126–130](/home/andrew/Projects/scrapkeep/docs/tech/sections/HF-07a-save-envelope.md:126). |

No observed line explicitly contradicts this classification by settling the direct reference family in favor of `ability`. HF-06a lines 66, 80 and 92 directly contradict adopting that family **without an amendment**. The SC-02 candidate makes this reference-family choice explicitly (`AbilityDefinition` for all four roles, kit → ability), but that is a candidate decision, not evidence of prior acceptance — and its FR-11 still assigns mobility to `AttackDefinition`, needing its own internal correction. [SC-02:269–277, 373, 508](/home/andrew/Projects/scrapkeep-wt-SC-02/docs/tech/schemas/SC-02.md:269).

### 2. The two options

| Option | Player-facing consequence | Production consequence |
|---|---|---|
| **Ability first — recommended** | Preserves positioning/traversal without requiring a damage threat; attacks still follow the same readable geometry contract. | One reference family for all four kit slots; cooldowns/charge/lifetime stay separate from attack geometry. Requires coordinated amendments across HF-06a, SC-01/SC-02. |
| **Attack first** | Movement-only actions need an explicit non-damaging case within the attack family. | Preserves HF-06a's direct references but requires defining a non-attacking case inside a contract whose stated fields include danger geometry, targets, telegraph and recovery. [HF-06a:67](/home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06a-schema-inventory.md:67), [TH-03:52–60](/home/andrew/Projects/scrapkeep/docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md:52). |

Recommended decision wording: a character's weapon, main hero skill, mobility and ultimate kit actions reference N-021 ability definitions by ID and expected family `ability`; an ability references F-02 attack definitions for any attacks it produces; a mobility action may produce no attack; every produced attack remains subject to TH-03.

Because classification is **(b)**, the request's conditional item 2 (factual-alignment replacement cells) does not apply.

### 3. Additional contradictions

One additional HF-06a row is affected beyond the request's list: **N-016** says transformative replacement of "movement or attacks" references F-02 — an ability-first amendment must distinguish replacing a mobility action from replacing an attack, in both Markdown and CSV. [HF-06a:89](/home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06a-schema-inventory.md:89) / [CSV:25](/home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06a-schema-inventory.csv:25).

Two clauses need careful (not blanket) treatment: **HF-06b N-009** (planted-limb actions → F-02/AttackLedger) needs clarification of whether it covers the whole mobility action or just an attack it produces — N-011's beam rules can still remain F-02. **HF-06a N-013** (weapon silhouette → F-02) — the amendment should distinguish the slot action's visual reference from an attack-specific one. No additional contradiction was found in TH-03, TH-04, TH-07, TH-08, or HF-07a; **no HF-07a save-field change follows** from this choice.

A read-only comparison confirmed all inspected HF-06a/HF-06b rationale cells match their CSV copies — the contradiction exists in both representations.

### 4. Actual model and reasoning effort reported by the run

The Codex run itself reported: **"Actual runtime model identifier: not exposed. Actual reasoning effort: not exposed."** It found no `OPENAI_MODEL`/`CODEX_MODEL`/`CODEX_REASONING_EFFORT` etc. environment variables set, and stated it could not confirm from runtime evidence that the requested `gpt-6-astra`/high pair was what actually executed — only that the session identifies itself broadly as GPT‑6-based. This is a runtime-transparency gap in the tool's self-report, not a claim of confirmed model/effort.