# ACE music system: compose in the engine, perform in ACE-Step

Design proposal, 28 September 2026. Andrew's direction retires the live hybrid: the synth engine composes and arranges guides; ACE-Step performs and produces the music; gameplay SFX remain synth in the audible key. This replaces AUDIO-V3 §12's architecture, R5's drums-and-keys-only bed recipe and G11's literal accumulation rule. It preserves their musical intentions through arranged sections and enter-means-exit. No production, runtime change or acceptance is claimed here.

Scope is this document. The assignment names `proto/core-loop-v3-audio` at `9418d63`; Git identity was not checked because Git is prohibited. The working files, including existing engine edits, were read without modification. Coordinator owns admission, source-record reconciliation and commits.

## 1. Adaptive model

Each theme is a family of performances with one progression, bass identity and motif vocabulary. Calm, travel/build, drop line, club, open window, break, lounge and summary are sections, selected by game facts. Ordinary changes start on the next bar, phrase variations on four-bar boundaries. No gameplay outcome waits for the music.

Each section has three Demucs stems, `drums`, `bass`, `other`, from exactly one take. They share the same source hash, sample count, trim and warp map, and advance even while muted. Never combine one take's drums with another take's bass. There is no continuous live synth bass, drum kit, arp or lead over ACE music. Repaint creates a new whole section and new stem set.

Three streams do not mean three musical parts. Count audible foreground roles in the guide and rendered mix: rhythm section, bass, harmony, lead, answer/ornament. Cap calm at three roles and all other states at four, including a musical stinger and ringing foreground tails. This adopts the stricter restraint proposal inside R4's range. `other` may contain two roles; a rendered fifth foreground idea fails admission even with only three files playing.

Enter-means-exit: a new answer replaces or backgrounds the lead; a stinger takes a role from the arrangement. Pressure changes gains, register, filtering and the selected arrangement, never enables every part. Compose a trough before a peak. Energy targets, independent of master loudness: calm 2, travel 5, telegraph 6, open 2, landing 8, sinister break 3 rising to 7, unseal 10, lounge 2, summary 3.

Transitions release the old rhythmic stems before the new downbeat. Only an approved non-rhythmic tail may overlap, within the role cap; otherwise use a short outgoing fade and a fresh attack. Do not equal-power-crossfade two complete grooves. Shared motifs and voicings carry continuity between performances, rather than an always-running bed.

| Event | Rendered music | Live response |
| --- | --- | --- |
| Evolution | The subsequent section uses an evolution arrangement, with its tease/answer written into the guide | Keep the class motif plus rig-specific two-note tag synth, keyed at playback; next-beat fanfare, no 16-rig × tempo × key render bank |
| Ceremony reveal | ACE one-bar, percussion-light reveal, derived from the parent palette; D/Eb/E/F at the three fixed tempos | Immediate keyed confirmation on the reveal frame; ACE phrase begins next beat as a new local bar, after the arrangement makes space |
| Drop landing | ACE four-bar bright chorus; final Warden payoff is eight bars home in D | Reward-ladder note, speed-pitched spring snap and slam womp remain synth on the contact frame; music gaps immediately, then drops next beat |
| Clear/launch | Guide contains A7b9 suspension, mallet ascent, resolution and high-D answer | The rice-cooker climb and two done beeps remain available as keyed SFX; suppress a duplicate when the rendered section already supplies them |

G9 is the explicit exception to ordinary bar switching: the next beat becomes bar 1 of the payoff, as current `drop_now()` already resets `bar_origin`. The maximum musical wait is one beat, 349 ms at 172 or 465 ms at 129, plus output buffering. A next-old-bar wait could reach 1.86 s and is rejected. The gap is at most the remainder of a beat, never a full-bar silence.

Opening a short Warden window immediately ducks the bass and thins the current stems; its dedicated open section enters at the next bar only if the window still exists. A landing or miss cancels that queued open. Immediate state audibility therefore survives windows shorter than a musical transition. Held-door ticks and the threat ratchet remain keyed/game-clock SFX, not an added music groove.

## 2. Content plan and counts

