# Sable title intro: storyboard stills

Rough Blender Cycles stills for the eleven shots in [TITLE-INTROS.md](../../TITLE-INTROS.md), rendered from the game's own glb models with a Freestyle ink pass (originally published as an HTML review artifact with captions, name cards, and sound words overlaid on the stills).

```sh
# from the repo root; shots are comma-separated, quality is draft (480x270) or final (960x540)
blender -b -P sketches/core-loop/design-v3/storyboards/intro-sable/render_shots.py -- 01,02,03 final
```

Output lands in `artifacts/local/intro-sable/`, which git ignores. A final shot takes about a minute on four CPU cores.

Known limits: `shell_sable`, `shell_rivet` and `shell_kest` carry their own pilot, so a posed pilot (shot 8) and Tarn and Tally use a stand-in glass sphere. Shot 8b renders with a transparent background so the page can draw it as a silhouette.
