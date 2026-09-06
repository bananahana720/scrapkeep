# Independent review receipts

The coordinator transcribed these findings from fresh Astra reviewer responses. The reviewers operated no desktop inputs and made no source edits. Native trial reports own live outcomes. This is review separation, not model diversity.

## Cross-judge of initial candidates

A fresh Astra max judge ran candidate A's 56 tests and B's 59 tests, checked their diffs and source hashes, and scored both 8/10. The judge provisionally preferred A because B permanently stopped searching after four recovery attempts. It reproduced a shared target-expiry gap and A's reset of the observed-progress clock on escape completion. The admitted synthesis uses B's association/progress structure, removes its permanent stop, and checks expiry before matching. Initial source variants and their native timeout reports are retained under the candidate directories.

## First integration review: required correction

A fresh Astra high reviewer independently passed 65 focused tests and reproduced target expiry, unchanged observed-progress time, bounded phase expiry and all 12 saved-image framing measurements. It rejected integration because horizontal search alternated direction every six seconds. A 72-second targetless command probe accumulated only 15 net units. It also noted that a new target reset the in-flight episode number. The coordinator corrected both and preserved before/after evidence.

## Source review after correction

A second fresh Astra high reviewer found no required source fix. All 67 focused tests passed. Its retained-image probe passed seven images; the original result is retained beside this file. Additional 72-second targetless probes at 20, 120 and 490 ms observation cadence kept yaw nonnegative, accumulated 8404.8, 8343.6 and 7786.1 command units, and completed 12, 12 and 11 bounded escape episodes. Age-first target expiry passed independently.

Reviewed runtime hashes:

- policy.py: e5bbbe259c534e01c0c935f9d05c07c232818054406a5cc91cee443d4619a4fc
- observer.py: 20c92a3b28f31f119065123212d29f908c262f6db64221206bcc077f007ab216
- combat.py: 05f8efebfd3fe6756b42d8f40da36657a23a46f226db30d908809c841deac22f

The reviewer confirmed that recovery memory does not extend frame authority: release occurs at 500 ms, frames older than 750 ms are rejected, and each input lease is bounded by remaining frame authority. Escape completion does not fabricate visual progress. New targets preserve the in-flight episode number and side.

## Attention flags and disposition

- Native acceptance was pending at source review. The qualification README and actual reports must determine live acceptance; unit tests do not close it.
- Planning language in WORKPLAN and SYNTHESIS had become stale. The coordinator updated the source-correction and check results, and preserves earlier decision rows as history.
- Yaw regression tests integrate requested input at the current camera sensitivity. They do not observe a physical camera revolution.
- Framing is a scene-specific color heuristic. Scene change and target geometry are indirect evidence, not an obstacle map or world-position measurement.
- Comment review requested removal of two new module prose summaries; those were removed. Final source review found no new constraint or suppression comments.

## Review after straight relocation

A fresh Astra high reviewer compared the retained 67-test policy with the final relocation change and found no required source correction. Its independent 70-test run passed. Twenty additional inline scenarios checked original phase deadlines after late observation jumps, fresh target interruption, sky and ground correction, and menu/expired/stale/capture-error/active-limit priority while the policy was already relocating. It operated no native inputs.

The retained-image probe's deadline guard includes relocation, but its repeated-image scenarios trigger scene_unchanged escapes, which do not enter relocation. Dedicated tests and dynamic-scene policy probes establish that phase. Native acceptance remains owned by the relocation run report.

## Review after progressive relocation

A fresh Astra high reviewer independently passed all 71 tests and found no required source correction. At 20, 120 and 490 ms observation cadence, additional 120-second probes scheduled relocation durations of 2.5, 3.25, 4, 4.75 and 5 seconds, then stayed capped. Minimum observed scanning intervals afterward were 3.0, 3.0 and 3.43 seconds. Twenty late-completion cases preserved a scan interval beginning when completion was observed; twenty fresh-target cases interrupted relocation while preserving its episode number.

Reviewed policy SHA-256: 2f463fba2bc022c162befb21db0429952c852c5dd4831057c1f3847a03848447. Observer and combat hashes match the preceding review. Scheduled transitions take effect on fresh observations; these are not hard real-time actuation deadlines. Native batch acceptance was pending at review.

## Final stationary-scan admission

A fresh Astra high reviewer independently passed all 76 tests and found no required source fix. The reviewed policy hash is 4bf6006a49770f885a3314d524ab19f5ed8f34c17ca7d914b3f011d6bcb9c09b. A production combat-loop probe with four seconds of sky correction and a brief target began lost-target escape at 19.5 active seconds, after 14.1 accumulated search seconds. Relocation reset the scan budget. A near-complete scan supplied one aging capture: exactly one 500 ms lease was issued, stale perception failed, and inputs released without granting the remembered scan state new authority.

The reviewer inspected the completed three-trial report, matched each trial result and every recorded source hash, and confirmed won/won/lost, all pause checks passed, unchanged source/controller values and no cleanup errors. It inspected the matching interruption receipt: 0.264040 seconds, session removed, both owned processes no longer live. It did not operate the desktop independently.

Final Attention flags were to replace pending acceptance text, preserve historical decisions while adding a retained closeout row, and avoid three-win, general win-rate, world-coverage or human-play claims. Those documentation flags were resolved in the synthesis, workplan, qualification and decision trail. Explicit restart-check mode was disabled in this batch; earlier retained verification owns that path. The default seed of 42 is confirmed from ordinary game construction and reset source.

After this review, only report.py explanatory text changed to clarify asynchronous timing and live-seed limits. The final smoke receipt and source comparison cover that text-only difference; no gameplay policy, perception, flow or installed controller code changed.
