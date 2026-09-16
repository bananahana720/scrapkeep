# TH-18 assignment A2 (changes requested)

GOAL: Revise TH-18 revision 1 so no coverage cell or coverage rule fixes any part of a binding layout that Q-P30 owns, and correct the review notes below, leaving every other passed item intact.

SCOPE: /home/andrew/Projects/scrapkeep-wt-TH-18, branch wt/TH-18, building on your A1 candidate 7f42500061a4761690f32e3ab26ec22d1895ce53 (base bb97c4111d1e7b2dd40cae575eccde17878b07c5). Exclusive lease TH-18-L2, attempt TH-18-A2, the second of at most three attempts. Permitted files unchanged: docs/tech/sections/TH-18-input-integration.md; artifacts/local/tasks/TH-18/ (ignored, receipts), including your paper check.

CONTEXT: Independent review R1 (scrapkeep-reviewer-medium, claude-opus-5 high) returned FAIL with one blocking finding and seven notes; it is at artifacts/handoff-8-2026-09-16/tasks/TH-18/review-R1.md in the main checkout /home/andrew/Projects/scrapkeep. The coordinator confirmed B1 at your lines 62 to 66 and 84 (for example IN-04 allows only IK-03 on keyboard and mouse and IN-05 only IK-02) against TH-12 UP-15 at line 271 (controller device set, mappings, glyphs and remapping unset under Q-P30), PD-02 IP-02 line 129, TH-02 MP-24 line 238 and your own line 31. The traces, DL-02, FC-02, DL-08's explicit gate, the headings and the hardware rows passed and must not regress. Engine facts still come only from Context7 receipts (/websites/godotengine_en_4_7), at most three queries per question.

REQUIRED CHANGES:
1. B1 (blocking). In every coverage cell list every physical action kind that can produce the signal the intent needs: held or edge intents take IK-02 and IK-03 on keyboard and mouse and IK-07 and IK-08 on controller; discrete directions add IK-09; aim takes IK-01 or IK-06. Route any narrower choice to DP-07 under Q-P30. Reduce IC-03 to the consumed-press rule its sources state (HF-04a lines 87 and 90, TH-12 FI-04 line 135), or route the one-control-one-intent rule to DP-07.
2. N1. Name the owner that stops un-re-armed or unfocused input before it reaches Presentation (InputAdapter under its HF-03a and HF-03b rows, since Presentation has no edge to InputAdapter at HF-03b line 52), and add a parameter row or native test for the engine mechanism that was not retrieved.
3. N2. State explicitly how II-02's F-CONTROL focus observation refines TH-01 IF-33 and TH-12 UI-19's F-INPUT `sample_input` classification, or reclassify it to match.
4. N3. Extend FC-08 to RL3, RL7, RL8 and Held (TH-01 IF-10 admits O1 at RL3, RL7 and RL8) and include O1 where it requires neutral re-arm.
5. N4. Carry DL-08's implementation gate into the DA.3 and DA.11 gate cells, and list the HF-04a callback-family revision as a requested shared-file change in your handoff.
6. N5. Route DP-26 (vibration) and DP-13 and DP-24 to questions whose BACKLOG text actually covers them, or record the missing question as a proposed protocol.
7. N6. Scope line 288's definition of `tick` to the trace rows it describes.
8. Paper check. Add assertions that no coverage cell omits a kind able to produce the intent's signal class (the check that would have caught B1), that DL-02's loss-is-not-release rule holds in every trace step that loses a device, and that Sources citations written as "ID at line N" resolve. Keep the existing negative controls and add one that narrows a coverage cell.

VERIFY: In the worktree: npm run check:scope -- bb97c4111d1e7b2dd40cae575eccde17878b07c5 <candidate> --no-build; npm run check:docs; npm run check:project; npm run check:drift (no line for your file); your revised paper check with --out under artifacts/local/tasks/TH-18/. Record exit codes and counts. The coordinator reruns everything and a fresh reviewer reads the revision.

TIMEBOX: Checkpoint at handoff. Target 40 minutes; reassess from evidence.

FORBIDDEN: As A1: no edits outside the permitted files; no controller layout, dead-zone, sensitivity or repeat value, supported-device list or hardware qualification claim; no answer to Q-P30 or Q-P32; no builds, no native or browser execution, no push, no rebase, no touching main. If a change needs an architecture or product choice, stop and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/TH-18/.

REPORT: Commit only the permitted file on your branch and leave the tracked worktree clean. Report the new candidate SHA, changed paths, section sha256, each required change item by item with line references, commands with exit codes, paper-check counts, CLAUDE_EFFORT, the requested HF-04a shared-file change, deviations, and state explicitly that you have stopped.
