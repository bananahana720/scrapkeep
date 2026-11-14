---
name: tmp-tmpfs-quota
description: /tmp is a 32 GB RAM disk with a ~25 GB per-user quota; it stopped the wave twice (2026-10-11, 2026-10-12); keep bulk scratch on disk under ~/scratch/w<N>
metadata:
  node_type: memory
  type: project
  originSessionId: cabb58e4-73c1-4c8c-adc7-200746caa4da
  modified: 2026-10-12T18:07:08.662Z
---

`/tmp` on Andrew's machine is a 32 GB tmpfs, and user 1000 has a quota of about 25 GB on it.

- **2026-10-11:** wave-13 scratch under `/tmp/claude-1000` reached about 24 GB. Bash failed with EDQUOT and tool output was lost. Pruning twelve merged units freed 11 GB.
- **2026-10-12, about 18:00 UTC:** it filled again with about 15 Codex units running. Ten unit loops died (exit 14) and their writers or gates stopped mid-round. Each Codex round left 0.4–1.5 GB: exported trees, smoke roots, Godot XDG folders. Two writers also built full private repository copies there (about 1 GB each).

**Why:** pruning after merge is not enough when many rounds run at once, and Claude's own Bash output capture also lives on /tmp, so a full quota blinds the coordinator too (write listings to a disk file and Read it).

**How to apply:**
- Bulk run scratch lives on disk under `~/scratch/w<N>/`, never /tmp. The wave 13 Codex round tools (sol_run4, codex_gate2, unit_loop2) are retired with the Codex lane; copies are in `artifacts/local/alpha/push/w13/coordinator-tools/`.
- Codex's sandbox refuses a symlinked writable root (probe 2026-10-12), so Codex must get the disk path itself, via `--add-dir` and a brief copy with the round's /tmp path rewritten.
- Briefs forbid private repository copies and large writes elsewhere under /tmp.
- Still prune a merged unit's scratch, and run `df -h /tmp` at each wave boundary. See [[codex-image-boards]].
