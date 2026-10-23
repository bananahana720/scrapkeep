You are drawing model reference sheets for Scrapkeep, a 3D action roguelite. A 3D modeller will build this body from these sheets, so accuracy and consistency between views matter more than drama.

Ground truth: image 1 is the approved board for this body. Copy its design exactly: the same parts, proportions, colours, markings and mechanisms. Where image 1 does not show a side, infer the simplest construction that agrees with what it shows, and list each inferred part in REVIEW.md. Images 2 to 4 are the project's palette, shape and materials boards; follow them for finish only, never for design.

Canon to follow:
- The machines are the humans' old utility fleet. The Mind was their foreman, and "all hands" means the crew were its hands, so crew numbers, gloves and HIRED stamps appear where the board shows them. Invent no faction marks, logos or real companies.
- Look: soft-toy proportions (chunky, slightly oversized, friendly). Machines keep crisp bevelled edges and a bold silhouette. Creature and crew bodies are one smooth shell, never stacked balls. Panel lines and bolts sit on the shell.
- Palette, exact hexes: petrol #365754 enamel, oxide #9b513a, sandstone #c6a274 wear, charcoal #242a28, brass #d9b44a, copper #b77843, bone #d2c5a5, amber #e5a044, frost #c8f0ff, mint #8bf0d3 (weak points only). Hazard coral with charcoal keylines and stripes is for danger footprints, never body paint.
- Scale: put a 1.84 m diameter pilot ball (a Hoberman-lattice gyrosphere) beside the body in the turnaround.
- Sheet style: clean model sheet on a flat light grey background, even studio light, no scenery, no perspective distortion in the orthographic views (front, side, back, top), thin dimension lines with metre labels, view names as small captions. Original design only; imitate no living artist or studio.

Make two images, saved as PNG in the current directory with the exact names given below:
1. `landmark_dam_face-turnaround.png`: front, right side, back, three-quarter front and top views of the whole body, same scale, on one sheet.
2. `landmark_dam_face-details.png`: close-ups of the distinguishing parts (mechanisms, joints, weak point or service hatch open and closed, markings), each captioned.

Then check both images against image 1 view by view. Regenerate any image that adds, drops or changes a part. If image 1 is ambiguous about a part, also save `landmark_dam_face-variant-<n>.png` showing the other reading, at most two variants.

Finally write two text files in the current directory:
- `PROMPTS.md`: the exact image prompt text you sent for each saved image, under a heading with its file name.
- `REVIEW.md`: what you checked, each inferred part, each mismatch you could not fix, and the open questions a modeller should ask.

## the dam-face waterworks landmark (a rideable concrete dam with its spillway machinery) (`landmark_dam_face`)

Board: `docs/art/reference/spillway/spillway-landmarks-dam-face.jpg` (image 1). The board's notes:

![spillway-landmarks-dam-face](spillway-landmarks-dam-face.jpg)

- **Why it exists:** The stage's destination becomes a rideable machine. Its waterworks history remains visible beside the Warden encounter.
- **Why it should work:** The authored 320 m crest and approximately 120 m face dominate; two towers make the skyline recognizable. The reactor sits 22 m above the toe. Water mineral bands and concrete repair joints carry detail outside the open approach. In this active encounter, the service shelves show traces of residents but no live locals.
