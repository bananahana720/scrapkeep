# Handoff: core-loop v3, 2026-09-28 (reset onto Sonnet 5.5)

Read this first, then `ROADMAP.md` in this folder (the canonical wave plan and every Andrew ruling). The previous session settled its in-flight work before Andrew reset onto Sonnet 5.5. Nothing is lost: each unit below is committed on its own branch, with its next step named.

## Where things live
- **Integration branch:** `proto/core-loop-v3`, worktree `/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3`. It holds the whole lab: drop, laps and interact modes, juice, class cards, the ceremony and the AU2 sound bank. Smoke: 192 of 192. The coordinator alone merges into it.
- **The visual track:** a separate clone at `/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/workspace`, branch `codex/visual-development`. Codex works there, and it's the only trusted Codex project (see Gotchas).
- **Main:** holds the launcher (`scrapkeep <sketch> -- <godot args>`) and the project desk.
- **Coordinator tools:** `sketches/core-loop/tools/coordinator/`:
  - `lab_capture.sh`: rendered stills on hidden workspace 10, GPU-polite.
  - `watch_codex.sh`: waits for a Codex job.
  - `keep_both.py`: resolves append-only doc conflicts.
- **Reusable workflow briefs** (full prompts for every unit below) are in `~/.claude/projects/-home-andrew-Projects-scrapkeep--claude-worktrees-game-repo-status-fork-3e5a69/7a71845f-f352-4263-acb1-425711da4701/workflows/scripts/`.

## Waiting on Andrew
1. **The lab sitting:** four modes, about 10 minutes each. The sheet is `/home/andrew/Projects/scrapkeep-worktrees/core-loop-v3/artifacts/local/LAB-SITTING.md`; launch with `scrapkeep core-loop-v3 -- --loop=drop --gun=hold`. His verdict becomes playtest entry 9, which decides the loop and starts wave B.
2. **Blind music pack 4** (optional, curiosity): `/home/andrew/Projects/scrapkeep/artifacts/local/music-ab-4/` Z1 to Z5, with the key in `.key.json`.

## Resume queue (in this order)

| # | Unit | Branch, head | Done | Next |
| --- | --- | --- | --- | --- |
| 1 | M0 delivered-damage ledger | `proto/core-loop-v3-m0` 4237a8a | Merged v3. drops_to_break now counts `warden_drop_landed` (one per landing) and `warden_slam_hits` is separate. The report's null crash is fixed. | Independent verify (brief: `m0-finish-*.js`, VERIFY), then merge into v3 and rerun smoke. |
| 2 | ACE music in the game | `proto/core-loop-v3-acemusic` 7772dad | Built. The stem sequencer from the PoC; `--music=ace`, `--breath=raw|hard|gentle`; a pause-menu Breath row; the Warden break as a directed set piece; synth fallback. | Verifier plus the audio-timing review (brief: `ace-music-in-game-*.js`, VERIFY and REVIEW), then merge and let Andrew play it. Assets are git-ignored under `assets/music_ace/`; rebuild them with `tools/ace/package_music.py`. |
| 3 | E1 telegraph perf plus readable density | `proto/core-loop-v3-e1` 51ace3b | Design `design-v3/E1-DENSITY.md` (1a7b54d): static telegraphs, a stencil fill union, the kill-pop budget. The perf bench is merged. | Build, verify and review per the doc (brief: `e1-telegraph-perf-and-density-*.js`, BUILD onward). Target: native s3 p99 at least 10 ms lower with the look unchanged. F1a (`proto/core-loop-v3-f1a`) was rejected; its findings are in `core-loop-v3-f1a/artifacts/local/f1a-review-findings.json`. |
| 4 | Pilot reactions | visual clone b6a595e | Four clips (big_cheer 2.8 s, wince 0.5 s, slump 1.5 s, phew 0.8 s) for all three pilots, plus a side-on Sable point. `pilot_reactions_test` passes. | Rerun the full smoke (stopped at 88 PASS, 0 FAIL). Time perf on hidden workspace 10; don't use `run_host.py perf`, which opens a window on Andrew's screen. Merge the clone into v3 when the look pass and v3 align. |
| 5 | Look pass 3 (Codex) | visual clone | Pass 2 (d9f1625) scored 52 to 62 against the 80 target. Draws p99 are 1,409 against the 1,389 cap. | (a) The lighting and post stack: warm sun, AO/GI, AgX, fog, a vivid sky; there's about 5 ms of GPU headroom. (b) Painted tileable textures from Codex imagegen. (c) Cut draws under the cap. The empty play floor is gameplay geometry, which belongs to wave C. |
| 6 | Perf E2 and E3 | after E1 | | One enemy snapshot per tick (about 1 ms), and HUD redraw on change (about 0.5 ms). See `perf-lab/ledger.md` on `proto/core-loop-v3-perf`. |

After the lab verdict comes wave B: one-page `DESIGN-V3.md`, archive the rest, and delete the losing loop mode and the v2 fallbacks.

## Rulings this session (all in ROADMAP or the design-principles memory)
- **Music is full ACE-Step.**
  - The screens only reject broken takes; Andrew's ear ranks. His pack-3 favourite was the planted "weak" raw take.
  - Judge music in play, where nuance gets lost moment to moment. Moments that carry game information must be unmistakable.
  - **Directed A-to-B set pieces** get composed, nuanced passages.
  - Parked: contraption flight times land on the downbeat.
- **Pilots react** to actions, achievements and failures. Length follows what the motion communicates, and poses must read from the rear chase camera.
- **The look target** is 80 to 90% of the concept art, in look and feel only. It must hold 60 FPS at 1080p on a mid-range PC; the dev-box proxy is CPU p99 ≤ 10 ms and GPU p99 ≤ 7 ms.

## Gotchas
- **Codex:**
  - Launch from inside the visual clone (`env -C <clone> node .../codex-companion.mjs task --background --write --fresh --model gpt-6-astra --effort high --cwd <clone> --prompt-file <f>`). Only that clone is a trusted Codex project.
  - Even there, the sandbox sometimes lacks the systemd user bus and the GPU. When that happens, run its prepared host stages from Claude.
  - Codex can't use git, so the coordinator commits.
  - Never add Codex trust entries without asking Andrew.
- **GPU:** every GPU job takes `flock /tmp/scrapkeep-gpu.lock` and waits while any process holds over 3 GB. ACE-Step peaks around 13 GB and TRELLIS at 13.3 GB on the 16 GB card.
- **Windows:** native Godot runs go through `claude-open` onto workspace 10, never Andrew's screen.
- **Licensing:**
  - Qwen-Image-2.1 is non-commercial, so it's not for shipped assets. Use Codex imagegen references.
  - TRELLIS v1 is MIT. Its trial is `proto/core-loop-v3-img3d` 829e549: props come out clean; the cliff reads as masonry and isn't proven.
- **Model routing:** commit c6d5f05 on main (session-scoped) pins Opus 5.5 at medium for `scrapkeep-writer-low` and `scrapkeep-explorer`. With Sonnet 5.5 out, confirm its model ID, then repin those two agents to it or revert c6d5f05. That's Andrew's call.
- **Andrew's hands (optional):** request DINOv3 access on Hugging Face (`facebook/dinov3-vitl16-pretrain-lvd1689m`), only if TRELLIS.2 is wanted.
- **Housekeeping noticed:** 25 stale `blender-mcp` server processes from the 3D-printing-hub project are running, some for 15 hours. They belong to another project, so they were left alone.
