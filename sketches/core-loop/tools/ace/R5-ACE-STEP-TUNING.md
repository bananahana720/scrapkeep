# ACE-Step 1.5 tuning deep dive: how Giddy Up was made, genre-agnostic

Sources cited inline as `path:line`. Vocal/lyric-specific findings are dropped; only
what transfers to an instrumental drum+keys bed is kept. `(inference)` marks anything
not directly sourced.

## 1. The pipeline as used

Giddy Up was **text2music**, not cover (no `src_audio` in the final job) — the source
of ACE-Step tuning evidence below, plus For Good's cover-mode evidence (music-video),
which is what Scrapkeep's cover bed actually needs.

1. **Sketch** (4 variants, 1 seed, 40 s, `thinking:false`): `song/ace.json` sketch block,
   `giddy_up/song/ace.json:1-25`. Model implied default (2B turbo). Blind-labeled
   `blind-A..D.mp3`, picked by ear (`giddy_up/song/song.md` interview log).
2. **Lab experiments**, each a single-variable A/B against a control, defined in
   `giddy_up/song/ace.json:"experiments"` and run via
   `~/.claude/skills/song-composer/scripts/ace.py lab <song_dir> <name> [--blind]`
   (`~/.claude/skills/song-composer/SKILL.md:81`).
3. **Full render**: `acestep-v15-xl-turbo`, `task_type=text2music`, `thinking:true`
   (planner on), `inference_steps=8`, `shift=3.0`, VAE = ScragVAE
   (`ACESTEP_VAE_CHECKPOINT=scragvae`), 4 seeds, `lyrics-3act.txt`, the "timeline"
   caption. `giddy_up/release/v1.0/RELEASE.md` table; `giddy_up/song/ace.json`
   `three-act` experiment block.