All lengths below are 4/4 bars unless marked as a bridge. D means the existing Dorian/minor mixture with its authored chromatic harmony, not a blanket D-minor pitch whitelist. Eb is +1 semitone; E is +2; F is +3. Keep separate rendered keys, never runtime pitch-shift the whole track to lift it.

Nominal grids are 172 and 129 BPM, plus Brindle's 150. Preserve the engine's exact 44.1 kHz grid for the first slice: 3,846/5,128/4,410 samples per sixteenth. Thus a 16-bar section is 984,576/1,312,768/1,128,960 samples, about 22.33/29.77/25.60 s. ACE gets integer BPM metadata; conform the output to these exact lengths. Do not mix rounded engine BPM and independently calculated loop lengths.

| Family and exact section IDs | Keys / tempo | Bars per section | Accepted sections |
| --- | --- | --- | ---: |
| Each of `spillway`, `sluice`, `weir`: `calm-a/b`, `travel-a/b` | D and Eb / 172 | 16 | 8 per stage |
| Each stage: `drop-line`, `landing` | D and Eb / 172 | 4 | 4 per stage |
| Each stage: `sinister`, `lift`, `cadence` | Eb, D→Eb, Eb→D / 172 | 8, 1, 1 | 3 per stage |
| Each stage's `warden`: `build-a/b` | D and Eb / 129 | 16 | 4 per stage |
| Each Warden: `open`, `drop` | D and Eb / 129 | 4 | 4 per stage |
| Each Warden: `break`, `unseal`, `pivot`, `lift`, `return` | Eb/129, D/129, D/172→129, D→Eb/129, D/129→172 | 8, 8, 1 old-tempo bar, 1, 1 old-tempo bar | 5 per stage |
| Spillway reactor `travel-pedal`, `warden-build-pedal` | D and Eb / 172, 129 respectively | 16 | 4 |
| Moss: `lounge-a/b` for each stage | D and Eb / 172 | 16, half-time feel | 12 |
| Brindle each phase: `base-a/b`, `lifted-a/b`, `break`, `lift` | Phase 1 D→Eb/129; phase 2 Eb→E/129; phase 3 E→F/150 | 16 for base/lifted, 8 break, 1 lift | 18 |
| Brindle chase: `base-a/b`, `lifted-a/b`, `lift` | E→F / 172 | 16, pickup 1 | 5 |
| Brindle `victory`, `cadence`, `entry`, `phase3-bridge`, `chase-bridge` | D/172; F→D/172; D/172→129; E/129→150; E/150→172 | 8, 1, 1, 2, 2 | 5 |
| `title-a/b`, `summary-win`, `summary-loss` | D / 172, half-time feel where quiet | 16, 16, 8, 8 | 4 |
| `ceremony` stinger | D/Eb/E/F × 172/129/150 | 1 | 12 |

Core total: 45 stage + 39 Warden + 4 reactor + 12 lounge + 28 Brindle + 4 title/summary = 132 three-stem packages, plus 12 stereo stingers. That is **144 accepted sections and 408 shipped audio files**, excluding manifests, masters and discarded takes. Short clips come from longer contextual renders, not unsupported one-second generation requests. A/B means alternate phrasing/re-voicing of the same composition, never two different grooves layered together.

At an estimated 128 kbit/s stereo Vorbis per stem, a 16-bar package costs about 1.07 MB at 172 or 1.43 MB at 129. Allow **100–160 MB** for the core compressed library and tails; measure after encoding. Lossless source mixes plus stems need roughly 2–4 GB before candidate retention. These are planning estimates, not measured deliverables.

Spillway keeps electric piano and sax calls over the reese roll; Sluice keeps clav, brass and slap bass; Weir keeps gospel organ, reversed talkbox answers and root-octave bass. Their Warden arrangements inherit those voices inside one funk-octave bass part, instead of playing the old bass and a new bass simultaneously. Brindle quotes Weir, Sluice, Spillway in that order. His within-phase lifts already exist in code, so Eb→E and E→F content is counted rather than silently flattening G7 to one global half-step.

