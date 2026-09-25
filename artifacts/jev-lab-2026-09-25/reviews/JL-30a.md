# JL-30a-A1 review (Opus 5.5, routine; verbatim)

## Verdict: PASS+NOTES for JL-30a-A1 (`reactive-model-loop`)

**Evidence level:** source review of the files on disk at the candidate, plus primary-evidence spot checks. I executed nothing.

**Identity:** `/home/andrew/Projects/scrapkeep/.git/refs/heads/wt/JL-30a` holds `85d16a5b665251abdb51789703c349f135085bab`, and the worktree HEAD points at that ref. I could not confirm a clean tree without git; the clean-tree claim comes from the coordinator receipt `forbidden-tokens.txt:1`.

**Coordinator receipts (not rerun by me):** check:docs pass with 0 failures, check:drift pass, check:scope listing 9 paths (all in the skill dir plus the link), 0 forbidden-token hits, and a crosscheck showing 43 lessons (32 provisional, 11 established) with no problems.

All notes below are non-blocking. None violates JL-30 DoD 4, and DoD 1 and 2 are met by the inventories and DESIGN.md, which this sub-attempt implements.

## Findings (all non-blocking)

1. **Missing lesson: which entities stay in the state is an instrument decision.**
   - `lessons.md:120` (RML-22) and `corpus.md:48-49` present "hide a neutralised threat from the exported state" as the fix.
   - The program later ruled that this rule fails where foes survive a hit. A 260-HP foe vanished from state after one hit and confounded 2 of 3 scenarios (inventory-2:3 correction (2)/(3), inventory-2:34, EV-0550).
   - Suggested addition, provisional: what leaves the state (dead, removed, knocked but alive) is decided per mechanic before the first batch, and changing it starts a new epoch.
   - Stop-on-death appears in the inventories only as an observation (inventory-2:66), not a lesson. If added at all, it should be a design choice.

2. **Missing trace-hash sensitivity control.** RML-41 and RML-43 (`preregistration.md:104-106`, `cadence.md:35`) treat hash equality as proof. Without a test showing the hash changes when one intent or the schedule is perturbed, a constant hash also passes. The inventory records this as a portable technique (inventory-2:28, JL-21.md:34).

3. **Cadence page: overclaims, and no path for systems that cannot pause.**
   - `cadence.md:15-16` says realtime has reproducibility "None" and replay is "Not meaningful". That overstates it: recording answer-arrival ticks as input would make replay possible (my inference). `cadence.md:26` itself says the realtime side was never measured.
   - `SKILL.md:90-92` and `cadence.md:22`: a stranger with a robot controller or other physical system cannot block the world, so as written they can never produce evidence. One line would fix this: when the world cannot pause, evidence comes from a simulator or recorded-state replay in blocking mode, and live runs are field observations.
   - Otherwise the page is a tradeoff, not a verdict (`cadence.md:3`, `SKILL.md:92`).

4. **RML-28 states a latent risk as an event** (`lessons.md:150`, `runtime.md:27`). The source, `reviews/JL-18b.md:12`, calls it a code-path risk that needs "a hand-edited or pre-JL-14 cache". Live entries always carried the model.

5. **RML-02 wording** (`lessons.md:20`, `instrument.md:24`): "survived the gate in 7 of 40 trials". The source, `reviews/JL-21.md:19`, says "7 `hit_kicker` intents in 40 random `bench-climb` trials". Intents are not trials.

6. **RML-41 is marked established but only half of it has two sources** (`lessons.md:213-215`).
   - "Record tree state" has two reviews: JL-21 F5 and JL-18b (EV-0536).
   - "A clean-commit re-run with matching hashes proves which code ran" has one instance (`JL-21.md:21`, EV-0546).
   - Split the lesson, or mark the re-run half provisional.

7. **RML-27 is worded three ways:**
   - `lessons.md:144`: "measured, computed or retracted"
   - `SKILL.md:98`: "measured, computed or simulated"
   - `preregistration.md:90-94`: V/U/R (verified, unverified, retracted)

8. **Some public or one-run claims lack an inline label.**
   - `instrument.md:41` "Four of six public projects inspected pin a bare alias" has no "unaudited" tag, although `lessons.md:35` has one. The source is also inconsistent: `prior-art-jev-games.md:45` names only three alias users, while `:64` and `:75` say four of six.
   - `SKILL.md:84` (strongest cost control seen) and `instrument.md:18` (signed bearing) are also unlabelled.
   - `SKILL.md:17` says per-option ratings "remove order effects". That generalises one run; `instrument.md:13` words it correctly as "in one lab".
   - All public-prior-art lessons are provisional (RML-01, 05, 06, 09, 22, 30, 40), so only the inline labels are missing.

