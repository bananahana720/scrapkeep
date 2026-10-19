# Music brief specs

One JSON file per composition brief, `<take-id>.json`, checked by `npm run check:briefs` (`scripts/brief-check.mjs`). The prose brief stays the human document; the spec holds the numbers a reviewer would otherwise recompute by hand. The 12 radio-remake takes are committed here as `take-*.json`.

## Fields

| Field | Meaning |
| --- | --- |
| `id`, `station` | take id (matches the file name) and its station |
| `seconds` | planned take length |
| `take_bpm`, `beats_per_bar` | the take's tempo and meter |
| `phrase_bars` | bars per phrase, default 4 |
| `grid_origin_s` | take-timeline second of the first bar line, default 0 |
| `pick` | `{file, root, sha256, recorded_by_measurement, native_bpm, native_seconds, semitone_shift}`. `root` is `repo` (relative to the repo root), `music_direction` (relative to `~/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/`, override with `BRIEF_CHECK_MUSIC_DIR`) or `pack` (relative to `sketches/core-loop/assets/music_ace/`). `native_seconds` is the length measured at the native tempo. Set `recorded_by_measurement: true` when the file lives outside the repo and the hash was taken by hand. |
| `sources` | `[{part, file?, root?, from_s, to_s, pick_from_s?, action, loop?, gap?, note}]`. `part` is `drums`, `bass`, `other` or `guide`. `from_s`/`to_s` are take-timeline seconds. `action` is `use` or `mute`. A source inherits the pick's `root` unless it names its own; `file` is optional (the span then plays the pick). `pick_from_s` is where in the pick, in tempo-stretched seconds, the span starts reading; it defaults to `from_s` and is required on a `use` span with `from_s` other than 0 (else `PICK_FROM_MISSING`). A `guide` span is not pick material. A `use` source with part `other` also needs `guide_matches_pick`: `{from_bar, to_bar}` (bars counted from 0 at `grid_origin_s`) or `{from_s, to_s}` (take seconds), the span where the guide plays the pick's lead bar for bar; the source's `from_s`..`to_s` must lie inside it (within `tolerance_s`), else `OTHER_STEM_LEAD`. The pick's `other` stem carries its own lead melody, so the default stems are drums and bass. `loop` lets a span run past the pick. `gap: true` marks a deliberate hole in that part's coverage (it silences `SPAN_HOLE` for the part) and never skips the length check. |
| `sections` | `[{name, start_s, end_s}]` |
| `journey` | `[{section, move}]`, the motif journey, one entry per section |
| `edits` | take-timeline seconds that are cut or join points |
| `tolerance_s` | default 0.12 |

## Findings

| Code | Raised when |
| --- | --- |
| `FILE_MISSING` | a pick or source file is not on disk under its root |
| `HASH_MISMATCH` | the file's sha256 differs from the spec's `sha256`, or from `STEMS.sha256` when the file is under `assets/music_ace` |
| `LENGTH_RAW` | a non-`guide` `use` span reads beyond the stretched pick: `pick_from_s + (to_s - from_s) > native_seconds * native_bpm / take_bpm + tolerance_s`, unless the source has `loop`; `guide` spans are exempt; or ffprobe's length of the pick differs from `native_seconds` by more than 0.25 s. A semitone shift alone does not change length. |
| `PICK_FROM_MISSING` | a non-`guide`, non-`loop` `use` span has `from_s` other than 0 and no `pick_from_s`, so the length check would guess where it starts in the pick |
| `OFF_PHRASE` | an edit or a span start/end is more than `tolerance_s` from the nearest `grid_origin_s + n * phrase_bars * beats_per_bar * 60 / take_bpm` |
| `SECTIONS_SUM` | sections do not chain from 0 with no gap or overlap, the last does not end at `seconds`, or the journey does not list every section once, in order |
| `SPAN_HOLE` | a part (drums, bass, other, or any part used) is uncovered for more than one bar, at the start, between spans or up to `seconds`. A `mute` span covers. A `guide only` note on any source exempts the spec. `gap: true` on a span of the part exempts that part. |
| `OTHER_STEM_LEAD` | a `use` source with part `other` has no `guide_matches_pick`, or runs outside it. The pick's `other` stem holds its lead melody, so wherever the guide plays a different line the source would hold two leads. `mute` spans and the other parts are not affected. |
| `BAD_SPEC` | a required field is missing or the JSON is invalid |
| `unchecked` | not a finding: the file's root is unavailable here (the `pack` root counts as available only when the first `STEMS.sha256` entry exists on disk, since the Oggs are gitignored), or ffprobe could not read it. Never a pass; `--strict` exits 2. |

## Run

```
node scripts/brief-check.mjs [--dir <specs dir>] [--strict] [--json]
```

Exit 1 on any finding, 2 for `unchecked` under `--strict`, 0 clean. The fixtures in `tests/fixtures/brief-check/` hold a clean spec and a planted bad one (a wrong file, an unstretched length, an off-phrase span; the `OTHER_STEM_LEAD` control is planted in the tests); the bad one must keep failing before a clean result on real briefs counts.