The first lip commit plays one 172 bar containing three pulses, then establishes 129. Stay at 129 across shelf/bowl laps until unseal and the return cadence; Moss then inherits 172 with a half-time feel. A per-lap pivot or a lounge entered at 129 is outside this core count and needs an explicit content addition. Tempo-ramp bridges carry their own sample/beat map; loops never ramp, and gameplay cues are not held through a bridge.

At 129, the drop-line suspension reuses the Warden `open` performance with approach gains: A7sus4 in D, Bb7sus4 in Eb, ascending guide figure and no tonic resolution before the landing. Opening the window thins that same take further. Author the b9 tension at a marked exit beat; if gameplay outruns that exit, the immediate keyed threat cue carries the tension and the landing still wins. This trades exact arbitrary-time harmonic insertion for an authored phrase without adding an uncounted section.

The snowball needs a second, bounded remix bank. For each stage at D/Eb and 172/129, reserve 13 parent-derived arrangements: three class counters, Fleet ticks 1/2/3, spiral/bell-fifth/tom-sub evolutions plus choir fallback, and three rule accents. That is **156 additional 16-bar packages**. Four evolution treatments for each stage lounge at D/Eb add **24**. Fully populated: **324 accepted sections, 948 audio files, roughly 300–420 MB compressed**. Produce only observed/authorized rows after the core wins; this is a ceiling for single treatments, not a promise of every combined loadout.

Choose one treatment per phrase: combat section first, then latest landed evolution, then rule, Fleet tier, class counter. Power tier/heft/overcharge affect intensity and space within that choice. Persist suppressed requests and replay their recognition cue in live SFX; armed evolution uses one four-bar excerpt before returning. Multiple independent pinned slots and all combinations cannot be reproduced by this finite bank. This proposed reduction of AUDIO-V3 §3 needs Andrew's listening acceptance; no gem is declared preserved merely because a manifest names it.

| Gem | Required guide/render evidence and remaining limitation |
| --- | --- |
| G1 | Exact eight-bar Dm9/G13/Dm9/Cmaj9/Bbmaj9/G13/Em7b5/A7b9 cycle, jazz voicings and sax call/response. Inspect the actual cover, not just its guide |
| G2 | A7b9→D climb and two high-D done beeps in clear/return material; live cue supplies variable launch duration |
| G3–G4 | Spill-B triplet pivot, 129 four-on-floor, funk octave bass, baked pump, dark build/bright drop, unseal and cadence. No brostep substitution |
| G5–G6 | Stage instruments above; Brindle's reverse-order quotes and high-D victory. Motif/rhythm annotations accompany each master |
| G7 | Warden 50% pickup/lift to Eb, 75% half-time sinister Eb break with flat second/tritone, unseal home; Brindle phase and within-phase keys above |
| G8 | Recognizable reese/slap/ladder figures and clean sub in the produced performance. Demucs bass alone loses reese harmonics; assess bass+other and ducked renders |
| G9 | Contact SFX/gap now, rendered payoff next beat; arbitrary speed/impact/flight-length articulation stays synth SFX |
| G10 | Four-bar re-voicing, introduced answers, withheld return and solo/trough passages authored into A/B and treatment variants. Infinite generative counterpoint and simultaneous pins are lost; bounded remixes and exact motif SFX mitigate |
| G11 | One escalation reducer, actual segment fractions, 0.5/0.75 thresholds, duplicate/stale-event rejection and payoff by the caller. Keep musical identity; replace literal “add, never swap” with R4's restraint rule |
| R1–R2 | Reject talking/formant growls and main-texture wobble. Brindle-only restrained rhythmic wobble is optional, never a new default |

Guide motifs retain Sable D-F-A-C-E, Rivet A-A-A-D and Kest D-A-F-D with their original rhythms/registers; transpose intervals with the live key. Fleet is D-Eb-D with anvil stamps. Only the reactor colours music: Ab against D, A against Eb. Swarm quartal D-G-C-F and the Mind's inverted class quote with its wrong last note stay synth threats. Moss keeps the stage's calm bass and half-speed sax answers; babble stays synth. His dialogue does not become generated vocals.

