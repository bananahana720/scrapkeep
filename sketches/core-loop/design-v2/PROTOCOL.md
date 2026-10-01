# Vision alignment protocol, core-loop v2

Andrew asked for this on 2026-09-27: a story, audio and design keeper, so every unit serves one vision without wasting time on check-ins.

## Roles

- **The coordinator** (the main session) is the only router. Writers never message each other. Every exchange goes through the coordinator, so writers keep disjoint files and uninterrupted focus.
- **The vision keeper** is one persistent agent (Fable 5.1 high), resumed at each checkpoint rather than kept running.
  - It owns `SOUND-STORY.md`: the audio identity and the narrative through-line.
  - It is the design authority on coherence across `DESIGN-V2.md` and `VISUAL-LANGUAGE.md`.
  - It edits only its own files. Everything else goes back as notes.
- **Writers** own their permitted files and decide inside them.

## The shared sources, read once at the start

Writers read these once, at the start of their task:

- `DESIGN-V2.md`: what the game does.
- `VISUAL-LANGUAGE.md`: how it looks.
- `SOUND-STORY.md`: how it sounds and what it means.
- `src/presentation/MUSIC-GEMS.md`: what Andrew already loves in the music. Never lose these.
- `src/core/event_kinds.gd`: the one table from which every event's colour, shape, sound, wording and priority are read.

## When a writer checks in mid-task

Only when one of these triggers fires. Otherwise it decides, logs the call in `DESIGN-NOTES.md` with the principle it serves, and keeps going.

1. **A seam change.** The decision changes something another unit consumes: an `event_kinds` row shape, the ability-slot contract, an icon id, a class-row field, a bus signal.
2. **A spec conflict.** The spec can't be built as written, or two spec sections contradict each other.
3. **An uncovered identity call.** A player-facing name, motif, sound family or lore fact that none of the three sources covers.

A check-in is one message to the coordinator: the trigger number, the question, the writer's recommended answer, and what it will do meanwhile. The writer keeps working on everything the question doesn't block.

## Every hand-back carries a vision delta

Alongside the usual report, a short list of every new player-facing fact the unit introduced:

- event rows and their sounds
- visual motifs
- names and wording
- timings the player will feel

## The alignment pass, once per wave

At each integration merge the coordinator resumes the vision keeper with:

- all the wave's vision deltas
- the merged branch's changed paths

The keeper returns alignment notes, grouped by owning unit, each marked **must** (it breaks the vision) or **could** (it would sharpen it). The coordinator routes the notes to the owners by resuming them; the mid-flight harmonize rule applies. The keeper also updates `SOUND-STORY.md` with anything the wave taught it.

Andrew's new direction lands the same way: the coordinator records it in the spec, the keeper folds it into its files at the next pass, and running writers harmonize after they hand back.

## What a check-in must not be

- a status ping
- an approval request for a decision inside the writer's own files
- a question the three sources already answer
