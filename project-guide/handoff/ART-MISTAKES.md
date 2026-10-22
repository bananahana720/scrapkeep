# Mistakes log

Andrew's rule, 21 Oct 2026 (DECISIONS section 10): every mistake caught by a reviewer, a test, a still or the agent itself gets one line here, so the next unit doesn't repeat it. It started for digital art and modeling, and any lane may log process mistakes too.

- Read this file before each unit, and name in the PR body the entries you checked.
- Append only. Add new lines at the bottom of the table and never edit or delete an old one. When two PRs both append, the merge keeps both sides.
- One line per mistake. The root cause says why it happened, not what happened. The rule is the check that would have caught it.

| Date | Lane | PR or unit | Mistake | Root cause | Rule that prevents it |
| --- | --- | --- | --- | --- | --- |
| 2026-10-21 | Coordinator | #231, #234 | Stacked two PRs that the last gate had dropped by bisect, then had to revert both (bb3b639c, a63d2cb6) | Trusted a PASS receipt that predated the drop. The intake did not read the drop list | Before stacking, check the last gate's drop list. A receipt older than a drop is void |
| 2026-10-21 | Coordinator | #222 ruling | Ruled "monster = class strictly above V" when V is the top class, so no build could earn the lift at the Waking or the Mind | Ruled without checking the enum's range (`run_state.gd` HEFT_CLASS_AT) | Before ruling on a threshold, read the scale it lives on and test the edge values |
| 2026-10-21 | Coordinator | #222 ruling | Took park Warden thresholds at stage entrance, where w1 reads 1.000 heft, so any scrap made a pilot a "monster" | Used the nearest available snapshot without asking when the fight happens | Measure a number at the moment it applies (Warden arrival), not at the nearest convenient snapshot |
| 2026-10-21 | World | #242 lane width | Called the park graph's LINE flag "the actual ride line"; it is one spawn-to-beacon spine and misses about half the routed rows | Named a mechanism from its label, not from reading `_line()` | Read the function before describing what a flag means |
| 2026-10-21 | Systems | #217 plate_press | Shipped a pack that no pilot could clear, and a swap of one member did not fix it | A cell that every pilot fails sits at the cap, so the 2x-median rule cannot see it. The pack also had no receipt | Every pack row runs the lab's WALL check, with a planted positive control, before it ships |
| 2026-10-21 | Music | row 7 export | The export was pointed at a stems folder that predated the heat remake, and it refused 8 takes | Reused an old path without checking its manifest against STEMS.sha256 | Check the stems folder against STEMS.sha256 before an export. Use `~/scratch/w18/music/ace-full` |
| 2026-10-19 | Dressing | crown placement | Ran audits outside the lock; two were OOM-killed (exit 137) | Treated the audit as light and did not read the audit.sh lock note | Run every park audit through audit.sh; never start a second Godot process beside it |
| 2026-10-21 | Dressing | crown low spots | `P()` ignored its `scale` argument, so low-ground spots came out 1.11 to 1.24 m tall and failed `low_ground` at every point | Wrote the helper for the chunky 1.15 to 1.3 scale and never tested an explicit scale; the fit script showed zero legal spots and my own debug run caught it | Test a helper with the non-default argument before building on it; check the manifest height times scale against LOW_GROUND_MAX_M |
| 2026-10-21 | Dressing | crown low spots | My fit script passed a file dict without `low_ground_rows`, and `expand()` reset the context's low rows, so every low spot failed `keepout` | Assumed the context object kept its settings across `expand()` | Read what a call mutates (`park_props.gd` expand line 526) before reusing a context across calls |
