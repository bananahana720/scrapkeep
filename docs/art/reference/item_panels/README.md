# Grey item panels: reference sheets

Eleven of the twelve panels for card IL-01 have two sheets each, drawn on 23 Oct from [PROMPTS.md](PROMPTS.md) through `tools/refsheets`. `<panel>-details.jpg` is the modelling reference: face, edge and back at one scale, the moving part, and its two states. `<panel>-onball.jpg` shows placement on the 1.84 m ball. Each folder's REVIEW.md is the image engine's own check.

Lane review (looked at every sheet against the prompts):

- Details sheets: all eleven match their spec in parts, states and grey-tier colours. Use these for the kit plates.
- On-ball sheets: scale and placement are right, but only the hull tile and vent louvre drew the five-panel stack, and most show two angles, not three. At this size the stat silhouettes read weakly from a distance. The modeller should check distance reads in Godot, not from these sheets.
- Silhouettes are this lane's proposal from each panel's stat, not an approved board. Treat them as inferred until a board or Andrew says otherwise.
- `panel_range_sight` has no sheets: the image service refused it as "violence" three times. Its prompt stays in PROMPTS.md; it is not retried with reworded text.
