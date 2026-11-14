# Verify-web lessons

## Lessons

- **VWB-01** · status: provisional · since: 2026-11-13 · origin: the Sitting Kit server's defaults
  The kit saves to one fixed file by default, the one the coordinator reads after Andrew's sitting, and the usual ports may already be in use by Andrew or another session. A proof starts its own servers on its own ports and gives the kit a scratch verdicts file.
  Evidence: `project-guide/handoff/sitting-kit/serve.mjs` (`VERDICT_FILE`, `--port`, `--verdicts`).
  Overturned by: —
- **VWB-02** · status: provisional · since: 2026-11-13 · origin: the first drives of this skill
  The kit's verdict buttons are radio inputs laid over their labels, and its row of area buttons sticks to the top of the view. A click aimed at the label or at a control scrolled just under the sticky row never lands: click the control's own box after bringing it to the middle of the view.
  Evidence: the thread's proof run on stage/alpha-w40 6d4320b8, 13 November 2026; `project-guide/handoff/sitting-kit/index.html`.
  Overturned by: —

## Changelog

| Date | Change |
| --- | --- |
| 2026-11-13 | VWB-01 and VWB-02 added with the skill. |