## 3. Generation pipeline and capability evidence

Evidence roots: `ACE = /home/andrew/.local/share/ACE-Step-1.5`; `MV = /home/andrew/Projects/music-video`. “Verified in code” means inspected implementation, not an executed render or a musical-quality finding.

| Capability | Installed evidence | Use / boundary |
| --- | --- | --- |
| Cover | Verified in code: `ACE/acestep/inference.py`, `GenerationParams`, source-duration handling at 816–820; local example `MV/ace/jobs/wave6-W6-sung-70-101.json` | Primary guide→performance path, `src_audio`; cover strength is conditioning, not a note/groove guarantee |
| Repaint | Verified in code: `inference.py` repaint parameters/cache; `core/generation/handler/{generate_music,conditioning_masks,repaint_waveform_splice}.py` | Repair or remix a bar-aligned span in a parent take; re-screen and re-separate its whole output |
| Extend | Verified in code: `core/generation/handler/padding_utils.py:37–58` pads negative starts or ends beyond source length | Repaint outpainting, not a standalone `task_type=extend`; continuity and usable extension length remain untested here |
| Lego / stem-conditioned generation | Verified in code: `acestep/constants.py:76–89,130–138`, `handler/task_utils.py:80–114`, conditioning masks | `lego`, `extract`, `complete` are base-model paths, not the chosen XL-turbo workflow. Separate generated stems meshing perfectly is inferred and unproven; exclude from core production |
| Text-to-music | Verified in code: `inference.py` default task and LM branch | Optional title ideation; cover the authored guide for gem-bearing sections |
| Reference audio | Verified in code: `GenerationParams.reference_audio`, passed through `inference.py:836` and `handler/generate_music.py` preparation | Shared timbral reference; family resemblance and motif fidelity are inferred outcomes, not locks |
| LoRA | Verified in code: `handler/lora/lifecycle.py`, `add_lora/load_lora`; training modules under `acestep/training/` | Optional future family-style experiment. No suitable instrumental adapter or quality win verified; no training in these waves |

R5 and its restraint proposal were read in sibling worktree `core-loop-v3-audio-3/sketches/core-loop/tools/ace/`. Craft notes were found at `MV/.claude/worktrees/song-composer-skill-improve-a886f5/songs/giddy_up/lab/craft-notes.md`, not under `MV/ace/`. Their “ScragVAE not installed” note is stale: the installed checkpoint directory now contains `scragvae`. The current API skips the LM for cover/repaint/extract at `inference.py:608–612`; planner-on text2music preferences do not establish a cover-mode benefit.

