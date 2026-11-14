---
name: alpha-coordinator-handoff
description: "START HERE for Scrapkeep: since 2026-11-10 one local Claude Code session on this PC is coordinator and Gate (ruling cs, World 1 fully polished before the sitting); plan, scratch paths and resume rules"
metadata:
  node_type: memory
  type: project
  originSessionId: 1e69038b-db24-4bab-b00e-3960de210913
  modified: 2026-11-11T14:25:22.794Z
---

**Since 10 Nov 2026 (about 16:30Z) coordination is local again.** Andrew switched to his alt account and asked this PC's Claude Code session to run long in A mode and "finish the world 1 sprint". He ruled what done means: **World 1 fully polished before he plays** (ruling cs in `project-guide/handoff/DECISIONS.md`). The local session is coordinator and Gate. The claude.ai project "Scrapkeep" (other account) coordinated from 23 Oct to 10 Nov and was told to stop on board #738.

- Approved plan: `~/.claude/plans/hello-we-changed-accounts-ethereal-whale.md`, re-planned on 10 Nov to six waves (34 to 39) after Andrew added three directions: a map standard with a fast check per point, difficulty tuned harder and never easier (kiting and steamrolling), and seamless stage hand-overs. He vetoed none of the seven calls on the one-page plan (https://claude.ai/artifact/2KJGo8MUxgv6XqwSgqRQuD); they are rulings ct to cw. Wave 36 builds the measuring tools, 37 the difficulty changes, 38 the hand-overs, 39 the sitting build. S4 arrivals on the grid stays parked.
- Since 11 Nov 2026 (ruling cy) a promotion runs the wave gate, not the full gate: node suite, every non-bot test, and the bot and band tests the wave's changes reach, tallied with `node scripts/gate/tally.mjs --wave --plan <plan>`. The full `pc.mjs` run is the release gate, once per sprint on the head the sitting build is cut from. The sprint order changed with it: polish waves first (37 one ride and bugs, 38 polish), then the parked difficulty stack, the release gate, the sitting build. See [[fast-focused-tests-cloud-cpu]].
- Since 11 Nov 2026 (ruling cz) every board post, receipt, brief, report and hand-off is written for a reader with no context, by `project-guide/handoff/COMMS.md`. A cloud session cannot read this PC's disk, so before going quiet publish the session log, briefs and evidence with `~/scratch/world1/w37/publish-cloud.sh` to a `scratch/coordinator-notes-<date>` branch, open a draft pull request with a receipt for each built unit, and post the hand-off on the wave board. See [[cloud-lanes-github-bus]].
- To resume: read the last dated section of `~/scratch/world1/NOTES.md` and the newest file under `artifacts/local/handoff-*/HANDOFF.md` in the repo, then the live board.
- Live state is not kept here: read `~/scratch/world1/NOTES.md` (session log with heads, task ids, briefs and what is owed) and the current wave board named in STATE.md.
- The gate on this PC is one command since wave 35: `node scripts/gate/pc.mjs run --wave N --head <40-char sha> --budget 16 --base <last gate's receipts>` from a checkout at that head; wrapper `~/scratch/gate/run-w<N>.sh`, receipts `~/scratch/gate/w<N>-<head8>/`, published to `scratch/gate-receipts-w<N>-<head8>` with `~/scratch/gate/publish-receipts.sh`. The hand lane scripts below are the fallback.
- Records of truth are in the repo: `project-guide/handoff/` START-HERE, STATE (Wave facts table names the live board), DECISIONS, GATE, PLAY-FINDINGS.tsv, KNOWN-FAILING.tsv. The repo DECISIONS.md is the only register; the Claude Doc and `/mnt/project-files` copies are frozen at ruling cr.
- `/mnt/project-files` does not exist on the PC. Andrew ruled: rebuild receipts locally. Gate scripts, env and lane runners are in `~/scratch/gate/` (`env.sh`, `lane-shard.sh`, `lane-alone.sh`, `lane-challenge.sh`), lane logs in `~/scratch/gate/logs/<lane>/lane.log`, base receipts under `~/scratch/gate/base-45691e94/`. Coordinator briefs and notes: `~/scratch/world1/`.
- Authority: [[standing-merge-authority]] carries to the local session. Decisions to Andrew: [[creative-charge-alpha]] (pick a default, give a veto page), [[stakeholder-decision-pitch]].
- Dates: weekly sweep due 2026-11-15; all 21 KNOWN-FAILING rows fall due 2026-11-23.

**Why:** coordinators hand off across resets and accounts; only what is on GitHub and disk survives.

**How to apply:**
- Re-check every SHA with `git ls-remote origin` before stacking or promoting. Andrew was not sure the old project threads had stopped, so a stage head that moved without this session moving it is a collision: stop and tell him.
- This checkout's `main` was 864 commits stale at takeover. Fast-forward it before reading repo docs, or read from `origin/<stage>`.
- Run Godot only with a scratch `XDG_DATA_HOME` (`~/scratch/gate/env.sh` or `~/scratch/bin/godot-safe`); never touch `~/.local/share/godot/app_userdata/core-loop`.
- Gate worktrees keep no packed Oggs on purpose, so head and base both play the synth band, as the cloud gates did. Do not run stems-sync in a gate worktree.
- Frame timing only on an idle 4080, under `flock ~/scratch/w18/gates/timing.lock`, when no gate lane runs and Andrew is away (`~/scratch/w33facts/away.sh`, `wallpaper-on.sh`).
- Check the clock (`date -u`) before writing a time into a record; on 10 Nov the session guessed times 30 minutes late and had to correct the board and DECISIONS.
- After a second review FAIL in one class, sweep the class with one grep instead of patching the named lines.
- Frame a close as "ready for your verdict", never "alpha ready" ([[fun-gate-before-alpha]]).
- Before stacking, check each PR against the last gate's drop list; a PASS receipt older than a bisect drop is void.

History before 10 Nov (PC coordinator 18 to 23 Oct, the 22 Oct housekeeping, the wave 17 and 18 resume states) is in git history of the handoff docs and in `~/scratch/memory-backup-2026-10-22/`.
