# PR 962 attack marks (FX-29) on the PC

- `cover/`: `tools/mark_cover_capture.gd` on PR 962 head e5f85f07, RTX 4080 (Forward+), 1280x720, headless gamescope, sound off. Exit 0, 71 s. Nine PNGs (lane pending, lane live, ring pending; each in haze, clear, edges) and `cover.json`.
- `film/`: player's-eye film, skipper bot, seed 1, stage 1, on PR 962 head b48a4516, once each with `--telegraph=haze`, `clear` and `edges`. RTX 4080, 1920x1080, headless gamescope, sound off. All three exit 0, 212 frames each. Four matching frames per look from the Reactor Warden fight (the three runs line up within 0.1 s), plus each run's `film.ndjson`.

The cover numbers come from e5f85f07; the films from b48a4516, which adds review fixes to the mark shader's depth pull and fence fade.

- `cover-e1c2885b/`: the same cover capture rerun on PR 962 head e1c2885b, RTX 4080, 1280x720, exit 0, 102 s.
- `cover-e1c2885b-run2/`, `cover-e1c2885b-run3/`: two more runs of the same capture on e1c2885b, exit 0, 49 s each, for a median of three.
