---
name: cloud-lanes-github-bus
description: "How Scrapkeep cloud lanes work (env scrap, cap 7, GitHub PR comments and the wave board as the bus); since 2026-11-10 they are the exception, used only when the PC saturates"
metadata:
  node_type: memory
  type: project
  originSessionId: 4a2277c3-040b-4307-a006-0aaff95dc0a3
  modified: 2026-11-10T22:09:58.162Z
---

Andrew (2026-10-18): hardware must never be the bottleneck. Cloud sessions, each in its own sandbox, act as sub-coordinators that fan out their own agents and Workflows; the local coordinator keeps the workflow graph, test dependencies and promotion in sync. He chose a cap of **4 cloud lanes** at once: Gate + staging, Systems, World (Blender), Perf. Revisit after wave 17's spend is measured.

**Why:** the cloud gave Godot and Blender work its own compute; 12+ parallel threads is what used up the old account.

**How to apply:**
- Start lanes with `start_session` `target: "cloud"`, environment `scrap`. Briefs use `project-guide/coord/LANE-BRIEF.md` and carry the ownership table and his 18 Oct words authorizing their own agents and Workflows.
- Cloud sessions cannot message back and send no completion note. Every unit ends as a PR against `stage/alpha-w<N>` with a receipt comment (verdict, head SHA, commands, test counts). Blockers, id claims and GPU requests go on the wave's "Wave board" GitHub issue. Read lanes with `list_events` and `gh`. The coordinator can push to a cloud lane directly: `SendMessage` to its session name from `ListAgents` is delivered one way (measured 2026-10-18), so a reply to a lane goes both on the board and as a direct message.
- Measured 2026-10-18/19: `ListAgents` shows a cloud lane "idle" between turns even while its sub-agents build; judge progress by board posts and branch pushes, since this app cannot list cloud sessions or read their transcripts. A cloud start can sit "pending" for hours; replace it. A turn started by an automated event (monitor, peer message) cannot start sessions; it needs Andrew's typed words, so carry a standing ask forward.
- Andrew 2026-10-19: keep lanes going, start new ones when a bucket finishes, pull work forward from oversized later waves. A CPU-bound cloud lane (load 15 on 4 vCPU) sheds work to a local PC lane (32 threads) rather than adding agents to its own box.
- Cloud perf numbers never count; GPU proofs go to the PC queue ([[pc-gpu-rules]]).
- More than 6 Godot lanes on a 4 vCPU cloud box cause mass timeouts; band sweeps can OOM, so rerun a 300 s or timeout row alone before calling it red.
Related: [[alpha-coordinator-handoff]].

**2026-10-19:** Andrew raised the cap to 6 ("cloud is free compute, divide and conquer") and added the Dressing lane (lived-in prop kits per park, hero props up to about 20k tris with LODs) and the Ambient life lane (critters and locals). Container CPU is free, but each cloud session's model turns still count toward the weekly Claude limit, so check the conductor budget line before adding more.
**2026-11-10 (alt account, ruling cs): cloud lanes are no longer the default.** One local session on the PC is coordinator and Gate; the gate and the writers' checks run on the PC, and a cloud session is added only when the PC saturates and only for a job that compares with nothing on the PC ([[fast-focused-tests-cloud-cpu]]). Two cloud sessions started that day (comparison bands, red team) produced no branch and no board comment in over 75 minutes, so the PC did both jobs; treat a cloud job as a bonus cross-check until one reports. The old account's lanes cannot be listed from the alt account; read their traces on GitHub. The "how to apply" list above still holds for any cloud lane that is started.

Later on 2026-10-19 the cap went to 7 for the Challenge lane (Souls-like difficulty, skill-band bots, replay ladder), which took #104 from Perf.
