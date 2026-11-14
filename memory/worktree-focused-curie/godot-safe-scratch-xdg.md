---
name: godot-safe-scratch-xdg
description: PC Godot runs go through ~/scratch/bin/godot-safe, which refuses without XDG_DATA_HOME under ~/scratch; a bare parse check once wrote into Andrew's real logs
metadata:
  type: feedback
---

On 2026-11-10 a film writer ran `godot --headless --check-only` twice without scratch XDG; it rotated logs in Andrew's real ~/.local/share/godot/app_userdata/core-loop/logs/ (save untouched). The coordinator said: do not restore or tidy his folder; make scratch XDG impossible to miss.

**Why:** every Godot invocation, even a parse check, writes user://logs; only XDG_DATA_HOME keeps it off his real profile.
**How to apply:** every brief names `/home/andrew/scratch/bin/godot-safe` (exits 97 unless realpath of XDG_DATA_HOME is under /home/andrew/scratch) instead of the raw `/home/andrew/scratch/w18/gpu4080/bin/godot`. Queued jobs and old scripts still call the raw binary and set XDG themselves; swapping the raw path is a guard change on queued jobs, so ask via the coordinator first ([[ask-before-changing-run-guards]]).