1. Render lossless engine guides with a density/role plan, motif notes, chord map, key/tempo map, intended entry/exit chord and game-state trigger. Use the restrained complete arrangement, including its bass. Long-form parent guides contain the little bridges/stingers in context. Archive guide hashes and engine-source hashes with the job.
2. Start with R5's `acestep-v15-xl-turbo`, 8 steps, shift 3.0, ScragVAE, cover strength 0.7, `thinking=false`, explicit BPM/key/4/4, `[Instrumental]`, lossless WAV. Set caption/metadata rewriting off; record effective defaults, model/VAE hashes and seeds. Describe Dorian in the caption because `keyscale` is major/minor. Caption ≤512 characters, lyrics ≤4096. Name only the intended parts, absences and timeline; remove the obsolete “drums+keys only” bed restriction.
3. Keep one prompt skeleton and one accepted reference excerpt per family. Use the same four seed IDs for matched trials, preserve the actual winner, then make covers/repaints from that parent. A shared seed alone does not preserve identity; changing conditioning changes the result. For a new key, use a transposed guide with the same timbral reference. Do not accidentally cover a D source while merely asking for Eb metadata.
4. Screen raw takes for actual tempo/downbeats, missing/added bars, tonal centre/chord turns, motif/bass identity, density, unwanted vocals/growls, clipping and internal groove. Start with ≤25 ms residual error on structural downbeats after a fitted global grid and ≤10 ms cumulative loop-length error before final conform; these are proposed gates to calibrate in the first slice. Judge subdivisions against the take's own swing, bass/drum relationship and recurring accents. The old per-kick match to synth drums is retired.
5. Apply one common modest timing conform to the complete performance. Reject/repair isolated bad bars; do not snap every bass/drum hit independently. Then Demucs-separate `drums/bass/other`, retain/check the vocal residual, and reject audible voice contamination. All subsequent trims/warps are identical across stems. Never discard a meaningful fourth residual unnoticed.
6. Trim all stems together to exact loop sample bounds; audition repeated seams and all outgoing/incoming joins. An approved same-take wrap tail is baked into all relevant stems, never added as a second drum loop. Require stem phase/length agreement, no attack loss, no cumulative drift, clean bass duck and a usable `other`-only state. If separation leaves too much bass or kick in `other`, repair the full take or author a sparse open section; do not promise isolation Demucs cannot supply.
7. Master the reconstructed mix, preserving relative stem gains. Use R5's rumble removal, gentle glue and oversampled peak control as needed, with shared gain/reduction across stems so their sum matches the approved master. Do not normalize every stem to -14 LUFS. Keep -14 LUFS as audition reference and ≤-1 dBTP after encoding; runtime state trims target AUDIO-V3's quiet/open/drop contrast. Recheck every allowed stem combination, threat ≥6 LU margin and open/hold low-end reduction.
8. Blind-present loudness-matched candidates with a sealed identity key and actual transition sequences, not just isolated best excerpts. Include the existing loved reference and a less-favoured screened take. Andrew's verdict chooses music; measurements only screen it. Archive accepted source, stems, trims, manifest, hashes, listen result and rejected reasons; no re-render of a winner just to reproduce it.

GPU budget: AUDIO-V3 §12.1 reports a historical 16-bar 172 cover at 45 s wall / 12.3 GB GPU peak, and Demucs at 4 s. That does not benchmark this XL/ScragVAE recipe. Budget **1–2 minutes per 16-bar candidate**, longer at 129 or for contextual bridges, plus cold model load and CPU finishing; replace this estimate with the first actual receipt.

First slice has 18 accepted excerpts: four candidates each = 72 serial jobs, plus 8 matched strength trials at 0.8/0.9 on one parent = **80 jobs, roughly 80–160 minutes**, before retries. Core ceiling is 144×4+8 = 584 jobs, or 730 with 25% contingency, roughly 12–24 hours at the planning rate. The optional 180-package treatment bank adds 720 candidate jobs before retries. Extracting several clips from one accepted contextual take reduces job count; record that sharing explicitly.

Run batch size 1, one GPU job across ACE and separation at a time, under the shared `MV/ace/run.py` GPU lock. Use a separate `systemd-run --user --scope` with `MemoryMax=28G`; keep `MAX_CUDA_VRAM` at or below the runner's 12.5 GB ceiling and lower it for currently available VRAM. Serialize Demucs under the same ownership even if its script lacks the lock. Stop on memory pressure/lock conflict; do not raise the cap or launch a second worker. No jobs run for this design.

## 4. Runtime contract