4. **Assembly**: spine = take `timeline-s12`; closer = take `timeline-s11`'s final
   chorus, grafted with `producer/splice.py` (beat-aligned equal-power crossfade at
   the last chorus's downbeat). Herd intro from `producer/hooves.py` (synthetic
   distance model, hoof one-shots from Stable Audio 3 Small-SFX) laid under the
   take's own intro with `producer/assemble.py --blend -3` (herd arrives exactly on
   the drop, found from the ear's own beat grid). `giddy_up/producer/{splice,
   assemble,hooves}.py`; `RELEASE.md`.
5. **Master**: `producer/master.py` — see §4.
6. **Release**: `producer/release.py` (not inspected; packages wav/flac/mp3, stems, `SHA256SUMS`).

## 2. Tuning decisions (source: `giddy_up/song/ace.json` experiments + `~/Music/songbook/LAB.md`)

| Knob | Varied | Result | Final value |
|---|---|---|---|
| `thinking` (planner) | on/off, 4 seeds each, v2 duet | ear: off 84% word recall vs on 78%; **blind listen ranked every planner-on take above every planner-off take** ("the planner's melody codes are the musicality") | **on** for the release, despite ~6x render time and non-reproducible seeds. `LAB.md` "v2-planner" entries |
| `inference_steps` | 8 vs 20, xl-turbo | 20-step take was **byte-identical** to the 8-step control | 8 (turbo clamps effectively at 8 in practice; source docs say clamp is 20, `craft-notes.md §5`, but the direct test found no change above 8) |
| VAE | official vs ScragVAE, identical latents | objectively +0.3-1.1pp energy >8kHz, +crest; **blind confirmed ScragVAE preferred** on the same xl-turbo latents | ScragVAE |
| `model`/steps/CFG | xl-base 50 steps + CFG7 vs xl-turbo 8 steps | 5x more >12kHz content by measurement, but blind: **"garbly goop"** — rejected | xl-turbo 8 steps. Rule recorded: *"no metric result counts until a blind listen confirms it"* |
| caption structure | verbatim caption + section tags vs a "timeline" caption narrating a 3-act build | timeline caption **won 1st and 2nd** in a 4-way blind; tags alone did not build the same layering | timeline-style caption (see §5) |
| LoRA (raspy-vocal, MIT, 2B) | off / 0.3 / 0.6 scale | ear scores inconsistent, no blind musicality check run; not used in the release (voice-specific, dropped here) | not applied |
| `shift` | held at 3.0 (turbo docs default) throughout; not swept for Giddy Up | — | 3.0 |

**How "ear" scoring works** (`giddy_up/producer/ear.py`, `producer/README.md`): per
2-bar window it measures **words heard** (double-pass Whisper recall against the lyric
line), **crest dB** (peak/RMS, "squash"), **air dB** (energy share >10kHz), **vocal
flatness dB**, **groove ms/tight** (onset drift off a fitted straight 16th-note grid,
and how tightly onsets lock to it — the same idea Scrapkeep's `audition.py`/
`retime_bed.py` already use), and **clip runs**. A composite score
(`words% - 0.5*flagged% + 2*crest_dB`) ranks takes and flagged spans become repaint
candidates. **Critical finding**: on the 4-take v2 duet set the composite's ranking
against the human blind ranking was **Spearman −0.4** — its best take (96% words) came
last, a planted 52%-word "control" take came 2nd. *"Word recall is a floor... not a
taste score. Always plant the ear's worst in a blind set."* (`LAB.md`, "Method"
section). The ear screens; it does not pick winners.

## 3. Selection method

- **Sketches**: 1 seed per variant, rendered and delivered **blind** (letters, key
  sealed until the listener answers) — `ace.py` shuffles labels
  (`~/.claude/skills/song-composer/SKILL.md:39-45`).
- **Full takes**: 4 seeds, always kept (planner-on isn't reproducible). Ranked first
  automatically by `ear.py`'s composite (screen only), then **decided by blind
  listen** — `song.md`'s interview log records the actual verdicts (e.g. "A(s1) >
  C(s4); B(s3), D(s2) 'off'").
- **Pre-registration**: before a blind verdict, a prediction is written down and
  checked after — one prediction was refuted, treated as informative in itself
  (`giddy_up/lab/predictions.md`).
- **Compositing across takes**: once two favorites are picked for different reasons
  (best opening vs best ending), they are **spliced**, not re-rolled — `splice.py`
  finds the last occurrence of a shared section in each take's ear data and
  crossfades one beat at the downbeat.

## 4. Mastering and mix chain (`giddy_up/producer/master.py`)

ffmpeg filter chain, in order:
1. `highpass=f=25:poles=2` — sub-25Hz rumble the low end doesn't need.
2. `acompressor=threshold=-16dB:ratio=2:attack=25:release=250:makeup=1` — gentle 2:1
   glue compression.
3. `volume={gain_db}dB` — the measured correction gain (see below).
4. `aresample=192000` then `alimiter=limit={ceiling}:attack=5:release=60:level=disabled`
   — a look-ahead limiter run at 4x oversampling so inter-sample peaks stay under the
   ceiling, then `aresample=48000` back down.

**Gain convergence**: measure `input_i` (integrated LUFS) via
`ffmpeg -af loudnorm=print_format=json`, set `gain = target - measured`, render,
re-measure, repeat up to 4 passes until within 0.3 LU of target (the limiter eats
some of the requested gain, so one guess doesn't land on target).

**Targets**: `--lufs -9` (default; *"a club track sits around -9 LUFS"*), ceiling
`-1.0 dBFS` requested, rendered at `ceiling - 0.3` to leave the limiter's own headroom.
Release measured: **−9.2 LUFS integrated, −1.3 dBTP, 48kHz**. Outputs: 24-bit wav,
flac, mp3 320k.

Note this differs from Scrapkeep's own loop target already in use
(`-14 LUFS` under `-1 dBFS` ceiling, `audition.py:23-24`, `retime_bed.py` docstring) —
that's a streaming/game-loop target, not a club-master target; keep `-14` for beds
that sit under live layers rather than adopting Giddy Up's `-9`.

## 5. Transfer to Scrapkeep's beds (genre-agnostic)

| Parameter/technique | Giddy Up value | Recommended bed value | Why |
|---|---|---|---|
| `task_type` | `text2music` | `cover` (unchanged, already Scrapkeep's design) | Giddy Up had no fixed arrangement to preserve; Scrapkeep's guide is the arrangement of record. Cover-mode evidence instead comes from For Good (`music-video/ace/jobs/wave4-6*.json`): `audio_cover_strength` swept 0.4/0.6/0.8/0.95 on a 57s excerpt then 0.6/0.7/0.8 on the full 211.86s song; **0.7 beat 0.6 and 0.8** (`LAB.md` "for-good" entries) |
| `audio_cover_strength` | n/a | keep **0.7** as the default; test 0.75-0.8 for a synth guide specifically | 0.7 was tuned on a *sung, produced* source; a synth guide is cleaner/simpler, so a higher fraction of source-conditioned steps (craft-notes: `audio_cover_strength` = fraction of steps conditioned on source before the sampler switches to text-only, `craft-notes.md §2`) should hold the kick pattern *and* the density closer without the "re-humanizing" cost a sung vocal needs |
| `inference_steps` (xl-turbo) | 8 (20 was byte-identical) | 8 | don't spend render budget past the point the model ignores it |
| `shift` | 3.0 | 3.0 (turbo docs default; unswept but consistent everywhere in both repos) | established default, not contradicted by any test |
| `thinking` (planner) | on for the release; **off** for any strict A/B | **off** for every tuning sweep, generation-config screen, and cover-strength comparison; decide on/off for the shipped bed only after a blind pass | off is the only reproducible mode (same seed+params -> byte-identical wav); mixing planner randomness into a cover-strength or caption sweep hides the true effect |
| Caption content | timeline/build narration, "state absences" | drums+keys only, explicit "no pads, no strings, no vocals, no extra synths, minimal, restrained" | ACE-Step "fills silence with clutter" if not told what's absent (`ace-step.md §Caption`); this is the direct lever for the "zero restraint" rejection (§below) |
| VAE | ScragVAE (blind-confirmed) | ScragVAE | objectively more top-end, blind-confirmed on the same model family; no reason it wouldn't transfer to a drum/keys bed, and top-end matters more for hats/transients than vocal grain |
| Selection | ear screens, human blind picks | build/reuse an `ear.py`-style automatic screen (below) **gated by, not replacing**, Andrew's playtest listen | the Spearman −0.4 finding is a hard warning: an automatic score must not be the acceptance gate on its own (also matches Scrapkeep's own "fun gate" memory) |

**Kick divergence (up to 56 ms flams).** `audio_cover_strength` is a single global
fraction of *diffusion steps*, not a per-instrument or per-frame lock
(`craft-notes.md §2`); even at 0.7 the model still re-performs the kick inside the
conditioned budget, so some per-hit jitter is expected and not fully closeable from
the generation side. Two generation-side levers to test:
- Raise `audio_cover_strength` toward 0.8-0.9 (more steps anchored to source) —
  should tighten the kick at the cost of "cover" character; worth it for a bed whose
  job is to sit under a strict game clock.
- Condition on a **drums-only** (or drums+bass) version of the guide rather than the
  full mix, i.e. run Demucs on the engine's own guide render first and use the drum
  stem as `src_audio` for a percussion-priority pass, then recombine with a
  text2music or separately-covered "other" layer. `(inference)` — untested, but
  consistent with ACE-Step's stem/lego machinery (`craft-notes.md §3`) and directly
  targets what the model is asked to imitate.
- What **won't** help: `repaint` — it operates on a single 3-90s span with one global
  lyrics/caption condition, not a rhythmic pattern inside an already-generated take,
  and its own injection still re-samples inside the span (`craft-notes.md §1`).
- The robust fix already exists and should stay primary: Scrapkeep's own
  `retime_bed.py`/`retime_slice.py` per-bar and per-slice kick-lag correlation and
  shift-without-stretch. Generation-side changes should aim to *reduce the flam
  before retiming*, not replace the retimer.

**Second-half drift.** No direct Giddy Up or For Good evidence explains this
specifically `(inference)`. What's established: `audio_cover_strength` is one fixed
number for the whole take — ACE-Step has no native per-segment or per-bar
conditioning control, so a global parameter cannot fix a drift that grows over a
take's duration. This is why `retime_bed.py` already computes both a whole-bar
`drift()` correlation and a narrower `windowed_lags(..., DOWNBEAT_MS,
DOWNBEAT_REACH_S)` measurement, and why `retime_slice.py` exists at all (per-slice
donor repair) — the downstream retimer is the right place to absorb this, not a
generation parameter. One generation-side mitigation worth an A/B: For Good's cover
fidelity was tuned on a 56.5s excerpt and got worse at full 211.86s length, so the
16-bar guide (~22s) should already sit in the more-reliable regime; if drift still
appears there, that points at the sampler's own local drift under cover conditioning
rather than length, which strengthens the case for the retimer as the fix.

**Density and restraint ("zero restraint" rejection).** Two transferable levers: (1)
caption specificity — "more detail constrains the result and less detail invites
surprise" (`ace-step.md`) — so naming exactly what's present (drums, keys) and
stating every absence is a direct anti-clutter lever, confirmed by the model's
documented tendency to fill silence; (2) the three-act experiment shows ACE-Step
*will* build up layers when the caption narrates a build and won't when it doesn't —
the inverse holds for restraint: describe the target as "lean," "minimal," one or two
named elements only, and avoid layering language ("epic," "towering," "stacked"). A
higher `audio_cover_strength` should also help restraint, since the guide itself is
sparse and tighter conditioning to it suppresses invented layers, not just timing.

## 6. Concrete re-cover recipe for the next bed attempt

1. **Render the guide** at 172 BPM, D minor (Dorian described in the caption, since
   `keyscale` has no native mode field — pass `keyscale="D minor"` and add "Dorian,
   modal" to the caption text; `(inference)`, untested whether ACE-Step honors the
   modal word). Also render a **drums-only** guide stem via Demucs
   (`tools/ace/separate.py`, `KEEP=("drums","bass","other")`) for the drum-priority
   variant.
2. **Duration**: `16 bars * 4 beats / 172 * 60 = 22.33s` (bar math per
   `ace-step.md §Full render`).
3. **Caption**: name only drums and keys, state every absence explicitly (no pads,
   no strings, no vocals, no extra synths), avoid layering language. Two captions:
   one against the full guide, one against the drums-only stem.
4. **Job matrix**, planner **off** (`thinking:false`) for reproducibility during the
   sweep, `model="acestep-v15-xl-turbo"`, `inference_steps=8`, `shift=3.0`, VAE =
   ScragVAE: `audio_cover_strength` in `{0.6, 0.7, 0.8, 0.9}` x `src_audio` in
   `{full guide, drums-only guide}`, **4 seeds per cell** (matches both For Good's
   per-strength batches and Giddy Up's per-take batches).
5. **Automatic screens, in order, run on the raw un-retimed render**:
   a. **Kick-onset match against the engine kick, before any retiming**: reuse
      `audition.py`'s `kick_envelope()` + `drift()` on the cover's raw drum stem vs
      the engine's guide drums; reject any cell whose per-bar flam exceeds a set
      threshold (start at 25 ms, tighter than today's observed 56 ms) or whose
      `windowed_lags` variance across bars is high (second-half drift signature).
   b. **Density/restraint check**: adapt `ear.py`'s `air_db`/`crest_db`/`balance_db`
      machinery to compare the cover's spectral energy and layer count against the
      engine's own "above"-solo reference level (`ace_guide_v3.gd`'s `above()`/
      `gains`); flag takes whose energy or apparent layer count exceeds the guide's
      budget by a set margin.
   c. Anything that fails both screens is dropped before it reaches a human.
6. **Retime and build the bed**: run `retime_bed.py` (bar-level) and
   `retime_slice.py` (slice-level, donor repair) on every surviving candidate, as
   today.
7. **Human pick**: blind-present the surviving, retimed candidates (per cell) to
   Andrew — the automatic screens gate, they do not rank taste, per the Spearman −0.4
   finding in §2.
8. **Master** the winning bed at Scrapkeep's existing **-14 LUFS / -1 dBFS** loop
   target (not Giddy Up's -9 LUFS club target).
