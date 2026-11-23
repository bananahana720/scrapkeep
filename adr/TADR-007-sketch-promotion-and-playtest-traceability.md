# TADR-007. Sketch promotion and playtest traceability

Status: **Accepted engineering direction.** Andrew authorized recording D5, the coordinator's recommendation, on 26 September 2026 ([TRACKING](../TRACKING.md) EV-0579). The criteria, the record shape and the checks below are this ADR's statement of that direction. The tooling they need is future cards. This is not authorization to build.

Date: 26 September 2026. Depends on [TADR-003](TADR-003-content-pipeline.md) and [TADR-006](TADR-006-physics-authority-and-verification.md). Written under [DF-01](../BACKLOG.md#df-01) revision 1.

## Context

The [light play lane](../ORCHESTRATOR.md#light-play-lane) runs throwaway Godot sketches under `sketches/<name>/`. Andrew plays each sketch, his verdict goes to the playtest log, the coordinator appends a line to `verdicts.ndjson`, and the branch merges (`ORCHESTRATOR.md:114`). Sketches are not proofs. Their checks qualify nothing, and promotion into `native/`, `/`, `/orchard.html`, the Bible or an ADR is a heavy-lane decision (`:116`). TRACKING receives an event when a sketch is promoted (`:114`). Nothing yet says what a promotion requires or what it carries.

Play has already kept several mechanics. Entry 3 keeps grapple, glide and slam, then the air dash (entry 3 (`../docs/playtests/PLAYTEST-LOG.md`), `PLAYTEST-LOG.md:67`, `:73`). Entry 4 keeps environmental events as a core stage mechanic (entry 4 (`../docs/playtests/PLAYTEST-LOG.md`), `:57`). TADR-006 records rigid physics. Entry 3 also asks for reworks rather than keeps: the reel, a pylon mount replacing mag-cling, and a slam anchor (`:69-71`). The Bible already disagrees with play in places. `BIBLE.md:519` still describes compact levels (`PLAYTEST-LOG.md:37`), and [DF-04](../BACKLOG.md#df-04) exists to harmonize it.

The verdict chain has three links. `docs/playtests/PLAYTEST-LOG.md` holds the prose. `docs/playtests/verdicts.ndjson` holds one line per entry with `entry`, `build_sha`, `anchor`, `quote` and `tags`. `scripts/lab/verdicts.mjs:95-190` checks each field against that entry's own log section and confirms that `build_sha` is a commit, and `npm test` fails until it passes (`ORCHESTRATOR.md:114`). No link records tuning.

In the sketches, tuning is data. `sketches/mobility-kit/src/tuning.gd:5-22` is one table of sixteen knobs with defaults, bounds and steps, and `:24-35` holds constants outside the panel. The F1 panel changes values in memory only (`tuning_panel.gd:52-54`; `tuning.gd:48-52`) and writes nothing. Tab switches physics mode during play (`hud.gd:54`). A `build_sha` therefore fixes the default values. It does not fix live panel edits, the physics mode Andrew was in, or values hard-coded outside `tuning.gd`.

The gap has already produced a wrong record. Entry 2 is the only entry that lists tuning, and it lists "restitution 0.35" among the values played (entry 2 (`../docs/playtests/PLAYTEST-LOG.md`), `:84`). At the played commit `dc94b2c`, the rigid ball's bounce was hard-coded to 0.25 (`git show dc94b2c:sketches/ball-lab/src/rigid_ball.gd`, line 35), and the restitution knob fed only the kinematic ball (`kinematic_ball.gd` line 75 at the same commit). The entry is right about the slider and wrong about the rigid mode Andrew preferred. Entries 3 to 5 record no tuning at all.

## Options

Promotion route:

| Option | Disposition | Reason |
| --- | --- | --- |
| Verdict-gated promotion through the heavy lane: a card re-implements the mechanic in `native/` under the accepted ADRs, carrying the traced tuning as evidence | **Recommended** | Uses the review, ownership and qualification the project already has, and keeps Andrew's verdict as the entry test. |
| Merge the kept sketch code into `native/` after the verdict | **Rejected** | Sketches skip review and treat typed warnings as optional (`ORCHESTRATOR.md:112-116`). Sketch code also mixes what TADR-002 separates: the rigid ball turns intent into forces inside its own `_integrate_forces` (`sketches/mobility-kit/src/rigid_ball.gd:76-126`), while TADR-002 line 26 gives one coordinator the tick. |
| Promote only through a Bible amendment, with no per-mechanic criteria | **Rejected** | A Bible edit re-pins six sections and cascades to others (EV-0579). Batching every kept mechanic behind one would delay single decisions and would still drop the tuning. |
| Promote on automated lab scores | **Rejected** | Automated play is never feel evidence (`PLAYTEST-LOG.md:3`; `ORCHESTRATOR.md:114`). |

Traceability record:

| Option | Disposition | Reason |
| --- | --- | --- |
| A machine-written tuning journal per play session, committed as `docs/playtests/tuning/entry-<N>.json` and referenced by hash from the verdict line | **Recommended** | The sketch writes what actually ran. The coordinator copies a file instead of transcribing values, and a check can test the file against the played commit. |
| Prose tuning lines in the log, as entry 2 did | **Rejected** | Hand-copied. The one instance is wrong for rigid mode (see Context). |
| The build SHA alone, with live tuning forbidden in verdict sessions | **Rejected** | The SHA does not fix the physics mode or values outside the table, and the panel is how a sketch explores feel. |
| The full snapshot embedded in the `verdicts.ndjson` line | **Rejected** | The verdict line is an index checked against the prose log. A journal of knob values, constants, mode times and edits belongs in its own file, written by the sketch and copied whole. |

## Decision

**Promotion criteria.** A sketch mechanic becomes production direction when all five hold.

1. **Andrew keeps it.** A playtest log entry keeps the mechanic in Andrew's words, and its `verdicts.ndjson` line passes `node scripts/lab/verdicts.mjs`. A rework request, such as the reel (`PLAYTEST-LOG.md:69`), is not a keep; the reworked sketch needs its own verdict.
2. **Its sketch checks pass at the played build.** `npm run sketch:smoke` passes at the verdict's `build_sha`. This shows the mechanic worked as built. It qualifies nothing (`ORCHESTRATOR.md:116`).
3. **Its tuning is traced.** From the cutover entry on, the verdict line references a tuning journal that the verdict check accepts. Entries 1 to 5 predate this rule and keep their gap. No reconstruction is presented as played.
4. **The Bible and the accepted ADRs agree, or an amendment is filed.** Where they disagree, an amendment card is filed and named in the promotion event. The mechanic may be promoted while that amendment is pending, but not before it is filed.
5. **The promotion is recorded.** It gets a TRACKING event (`ORCHESTRATOR.md:114`) and a `docs/decisions.tsv` row naming the entry, the `build_sha`, the journal path and any amendment.

**What a promotion carries.** It carries the mechanic's intent and constraints in Andrew's words, the played tuning as prototype evidence cited to its journal, and the sketch's tests as candidate fixtures. It carries no code and no production default. A played value may enter a technical section's parameter table only as evidence cited to its journal until the owning question is answered. TH-02 keeps prototype numbers out of its value column (TH-02 (`../docs/tech/sections/TH-02-movement-camera-and-active-aim.md`) line 211), and [Q-P21](../BACKLOG.md#q-p21) owns the movement kit.

**The heavy-lane route into `native/`.**

1. The promotion event and decision row are recorded.
2. A BACKLOG card defines the work: the promoted intent, the journal, and the ADRs and technical sections it touches.
3. A writer takes a lease in an isolated worktree with a verified base (ORCHESTRATOR § Admission and assignment).
4. The writer re-implements the mechanic in `native/` under TADR-002's ownership. Its tunables become typed Resource definitions with stable IDs (TADR-003), and the played values are their initial candidates, labelled with the journal.
5. An independent reviewer checks the result, and it is integrated serially.
6. Native qualification runs from the engineering handoff when a build is authorized ([README](README.md) line 43; [Q-E01](../BACKLOG.md#q-e01)).
7. Andrew plays the native build, and that verdict carries the same journal shape.

After promotion, the sketch stays in `sketches/` as a reference or is parked, as Cable Bench was (EV-0578). It is never a dependency of `native/`.

**Playtest traceability.** Every verdict names the exact tuning values that were played. The record is one JSON file per verdict entry at `docs/playtests/tuning/entry-<N>.json`, committed with the verdict. Its proposed shape:

```json
{
  "schema": "scrapkeep.playtest-tuning/1",
  "entry": 6,
  "sketch": "sketches/mobility-kit",
  "build_sha": "<40-hex commit the verdict names>",
  "tree_clean": true,
  "engine": { "godot": "4.7.2.stable", "physics_engine": "Jolt Physics", "physics_ticks_per_second": 90 },
  "tuning_source": { "path": "sketches/mobility-kit/src/tuning.gd", "sha256": "<bytes at build_sha>" },
  "sessions": [
    {
      "started_utc": "2026-10-01T02:10:00Z",
      "ended_utc": "2026-10-01T02:31:12Z",
      "mode_seconds": { "rigid": 1204.6, "kinematic": 67.2 },
      "mode_at_end": "rigid",
      "values_at_end": { "drive_accel": 34.0, "cruise": 16.5, "...": "every key in the tuning table" },
      "edits": [ { "t_s": 301.2, "key": "cruise", "from": 14.0, "to": 16.5 } ],
      "constants": { "BOOST_COOLDOWN": 1.1, "...": "every constant in tuning.gd" }
    }
  ]
}
```

The example values are illustrative, not measured. The verdict's `verdicts.ndjson` line gains two fields: `"tuning"`, the journal path, and `"tuning_sha256"`, the SHA-256 of the file's bytes. A verdict that spans several sessions lists each one in `sessions`.

Three parties produce the record. The launcher, `scripts/play.mjs`, already resolves each worktree's branch and head (`scripts/play.mjs:48`). It writes the journal header (`sketch`, `build_sha`, `tree_clean`) and tells the sketch where to write, under `artifacts/local/playtests/`, which git ignores (`.gitignore:7`), so play never dirties the tree. The sketch appends to the journal on every panel edit, every mode switch and on quit. When logging the verdict, the coordinator copies the matching journal to `docs/playtests/tuning/entry-<N>.json` and adds the two fields.

A mode that reads a value from outside `tuning.gd` defeats the record. The rigid ball's hard-coded friction and bounce are one such case (`sketches/mobility-kit/src/rigid_ball.gd:37-38`). That is a defect in the sketch, fixed by moving the value into the tuning table, not by recording around it.

**Enforcement.** `node scripts/lab/verdicts.mjs`, which `npm test` already runs, gains these checks for every entry from the cutover on:

- The `tuning` field is present, the file exists and its SHA-256 equals `tuning_sha256`.
- The file's `entry` and `build_sha` equal the verdict line's.
- `tuning_source.sha256` equals the SHA-256 of `git show <build_sha>:<tuning_source.path>`.
- Every session's `values_at_end` has exactly the keys of the tuning table at `build_sha`, each value within that row's bounds. The table is one row per knob by design (`tuning.gd:3-4`).
- The `engine` physics settings equal `git show <build_sha>:<sketch>/project.godot`.

Each check gets a negative control that corrupts one field and must fail, following the house practice for paper checks (TH-15 line 401).

**Future cards.** This ADR proposes them and implements none. The coordinator assigns their IDs and lanes.

1. **Sketch tuning journal.** Each sketch writes the session part of the journal. This is sketch-only work.
2. **Launcher journal header.** `scripts/play.mjs` writes the header and passes the journal path. This is heavy lane because it touches `scripts/`.
3. **Verdict tuning check.** The `verdicts.mjs` checks above, with tests and negative controls. The card also sets the cutover entry number.
4. **Tuning completeness.** Move the values each mode reads from outside the table into `tuning.gd`, starting with `rigid_ball.gd:37-38`, and mark mode-specific knobs such as restitution, which only the kinematic ball reads (`kinematic_ball.gd:75`).
5. **Log and lane text.** The log's header (`PLAYTEST-LOG.md:3`) names the journal among what each entry records, and ORCHESTRATOR's light-lane section points to these promotion criteria. Both files belong to the coordinator.

## Consequences

"What exactly did Andrew play?" gets answered by a committed file, not by recollection. The coordinator's work per verdict grows by one file copy and two fields. Each sketch gains a small journal writer, and the F1 panel stays as it is.

Entries 1 to 5 keep their gap. Entry 2's restitution line stays as history; whether to annotate it is the coordinator's call, and this ADR does not edit the log.

A kept mechanic reaches `native/` more slowly, through a card, a review and qualification. That is deliberate, because the sketch code was written to be thrown away. Played values become citable evidence for questions such as Q-P21. That may create pressure to answer those questions from sketch numbers, so this ADR leaves each question's owner as the decider.

## Later qualification and reconsideration

Under the future journal cards, a scripted session must edit two knobs and switch modes once, and the resulting journal must record all three events with the right values. A negative control drops one edit, and the verdict check must reject the result. The cutover entry number is fixed when the verdict tuning check lands.

Reconsider this decision in three cases. If native builds gain their own in-game tuning, the journal's value set should come from the TADR-003 Resource definitions rather than `tuning.gd`. If Andrew stops tuning live, the edit log loses its purpose. If the journal proves too heavy for the light lane, its cost is measured before any field is dropped.
