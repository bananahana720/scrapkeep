# Sable title intro: storyboard stills

Rough Blender Cycles stills for the eleven shots in [TITLE-INTROS.md](../../TITLE-INTROS.md), rendered from the game's own glb models with a Freestyle ink pass. Published for review at https://claude.ai/artifact/SP2Rcy3tzwhpwK3hcHAsBk, where captions, name cards and sound words are drawn over the stills in HTML.

```sh
# from the repo root; shots are comma-separated, quality is draft (480x270) or final (960x540)
blender -b -P sketches/core-loop/design-v3/storyboards/intro-sable/render_shots.py -- 01,02,03 final
```

Output lands in `artifacts/local/intro-sable/`, which git ignores. A final shot takes about a minute on four CPU cores.

Known limits: `shell_sable`, `shell_rivet` and `shell_kest` carry their own pilot, so a posed pilot (shot 8) and Tarn and Tally use a stand-in glass sphere. Shot 8b renders with a transparent background so the page can draw it as a silhouette.