Reduce `music_engine.gd` to section selection, three synchronized file cursors, gains/envelopes, the existing event queue and cue lane. Retain the `render(frames)`/`out_music`/`out_stinger` seam so `audio.gd` can keep its paired generator pump. Instantiate Ogg playbacks and pull bounded blocks with `AudioStreamPlayback.mix_audio()`, splitting at scheduled sample boundaries; do not launch three independent players from `_process` and hope they align. [Godot documents this pull API](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayback.html#class-audiostreamplayback-method-mix-audio); installed-version availability, decode rate and short reads need the runtime proof before admission.

Native `AudioStreamSynchronized` and `AudioStreamInteractive` offer synchronized starts and beat/bar transitions, but this proposal keeps one pull mixer to preserve the existing gap, per-stem duck and stinger contract. Do not add a second transport during migration. [Synchronized stream reference](https://docs.godotengine.org/en/stable/classes/class_audiostreamsynchronized.html), [interactive transitions](https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html).

One manifest row owns `id, family, parent_hash, stem_hashes, sample_rate, sample_count, bar_samples/beat_map, key_offset, chord_map, entry/exit, loop_bounds, foreground_roles, stem_gain_presets, allowed_successors, gem_checks`. Bridges identify the sample where the destination clock/key commits. The runtime refuses mismatched stems, undocumented transpositions and unavailable successors. `playhead_sample` is transport truth; integer bar/beat tables come from the approved asset, not elapsed frame deltas or gameplay time scale.

Prepare current/next section decoders before the boundary. Read every stem by the same frame count even at zero gain; handle EOF/short reads atomically, with no one-stem restart. At a switch, apply pending key and tempo before resolving same-sample keyed SFX. For the lift pickup, expose the pickup's actual harmony/key to cues; retain the earned stage key separately until the destination commits. Never report Eb because it was requested while D audio is still sounding.

Same-key A/B changes preserve the harmonic bar index in the shared 16-bar map. A new section starts at its authored entry or pickup, with an allowed chord transition from the current bar; equal tempo alone does not qualify a join. Validate every legal exit bar offline. Landing is the deliberate exception that resolves the held dominant and establishes a fresh tonic downbeat.

Queued requests carry run generation, encounter identity and priority: death/run exit > unseal/victory > landing > lift/break > open/build > arrangement variation. Reduce duplicate thresholds once, retain earned lift/break across temporary drops, cancel stale windows and stale run queues. Before a switch commits, a newer state may replace it. A loading miss keeps the current valid section and its key for one more boundary, logs the miss, and still plays immediate SFX; it never joins stems from a partially loaded take.

Keep danger bass gain 0.3, free-on-release, open-window hold and priority duck 0.55 for 0.35 s with the existing intensity scaling and beat recovery. Apply music gap, pause gain and tone filter after the stem sum; cue lanes remain separate. Pump is authored into ACE, so never blindly apply the old 0.65 synth sidechain again. The deeper-pump rule gets a rendered variant. The reactor gets a dedicated pedal performance at Ab/A; filtering a D bass cannot manufacture Ab. Its Geiger cue answers immediately, the pedal section enters on a bar, and eruption immediately ducks/filters its low end until the non-pedal section returns.

The queued generator buffer is part of latency. Bound render-ahead, track rendered versus consumed frames and test contact-to-gap latency on the actual device. A game-frame event cannot erase samples already sent to the speaker. Keep immediate SFX on the existing low-latency SFX path, and use [Godot's playback/latency guidance](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html) for audible-position telemetry, not as a second music clock. Pause/hit-stop retains current policy: transport continues with pause attenuation; retry resets sections and key explicitly.

`audio.gd` keeps event wiring, cue admission, class/priority resolution, user volume controls and SFX synthesis. Replace direct layer/oscillator accesses with section/treatment requests; adapt `_follow_warden`, `_follow_escalation`, `_follow_brindle`, launch/landing and lounge adapters. `cue_context()`/`KEYED_SOUNDS` read the sequencer's committed cue key/grid. Replace music-voice diagnostics with section, cursor, transition and gain logs. No collision, Warden or reward outcome code changes are required.

Ship Ogg **Vorbis**, not presumed native Opus. [Godot's import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html) lists the supported formats; an Ogg container does not imply Opus support. Keep Opus for previews only unless a separately approved decoder path proves it. Retain 48 kHz lossless ACE masters, conform runtime assets to the tested mixer rate. Load compressed resources per stage asynchronously before entry; only active/next stems have rolling PCM blocks. Compressed residency is still RAM, not guaranteed disk streaming. Budget 32 MiB core-stage music residency and 8 MiB PCM/decoder working space initially; treatment banks load on demand and must be measured. A fully decoded 16-bar float-stereo trio costs about 24–32 MB, so never decode the whole stage to PCM.

| Tests / tools | Runtime assertions to retain | Assertions that become content checks |
| --- | --- | --- |
| `presentation_gems_test.gd` | G3 timing, G7 threshold/key commits, G9 gap/payoff, G11 reducer | G1/G5/G6 notes/voices, G8 figures, G10 arrangements, R1/R2 sound exclusions bind guide+master hashes and Andrew's listen receipt; no fake `layer_starts` |
| `presentation_music_test.gd` | Cue quantisation, cancellation, output bounds, loudness by state, decode cost | Replace monotonic/all-layers-full tests with cap, enter-means-exit, contrast, role budget and authored phrase coverage |
| `presentation_bass_test.gd` | Bass duck/release timing and open-window low-end | Bass-note logs, reese/slap tone, sub balance, restrained Brindle wobble become recorded-audio checks, including residual bass in `other` |
| `presentation_themes_test.gd`, `presentation_escalation_test.gd`, `presentation_v3_test.gd` | Transitions, 172→129 bridge, D/Eb/E/F, resets, late loads, simultaneous events, duplicate/stale thresholds | Chord/sus/pump/roll/rotation internals move to per-section content checks; finite pin behaviour is explicitly revised, never silently passed |
| `presentation_motifs_test.gd`, `audio_music_layers_test.gd` | Exact SFX motifs and keying, class/Fleet/reactor/lounge signal routing | Band counter/Fleet/layer-mask assertions become treatment-selection plus listening/content evidence |
| `presentation_audio_test.gd`, `presentation_retry_test.gd`, `presentation_sfx_test.gd`, `audio_cue_resolution_test.gd`, `audio_board_test.gd` | Flow/retry/mute, cue resolution, priorities, synth output; replace only engine-private assumptions | Boards render the actual shipped stems and log hashes/encoding, not synthetic stand-ins |

Rows, banner, juice and hit-stop tests retain their gameplay/presentation meaning. Add a sequencer fixture with distinguishable impulses to prove stem phase, loop wraps, next-beat bar reset, key commit order and underrun handling; then test shipped audio for ten minutes across pause, mute, retry and load failures. Deterministic transport proof cannot establish groove, repetition tolerance or human feel.

## 5. Migration waves and exact file scope

All paths here are relative to `sketches/core-loop/`. Proposed names do not imply existing files. Asset convention: `assets/music/ace/<family>/<section>__<key-or-key-transition>__<tempo-or-tempo-transition>/{drums,bass,other}.ogg`; stingers use `assets/music/ace/stingers/ceremony__<key>__<tempo>.ogg`. Catalog tables above enumerate the finite IDs; metadata lives in `assets/music/ace/manifest.json`. Scratch and blind evidence go under repository `artifacts/local/ace-music/`.

| Wave | Exact files and deliverable | Gate |
| --- | --- | --- |
| 0, design | This `design-v3/ACE-MUSIC-SYSTEM.md` only | Coordinator review; no jobs or gameplay edits |
| 1, first slice production | New `tools/ace_music_guide.gd`, `tools/ace/{catalog,screen,package}.py`, `tools/ace/jobs/spillway-slice.json`; Spillway asset rows below and `assets/music/ace/manifest.json` | Authorized production, automatic screens and Andrew's blind slice listen before other themes |
| 2, runtime proof | Move preserved composer to `tools/ace/guide_engine.gd`; reduce `src/presentation/music_engine.gd`; new `src/presentation/music_catalog.gd`; adapt `src/presentation/audio.gd`; new `tests/presentation_sequencer_test.gd`, `tools/ace/content_checks.py`; revise the named music tests above and `tools/audio_v3_board.gd` | Native transport/cue checks, three-minute play listen, then approval to expand |
| 3, core library | New `tools/ace/jobs/{spillway-rest,sluice,weir,brindle,lounge-title-summary,ceremony}.json`; remaining exact table rows under `assets/music/ace/`; update manifest and content receipts | Each family blind-picked; every listed gem tied to a heard master |
| 4, snowball remixes | New `tools/ace/jobs/{class-fleet,evolution-rules,lounge-evolutions}.json`; treatment IDs `class-{sable,rivet,kest}`, `fleet-{1,2,3}`, `evo-{spiral,bell,tom,choir}`, `rule-{clap,pump,brass}` under each stage's `172`/`129` family; lounge `evo-*` rows | Select observed combinations first; Andrew accepts finite-treatment behaviour before retiring pins |
| 5, subtract and reconcile | `src/presentation/music_engine.gd`, `src/presentation/audio.gd`, `tools/ace/guide_engine.gd`, affected tests; coordinator updates `design-v3/AUDIO-V3.md`, `src/presentation/MUSIC-GEMS.md`, `SOUND-STORY.md` and the applicable ADR/desk record | Accepted ACE path, no runtime synth-score dependencies, preserved source/listening receipts |

Wave 1's **18 packages / 54 stem files** are Spillway `calm-a/b` D172, `travel-a/b` D172; Warden `build-a/b` D129, `open` D129, `drop` D129, `pivot` D172→129, `lift` D→Eb129, `build-a` Eb129, `open` Eb129, `drop` Eb129, `break` Eb129, `unseal` D129, `return` D129→172; plus `warden-build-pedal` D129 and Eb129. Do not produce Sluice, Weir, Brindle, title or lounge while this listening gate is unresolved.

After ACE holds, remove runtime `_trigger_dnb/_funk/_halfpipe/_house/_break/_drop/_brindle/_victory/_lounge`, generated bass/lead/counter/choir voices, rotation note synthesis, music sample caches, fifteen-layer pressure curves, live riser/drum fills and obsolete bed-over-synth mixing. Preserve their musical recipes only in the offline guide engine. Keep `harmony.gd`, `synth.gd` and `sfx_bank.gd` portions used by keyed effects, motifs and cue baking. Before deletion, map actual callers and migrate tests; do not keep silent synth sequencing merely to make historical tests green. A missing ACE file fails the music mode visibly in diagnostics, with SFX working, rather than reviving the retired hybrid.

## 6. Risks and open questions, recommendation first

1. **Require a three-minute blind play test before scaling.** Does a loop of an ACE take hold up over 3 minutes of play? Compare one repeated 16-bar take against A/B re-sequencing through identical recorded state timelines, then Andrew plays the same slice. Collect replay/skip preference and timestamps for boredom, exposed seams or lost groove at 0:30, 1:30 and 3:00. If both tire, author a 32/64-bar development; do not mask repetition with more layers.
2. **Keep immediate SFX/gap and next-beat payoff.** Can the buffered stream path retain the loved landing response? Measure event→audible contact/gap/drop under load, with zero stale windows and no extra beat from a missed boundary; compare against the current engine. Failure blocks synth-score deletion, not gameplay progress.
3. **Reject a take that loses its gem or cannot duck cleanly.** Can ACE preserve the bass figure and Demucs isolate it enough? Check produced notes/phrasing by ear, full-stem reconstruction and the `other` residual during threats. Repair the parent or author sparse variants; never restore an unrelated live bass beneath it.
4. **Use finite treatments and expose the tradeoff.** Is one foreground evolution/rule treatment at a time enough to hear the build? The proposed priority loses simultaneous arbitrary pins and some Fleet/class combinations. Blind-test a real multi-evolution run; if it loses identity, commission the specific combined arrangements and price them before growing the catalog.
5. **Use cover/repaint on XL-turbo now; park LoRA and Lego.** Will parent-derived variants stay recognizably one family across Eb/E/F and tempo changes? Judge transitions blind with the same motif/voice criteria. If they fail, rework the guide/reference before model experiments; a new model or adapter needs its own bounded test, not a full-catalog rerender.

## Sources and evidence boundary

Local design sources: [AUDIO-V3](AUDIO-V3.md), [R4](research/R4-giddy-up-composition-principles.md), [gems](../src/presentation/MUSIC-GEMS.md), [sound/story](../SOUND-STORY.md), [engine](../src/presentation/music_engine.gd), [audio adapter](../src/presentation/audio.gd), [harmony](../src/presentation/harmony.gd). R5, restraint, craft notes and installed code locations are identified above. This is source inspection and architecture design only. Current audio quality, GPU timings, native streaming and Andrew's acceptance remain unverified.
