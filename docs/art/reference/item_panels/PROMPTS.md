# Grey item panels: reference sheet prompts

The item ladder (DECISIONS section 6, ruled 23 Oct 19:28Z; design page "Scrapkeep Item Ladder", sections "Grey panels" and "Readability") adds twelve grey panels: stamped fleet plates that drop from kills and bolt into 32 seeded sockets on the player's gyro sphere. Card IL-01 (`alpha-status/briefs/item-panels-w19-card.md`) needs a reference set before the Blender kit plates are made. Each panel gets two sheets, drawn by Codex `gpt-6-astra` through `tools/refsheets`:

- `<unit>-onball.png`: the panel bolted on the 1.84 m ball, seen from three angles (front, side, three-quarter from above), plus a cluster of five of the same panel on the ball to show how a stack reads from a distance.
- `<unit>-details.png`: the flat panel alone at one scale (face, edge profile, back with its socket boss), a close-up of its moving part, and its open and closed (or idle and working) states.

References passed to every run: `docs/art/reference/style/style-palette-moodboard.jpg`, `style-shape-moodboard.jpg`, `style-materials-moodboard.jpg` and `docs/art/reference/pilots/pilots-balls-heft-moodboard.jpg`. Silhouettes are this lane's proposal from the panel's job ("shape is the stat"); they are not an approved board, so every REVIEW.md lists them as inferred.

## Shared preamble (every run)

You are drawing model reference sheets for Scrapkeep, a cheerful toy-styled 3D ball-rolling game. A 3D modeller will build a small bolt-on plate from these sheets, so accuracy and consistency between views matter more than drama.

What a panel is: a stamped fleet plate with one job, bolted onto the player's ball. The ball is a see-through Hoberman-lattice gyrosphere 1.84 m across, petrol #365754 lattice with brass #d9b44a joints. Each panel is a curved plate about 0.45 m across that follows the sphere's surface (it sits in one triangular-hexagonal socket of a geodesic layout), sticks out at most 0.25 m from the surface, and is held by four bolts. Its silhouette tells the player which stat it gives, readable from 20 m away without colour.

Look: machined, not plush. Crisp bevelled edges, stamped sheet metal with a raised rim, panel lines and bolt heads, one small moving part. Grey tier colours only: worn bone #d2c5a5 face with brushed steel #9aa0a0 edges and charcoal #242a28 recesses and bolt heads; a small stencilled fleet number in charcoal. No mint, cobalt, pearl, amber or purple, no glow. Original design only.

Scale rule: draw the 1.84 m ball in every on-ball view at the same scale, with thin dimension lines and metre labels. True orthographic cameras for the flat panel views (face, edge, back). Flat light grey background, even studio light, no scenery, no characters, small view captions.

Describe and draw every part as a plain machine part. Make two images, saved as PNG in the current directory with the exact names given below.

## Vent Louvre (fire rate +5%), `panel_vent_louvre`

Silhouette: five parallel horizontal slats across the plate, like a radiator grille or a window louvre, set in a raised frame. Moving part: the slats tilt open together; draw them closed and open with a small puff of white steam from the open slats. A ball with six louvres reads like an engine block.

Images: `panel_vent_louvre-onball.png` and `panel_vent_louvre-details.png` (face, edge, back with socket boss, slats closed and open, a close-up of the slat hinge).

## Punch Rivet (flat damage +1), `panel_punch_rivet`

Silhouette: one big domed rivet head (about 0.18 m across) in the centre of a thick square plate, with a ring of eight small rivets round it, like the hub of a hammer anvil. Moving part: the big rivet head sits on a short spring and pushes out 4 cm; draw it rested and pushed out.

Images: `panel_punch_rivet-onball.png` and `panel_punch_rivet-details.png` (face, edge showing the dome height, back, rested and pushed, a cutaway of the spring).

## Splash Skirt (slam and burst radius +0.35 m), `panel_splash_skirt`

Silhouette: a flared skirt plate whose lower edge bends outward and down like the brim of a hat or a hovercraft skirt, with a scalloped lip. Mounted near the ball's equator, so on a stack the skirts form a wider ring. Moving part: the lip is in three hinged segments that fan out a few centimetres.

