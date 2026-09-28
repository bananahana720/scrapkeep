# ACE-MUSIC-SYSTEM review (2026-09-28)

Three Opus lenses (Godot runtime with real 4.7.2 probes, taste and gems, scope) and a Fable synthesis. The per-lens findings are in the workflow journal wf_391a35e3-0e2; receipts are in .pstack/receipts/cap-*.json in the session worktree.

**Synthesis.** All three reviews hold up where I checked them against the code; none contradicts another on facts. The direction (one ACE performance per section, no live synth over it) answers both rejections. The design fails on four things: it drops the telegraph's kick, it re-performs the core at every boundary (the same drums-vs-bass mesh risk Andrew rejected), it puts the cheap proofs after 80 GPU jobs, and it ships a catalog 3-4x bigger than the verdict needs.

**1. Must change before the first slice**

- §2 line 60: do not build the telegraph from the kickless `open` take. `_trigger_house` plays the kick only `if not open` (music_engine.gd:1733-1734), and the air is the dark build with four on the floor (AUDIO-V3:38). Add a 4-bar Warden `telegraph` section; keep `open` kickless.
- §2 table, `pivot`: author it as three 129 quarters at the head of the Warden parent guide, bass on the held dominant (`begin_boss` takes the root from `_chord`, which is A under `hold_dominant`, music_engine.gd:583-590). No separately rendered tempo-change bar.
- §1 line 11/17, §2 line 52: render each family arc from one contextual parent per key (calm-a/b+travel as one 32-bar take; Warden pivot→build→telegraph→open→drop as one take) and cut sections from it, so drums and bass share one performance across every boundary.
- §2 line 56: keep the level's calm bass figure on reese under the funk bass inside the Warden guide (music_engine.gd:1752-1759; G8 "really well layered").
- §2 table: add Warden `lifted-a/b` in Eb (snare on the clap, lead up an octave, arp, bright stabs: music_engine.gd:1737, 1761, 1777-1779, floor 0.7 at :107). A transposed dark build is not the lift.
- §1 line 13: the four-role cap is untested by Andrew's ear; the loved hybrid was engine layers at pressure 0.9 over cover drums+keys (AUDIO-V3:314). Tier it (calm 3, build 4, break 5, payoffs up to 6) and settle the number with R4 experiment 3 in the blind listen.
- §5 line 160 / §1 table: keep a live build lane (`_build_overlay`, music_engine.gd:2194-2211; audio.gd:790 "the launch is the build"). Roll one-shots cut from the accepted take's own drums stem.
- §2 line 62/79: class motifs enter the core, not Wave 4. `CLASS_ROTATION` seeds the counter every cycle today (music_engine.gd:156, 2131).
- §2 table: `cadence` and `return` are 2 bars, A7b9 then Dmaj9 (harmony.gd:177-182).
- §2 line 34 vs §4 line 132: ship every asset at 44.1 kHz, drop "conform to the mixer rate", call `mix_audio(AudioServer.get_mix_rate()/44100.0, n)`.
- §4 line 118: set `loop`/`loop_offset` from manifest.json at load; `*.import` is gitignored (.gitignore:2).
- §4 line 128: quantify the ring. `GEN_BUFFER=0.1` (audio.gd:26) keeps ~186 ms queued plus 38 ms device latency, so "gaps immediately" is ~250-600 ms. Target a numeric queued depth and measure contact→audible.
- §4 line 130: keyed SFX read `engine.key` (audio.gd:348), which is the render head. Read the key at the audible sample from a key-change log.
- §3 line 106: the 45 s audition was already `acestep-v15-xl-turbo`: 16.5 s load, 8 s generation for 22 s of audio (timings.json). Budget warm jobs at ~10 s; the bottleneck is Andrew's listening minutes.

**2. Revised first slice (Slice 0)**

Two parent renders, Spillway D only, 4 seeds each: (1) calm 32 bars at 172 ending in the pivot bar; (2) Warden at 129: pivot pickup, build 16, telegraph 4, open 4, drop 4. About 8 jobs plus trials, roughly 5 minutes warm. Deliverable: one offline ~3-minute WAV per candidate, assembled from a recorded Spillway state timeline, blind against the loved hybrid and one planted weak take. Stereo masters only; Demucs the winner afterwards. Eb/G7 content is Slice 1, after a win.

**3. Runtime proof of concept**

A scratch scene outside the engine, no ACE audio: `tools/ace/poc_sequencer.gd` plus `tests/presentation_sequencer_test.gd`, fed small committed impulse Oggs (three 16-bar stems D172, a 4-bar landing, a 1-bar lift). Proves: native `loop=true` wrap continuity and the 2-frame lead-in at joins; bar-boundary mid-file entry with `(sample+0.5)/rate` seeks; contact→gap→next-beat drop with measured queued depth; keyed-cue key at the audible sample across a lift; `get_skips()==0` over 3 minutes with a synthetic 26 ms frame load; identical frame counts under `mix_rate=48000`. Pass bar: every assertion exact, contact→audible ≤ current engine. Only this unlocks the `music_engine.gd` reduction (do it as a `git mv` to `tools/ace/guide_engine.gd`, then a fresh small sequencer).

**4. Gems at risk**

- G3: telegraph kick and pivot seam (above).
- G7: lift contrast; make Eb by offline-shifting bass+other from the D winner, drums identical, A/B against a separate render.
- G8: Warden bass layering; admission check that both figures are audible.
- G9: build lane retained; landing latency measured.
- G10/G11: cap tiered and the "add, never swap" replacement put to Andrew explicitly in the listen.
- G2: two-bar cadence.
- G5: write the Weir talkbox retrograde as notes, whitelist its residual.

**5. Cut**

Wave 4 and the 324/948 bank; the 12 ceremony stingers; all B alternates from the core count (33 packages) pending risk #1; Eb-172 stage rows, Eb lounge, stage `sinister` until play logs reach them (level-track events pass `sinister=false`, audio.gd:647/845, so no break exists there); the reactor pedals from Wave 1; Brindle pricing until Spillway wins; new `catalog.py` (the manifest is the catalog) in favour of extending the sibling worktree's `ace_guide_v3.gd`, `audition.py`, `separate.py`.

---

VERDICT: PASS+NOTES (design sound with the changes above). Evidence level 3: source and receipt inspection, nothing executed; runtime numbers are reviewer 1's receipts, present at `/home/andrew/Projects/scrapkeep/.claude/worktrees/game-repo-status-fork-3e5a69/.pstack/receipts/cap-{aa38cb4dea2f0fd1,5b726041a422441e,219b420771752b2c,094a858c369d1592,44605a412e4922d6,b3b7750cabf237ad,e6d37ccf6642dc0b}.json`, not re-run by me. Andrew's three verdicts are from the brief (ASSERTED, unverified). No writes, no commits, no GPU jobs.

Commands (all exit 0): `wc -l` on the six sources; `sed -n` ranges over `/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3-audio/sketches/core-loop/src/presentation/{music_engine,audio,harmony}.gd`; `cat` `.gitignore`, `core-loop-v3-feel-3/artifacts/local/ace-audition/cover/timings.json`, `logs/demucs.time.json`; `sed -n 250,262p /home/andrew/Projects/music-video/ace/run.py`; `ls` of both `tools/` trees (`tools/ace` absent in the design worktree, exit 2 for that path only); `grep` for `MAX_ACTIVE_LAYERS`, receipts and manifest fields.
