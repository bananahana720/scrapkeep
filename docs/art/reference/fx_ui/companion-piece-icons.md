# Companion piece icons (purpose note)

Written before drawing. Concept only. Follows `sketches/core-loop/VISUAL-LANGUAGE.md` section 5 and the generator `sketches/core-loop/tools/icons/generate_icons.py`; the mistakes log (`project-guide/handoff/ART-MISTAKES.md`) was read first.

Where the marks show: the two socket marks in the companion panel and each piece row (`companion_panel.gd`), at 26 px. Today all six draw a fallback glyph borrowed from an ability. No board exists for these pieces; the families follow the icon sets named below, and `fx_ui-hud-moodboard.jpg` (flat bone glyph on charcoal) sets the register.

Family trait, readable without colour: the backplate shape. The two pieces of a family share it, so "One of each kind" can be read from the marks. The accent colour repeats the family but is never the only cue.

| Family | Backplate | Accent | Follows |
| --- | --- | --- | --- |
| Conductive primer | circle | mint (arc) | `el_arc`, `cls_sable` |
| Ram brace | rounded square | copper (Rivet's ram) | `cls_rivet`, `ab_*` slots |
| Escape corridor | hex nut | ice | `obj_launch`, `cat_mobility` |

| Piece (`cmp_` id) | The one fact, in the player's words | Mark |
| --- | --- | --- |
| Primer Coil | My shots mark a foe, and my next heavy hit on it lands harder. | A coil of three loops beside a ringed target dot. Never a bare bolt: the bolt alone means hot-wired. |
| Conductive Mesh | My shots mark a foe, and my next heavy hit on it jumps to its neighbours. | A diamond lattice with three lit nodes. |
| Ram Prow | My ram knocks foes out of their wind-up. | A solid wedge nose driving a bar (the foe) with shove ticks. |
| Brace Spring | A landed ram loads my next shot. | A wall bar, a compressed zigzag spring, a pressed plate. |
| Escape Vent | When a hit nearly kills me, I get blown clear. | A slotted vent box with two chevrons pushing out. |
| Corridor Rail | When a hit nearly kills me, a slick lane carries me out. | Two rails with ties and one chevron at the far end. |

Told apart at 26 px: circle, rounded square and hex differ in silhouette; inside a family the coil (curved loops) differs from the mesh (straight crossings), the wedge (solid) from the spring (zigzag), the vent (box) from the rail (long parallel lines).
