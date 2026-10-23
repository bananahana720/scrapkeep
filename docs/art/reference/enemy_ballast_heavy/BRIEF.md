You are drawing model reference sheets for Scrapkeep, a 3D action roguelite. A 3D modeller will build this body from these sheets, so accuracy and consistency between views matter more than drama.

Ground truth: image 1 is the approved board for this body. Copy its design exactly: the same parts, proportions, colours, markings and mechanisms. Where image 1 does not show a side, infer the simplest construction that agrees with what it shows, and list each inferred part in REVIEW.md. Images 2 to 4 are the project's palette, shape and materials boards; follow them for finish only, never for design.

Canon to follow:
- The machines are the humans' old utility fleet. The Mind was their foreman, and "all hands" means the crew were its hands, so crew numbers, gloves and HIRED stamps appear where the board shows them. Invent no faction marks, logos or real companies.
- Look: soft-toy proportions (chunky, slightly oversized, friendly). Machines keep crisp bevelled edges and a bold silhouette. Creature and crew bodies are one smooth shell, never stacked balls. Panel lines and bolts sit on the shell.
- Palette, exact hexes: petrol #365754 enamel, oxide #9b513a, sandstone #c6a274 wear, charcoal #242a28, brass #d9b44a, copper #b77843, bone #d2c5a5, amber #e5a044, frost #c8f0ff, mint #8bf0d3 (weak points only). Hazard coral with charcoal keylines and stripes is for danger footprints, never body paint.
- Scale: put a 1.84 m diameter pilot ball (a Hoberman-lattice gyrosphere) beside the body in the turnaround.
- Sheet style: clean model sheet on a flat light grey background, even studio light, no scenery, no perspective distortion in the orthographic views (front, side, back, top), thin dimension lines with metre labels, view names as small captions. Original design only; imitate no living artist or studio.

Make two images, saved as PNG in the current directory with the exact names given below:
1. `enemy_ballast_heavy-turnaround.png`: front, right side, back, three-quarter front and top views of the whole body, same scale, on one sheet.
2. `enemy_ballast_heavy-details.png`: close-ups of the distinguishing parts (mechanisms, joints, weak point or service hatch open and closed, markings), each captioned.

Then check both images against image 1 view by view. Regenerate any image that adds, drops or changes a part. If image 1 is ambiguous about a part, also save `enemy_ballast_heavy-variant-<n>.png` showing the other reading, at most two variants.

Finally write two text files in the current directory:
- `PROMPTS.md`: the exact image prompt text you sent for each saved image, under a heading with its file name.
- `REVIEW.md`: what you checked, each inferred part, each mismatch you could not fix, and the open questions a modeller should ask.

## the ballast heavy enemy machine (`enemy_ballast_heavy`)

Board: `docs/art/reference/enemies/enemies-highdraft-ballast-heavy-reference.jpg` (image 1). The board's notes:

![enemies-highdraft-ballast-heavy-reference](enemies-highdraft-ballast-heavy-reference.jpg)

- **Why it exists:** Make the interruptible brace and the inland-to-edge ram the obvious answer to a near-unkillable heavy.
- **Why it should work:** The overhead slab, brake feet, inland cable stake and open cliff establish mass and direction without a health-bar explanation. The enemy tips outward while the player stays on the island.
- **Open question:** Does the movable ballast-hoist origin read clearly? The rear-cable layout is a proposal illustrating the existing grown-pilot rule.
