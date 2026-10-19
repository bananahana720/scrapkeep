# Music brief specs

One JSON file per composition brief, `<take-id>.json`, checked by `npm run check:briefs` (`scripts/brief-check.mjs`). The prose brief stays the human document; the spec holds the numbers a reviewer would otherwise recompute by hand. No real specs are committed yet: the 12 radio-remake briefs do not yet give stem paths or hashes, so a later step converts them.

## Fields

| Field | Meaning |
| --- | --- |
| `id`, `station` | take id (matches the file name) and its station |
| `seconds` | planned take length |
| `take_bpm`, `beats_per_bar` | the take's tempo and meter |
| `phrase_bars` | bars per phrase, default 4 |
| `grid_origin_s` | take-timeline second of the first bar line, default 0 |
| `pick` | `{file, root, sha256, recorded_by_measurement, native_bpm, native_seconds, semitone_shift}`. `root` is `repo` (relative to the repo root), `music_direction` (relative to `~/Music/Scrapkeep-sound-direction/sound-bible-2026-10-16/`, override with `BRIEF_CHECK_MUSIC_DIR`) or `pack` (relative to `sketches/core-loop/assets/music_ace/`). `native_seconds` is the length measured at the native tempo. Set `recorded_by_measurement: true` when the file lives outside the repo and the hash was taken by hand. |
| `sources` | `[{part, file?, root?, from_s, to_s, action, loop?, gap?, note}]`. `part` is `drums`, `bass`, `other` or `guide`. `from_s`/`to_s` are take-timeline seconds. `action` is `use` or `mute`. A source inherits the pick's `root` unless it names its own; `file` is optional (the span then plays the pick). |
| `sections` | `[{name, start_s, end_s}]` |
| `journey` | `[{section, move}]`, the motif journey, one entry per section |
| `edits` | take-timeline seconds that are cut or join points |
| `tolerance_s` | default 0.12 |

## Findings

| Code | Raised when |
| --- | --- |
| `FILE_MISSING` | a pick or source file is not on disk under its root |
| `HASH_MISMATCH` | the file's sha256 differs from the spec's `sha256`, or from `STEMS.sha256` when the file is under `assets/music_ace` |
| `LENGTH_RAW` | a `use` span ends beyond `native_seconds * native_bpm / take_bpm` (plus tolerance) unless the source has `loop` or `gap`; or ffprobe's length of the pick differs from `native_seconds` by more than 0.25 s. A semitone shift alone does not change length. |
| `OFF_PHRASE` | an edit or a span start/end is more than `tolerance_s` from the nearest `grid_origin_s + n * phrase_bars * beats_per_bar * 60 / take_bpm` |
| `SECTIONS_SUM` | sections do not chain from 0 with no gap or overlap, the last does not end at `seconds`, or the journey does not list every section once, in order |
| `SPAN_HOLE` | a part (drums, bass, other, or any part used) is uncovered for more than one bar, at the start, between spans or up to `seconds`. A `mute` span covers. A `guide only` note on any source exempts the spec. |
| `BAD_SPEC` | a required field is missing or the JSON is invalid |
| `unchecked` | not a finding: the file's root is unavailable here (the `pack` root counts as available only when the first `STEMS.sha256` entry exists on disk, since the Oggs are gitignored), or ffprobe could not read it. Never a pass; `--strict` exits 2. |

## Run

```
node scripts/brief-check.mjs [--dir <specs dir>] [--strict] [--json]
```

Exit 1 on any finding, 2 for `unchecked` under `--strict`, 0 clean. The fixtures in `tests/fixtures/brief-check/` hold a clean spec and a planted bad one (a wrong file, an unstretched length, an off-phrase span); the bad one must keep failing before a clean result on real briefs counts.