Images: `panel_splash_skirt-onball.png` and `panel_splash_skirt-details.png` (face, edge showing the flare angle, back, lip folded and fanned, a close-up of one segment hinge).

## Range Sight (reach +4%), `panel_range_sight`

Silhouette: a small surveyor's sighting tube (like a theodolite scope) lying along the plate on two saddle clamps, with a round lens cap at the front and a ring of distance marks along it. Moving part: the lens cap flips up.

Images: `panel_range_sight-onball.png` and `panel_range_sight-details.png` (face, edge, back, cap closed and flipped up, a close-up of the saddle clamp and the marks).

## Fin Plate (cruise speed +3%), `panel_fin_plate`

Silhouette: one tall swept fin standing up from the plate, like a car's tail fin or a shark fin, leaning back along the roll direction, with three speed lines pressed into it. Moving part: a small trim tab at the trailing edge that tilts.

Images: `panel_fin_plate-onball.png` and `panel_fin_plate-details.png` (face, side profile of the fin, back, trim tab neutral and tilted, a close-up of the fin root bolts).

## Winch Drum (reel speed +6%), `panel_winch_drum`

Silhouette: a short cable drum lying across the plate between two side cheeks, wound with a few turns of rope, like a boat winch. Moving part: the drum spins; show a ratchet pawl on one cheek and motion lines on the drum in the working view.

Images: `panel_winch_drum-onball.png` and `panel_winch_drum-details.png` (face, edge, back, drum idle and spinning, a close-up of the pawl).

## Ratchet Collar (harpoon recovery +6%), `panel_ratchet_collar`

Silhouette: a toothed gear ring (a ratchet wheel, about 0.3 m across) lying flat on the plate around a central hub, with a sprung pawl clicking into the teeth. Reads as a big cog from a distance. Moving part: the ring turns one tooth at a time.

Images: `panel_ratchet_collar-onball.png` and `panel_ratchet_collar-details.png` (face, edge showing tooth height, back, the pawl engaged and lifted, a close-up of three teeth).

## Rope Spool (rope range +5%), `panel_rope_spool`

Silhouette: a tall narrow bobbin standing upright on the plate, wound fat with rope, with a loose rope end tucked under a clip. Taller and thinner than the winch drum, so the two read apart. Moving part: the spool turns on its axle.

Images: `panel_rope_spool-onball.png` and `panel_rope_spool-details.png` (face, side, back, full and half-unwound, a close-up of the clip).

## Dunk Tank (stored dunk damage +6%), `panel_dunk_tank`

Silhouette: a small round pressure tank lying on the plate in two strap bands, with a round gauge dial on its end and a short pipe stub. Moving part: the gauge needle swings from low to high.

Images: `panel_dunk_tank-onball.png` and `panel_dunk_tank-details.png` (face, edge, back, gauge low and high, a close-up of the dial and strap buckle).

## Ram Bumper (ram force +5%), `panel_ram_bumper`

Silhouette: a thick rubber-faced bumper bar across the plate on two short shock struts, like a tugboat fender or a dock bumper; the rubber face in charcoal. Moving part: the struts compress; draw extended and compressed.

Images: `panel_ram_bumper-onball.png` and `panel_ram_bumper-details.png` (face, edge showing strut travel, back, extended and compressed, a close-up of one strut).

## Hull Tile (max health +5), `panel_hull_tile`

Silhouette: the plainest panel: a thick hexagonal armour tile with a raised cross-brace pressed into it and a heavy bevelled rim, like a manhole cover. On a stack, hull tiles read as a scaled shell. Moving part: none; show a dented and a fresh tile instead.

Images: `panel_hull_tile-onball.png` and `panel_hull_tile-details.png` (face, edge showing thickness, back, fresh and dented, a close-up of the rim bevel).

## Cell Bracket (active recharge +4%), `panel_cell_bracket`

Silhouette: three upright battery cells (short fat cylinders with ribbed caps) held in a wire bracket on the plate, side by side like a battery pack. Moving part: a small bone-coloured charge flag on the bracket flips up when the cells are full.

Images: `panel_cell_bracket-onball.png` and `panel_cell_bracket-details.png` (face, edge, back, flag down and up, a close-up of one cell cap and the bracket clip).