9. **RML-43's 360/360** (`lessons.md:225`, `cadence.md:24`) is tagged **[receipt]** (writer-produced) in `JL-21.md:15`, not recomputed by the reviewer. The lesson states it without that qualifier.

10. **Changelog reviewer is "pending independent review"** (`lessons.md:234`). The changelog is append-only, so the coordinator should record this review's identity before the canonical commit.

11. **Boundary note, no violation.** DESIGN §3's grey-items row puts the ledger double-count "in neither skill". RML-38 uses it only as description-level evidence for a rule that DESIGN §2 section 7 requires, so no project token leaks.

## Judged points

**1. Portability: pass.**
- My own grep of the skill directory for a wider set (scrapkeep, Godot, Jolt, stage names, EV-/JL-/Q- ids, paths, npm, Andrew, Jev, Noul, Doom, Opus/Fable/Sonnet, kicker, stomp, dummy, TRACKING, BACKLOG, lease, card, /home, ~/) found only `SKILL.md:3`. That line names the `jevify` and `typesafe-ai` skills, as the DESIGN §2 frontmatter requires verbatim.
- `runtime.md:42` ("real regression") reads as generic.
- The symlink resolves: reading `.claude/skills/reactive-model-loop/SKILL.md` succeeded, and check:scope lists it as a single path (coordinator receipt).
- A router builder can use every section as written. A robot builder can use all but the cadence evidence rule (finding 3).

**2. Accuracy.** All brief-named lessons are checked (RML-05, 08, 11, 12, 17, 24, 30, 32, 36, 37, 38, 43), plus RML-02, 13, 14, 15, 22, 23, 25, 28, 29, 31, 35 and 41.

Checked against primary evidence:
- RML-08: `RESULTS.md:40,272`
- RML-17: `RESULTS.md:14,18,44` (matches the coordinator correction)
- RML-24 and RML-25: `PREREGISTRATION.md:5,154,170,184,191` and `RESULTS.md:16,48`
- RML-13: `PREREGISTRATION.md:124` and `JL-18.md:18`
- RML-14: `JL-18.md:16`
- RML-15: `JL-18.md:14`
- RML-11, RML-29, RML-30, RML-31: `JL-19.md:13,29-32,36,63`
- RML-02, RML-22, RML-23, RML-41, RML-43: `JL-21.md:9-21,41`
- RML-28: `JL-18b.md:12`
- RML-35: TRACKING (JL-coord) `:794`
- RML-38: TRACKING `:799`
- RML-36: TRACKING `:821,824`
- RML-29 probe: TRACKING `:835`

Checked against inventories only: RML-05, RML-12's last-position figures, RML-32 and RML-37.

Of the 11 established lessons, 10 are supported by two sources; RML-41 is the partial exception (finding 6). Every number carries its origin at `lessons.md:9` and in each reference intro. The only mismatches found are findings 4, 5 and 9.

**3. Usability: pass.**
- SKILL.md has 117 body lines against the 120 cap. It opens with the trigger, and its rules cite lesson ids and point to the references.
- The description excludes `jevify` and `typesafe-ai` by name.
- The pre-registration template (`preregistration.md:30-84`) can be filled in as it stands. One small gap: it has no slot to record the stub dry-run result from Phase A step 3.

**4. Ledger format: pass.** It matches DESIGN §4c exactly: id, status, since, origin, rule text, `Evidence:`, `Overturned by:`. The changelog has the §4d columns, and the statuses use only the allowed values.

**5. Gaps:**
- Labelling fallbacks on user-facing surfaces is covered (`SKILL.md:71`, `runtime.md:45`, `cadence.md:46`).
- Which entities stay in the state, and the hash sensitivity control, are missing (findings 1 and 2).

## Files
- `/home/andrew/Projects/scrapkeep-wt-JL-30a/.agents/skills/reactive-model-loop/SKILL.md`
- `/home/andrew/Projects/scrapkeep-wt-JL-30a/.agents/skills/reactive-model-loop/references/{lessons,instrument,controls,corpus,preregistration,runtime,cadence}.md`
- `/home/andrew/Projects/scrapkeep-wt-JL-30a/artifacts/local/tasks/JL-30a/` (receipts)

## Runtime
The system prompt states Opus 5.5 (`claude-opus-5-5`); that is self-description, not runtime metadata. `CLAUDE_EFFORT` was unavailable: I had no shell and it was not exposed to me.
