# HF-07a-A1 independent review

Reviewer: fresh scrapkeep-reviewer-medium (claude-opus-5, effort high pinned by agent definition after EV-0149; self-described "Opus 5 (1M context)"; CLAUDE_EFFORT not exposed). Reviewed identity: worktree /home/andrew/Projects/scrapkeep-wt-HF-07a, branch wt/HF-07a, head b2926a6e9cf782042cd7674b837b473cc7885d73, base 5f459b0407dce4fbb060a1a8421a00fb8bb5e0c1. Verbatim report follows.

---

**PASS+NOTES** — evidence level 3 (walked the artifact and every named source file by line in the worktree), with level 4 for command outcomes (all check exit codes and the 841/841 result rest on coordinator receipts).

Card matched: `BACKLOG.md:466-495` in the worktree is HF-07a revision 1 and is byte-identical in content to the exact card in `assignment.md:23-50`.

## Blocking findings

None.

## Check-by-check result

**1. DoD 1 — met.** 60 rows in six groups (`HF-07a-save-envelope.md:75-80, 88-90, 98-100, 108-148, 156-157, 165-169`); 6/3/3/41/2/5 in both the Markdown and the CSV. Every row carries type, presence, owner module + record, produced-from, projection group, source and question cells. Owners verified against `HF-03a-module-map.md:35` and `:49`. Sampled well over fifteen source cells (`TADR-004:24-34, 20, 42`; `BIBLE.md:460-465, 570-602`; `HF-05:18-58`; `HF-03a:45-96`; `S0-07:20-45`; `DECISION-REGISTER.md:49-50`); no misattribution. The HF-05:8 gotcha was not propagated (`md:8`, `md:123` cite TADR-003 line 41 directly). All 14 HF-06b `json-projection` rows and all 15 projection groups appear. The packet's line number was wrong: the reserved `checkpoint.device-carry-over` row is `HF-06b:63`, which the section cites at `md:11` and `md:144`.

**2. DoD 2 — met.** Six explicit anchors at `md:69, 82, 92, 102, 150, 159`, distinct from heading auto-slugs, cited as a consumer contract at `md:25`. Naming rule at `md:23`. Hand-checked parity on first, last and thirteen middle rows: cell for cell after backtick removal, identical order.

**3. DoD 3 — met.** Q-E09 on `profile.discoveries`, `profile.recipes`, `profile.unlocks` (`md:88-90`), all `array of id-string`. Q-P16 on `run.checkpoint.interruption` (`md:148`, `object or null`) and `run.lifecycle.revival_spent` (`md:156`). Rejected-key table (`md:174-182`) is substantive. The envelope is exactly six keys (`md:172`), no envelope row carries a question tag.

**4. The writer's five decisions — all inside the card and TADR-004.** Int-with-boundary-cast (`md:35, 43`) is exactly the authority `HF-06b:34` delegates, resting on `S0-07:45`. Rng state as `string` (`md:140`) follows. Preferences carrying only `schema_version` (`md:165, 184`) follows `TADR-004:24` and `:28`. The separate run-identity group is `TADR-004:24` and `HF-06b:59`. `instance_id` (`md:115`) is forced by `BIBLE.md:460` and `:465`. `mount_id` is the one extension; see N2.

**5. Prohibitions and headings — clean.** No `retain_revision` or `read_initial_snapshot`. HF-06b, HF-07b, HF-08, HF-09, TH-11 and TH-21 cited with exact BACKLOG headings. Seven required headings in order at `md:3, 17, 200, 231, 241, 247, 255`. No engine behavior claimed (`md:202`, `md:255-257`); S0-07 receipts read, not rerun (`md:196`).

**6. check_envelope.py coverage** — mostly accurate, three overstatements; see N6.

## Accepted notes

**N1.** The section never names, links or specifies its own machine-readable copy (only `md:11` for HF-06b's CSV and `md:249, 251` for procedure). Compare `HF-06b:189-191`. Not a DoD failure; consumers have no in-document pointer or authority rule if the two diverge. Recommend one subsection before integration.

**N2.** `md:118-119` presumes named equipment positions exist (`equipped` ordered by `mount_id`, required `id-string`). No cited source establishes position-based equipping (`BIBLE.md:594, 596`, `HF-05:56`, `HF-06b:143`). `md:237` records the derived question but not the prior one. One sentence in `md:237` or `md:119` would close it.

**N3.** Three intermediate aggregate objects (`build`, `equipment`, `companion`) carry no row while `profile`, `run`, `run.checkpoint`, `run.lifecycle` do (`md:79, 80, 99, 100`). Shape is determinable from `md:50`; treatment internally inconsistent. `check_envelope.py:264` guards only the root key set.

**N4.** The S8 table enumerates Q-E09's two poles, not the mixed per-fact answer `BACKLOG.md:2730` literally asks; the shape still holds per `md:88`, `md:233`, `md:176`. Presentational.

**N5.** `md:169-170`: the preferences table's last row is followed by a heading with no blank line. Renders; `check:docs` exit 0.

**N6.** Of the 841 assertions, roughly 21 can never fail (`check_envelope.py:279` asserts True; `:225-226` compares two script constants). `md:251`'s "no engine token in any cell" scans only field, type and meaning (`:258-259`); its preferences claim tests type and name only (`:329-332`); cross-file link fragments are existence-checked only (`:369-371`). The 28 `LINE_CLAIMS` cover a subset of citations; the remainder verified by hand this session and all hold. What the pass does establish is accurate: headings, anchors, 60 rows, three attributes per row, closed vocabularies, six envelope keys, numerics confined to four int fields, rng string, group-prefix naming, HF-06b coverage, question sets and shapes, md/csv parity, dependency and receipt hashes, card bytes.

**N7.** Admitting this section fires S0-07's own re-verification trigger at `docs/tech/proofs/S0-07-save-owner.md:116`; the section consumes its inbound trigger but does not flag the reciprocal one. The sections index needs the HF-07a entry plus CSV link at integration.
