# Boom tender reference sheets: prompts

Unit 1 (Spillway roster) needs one new Mojulo-sculpted Fleet body for the dam and the flume. Andrew's 23 Oct rule: a turnaround set before any modelling, drawn on the PC with `tools/refsheets` (branch `claude/project-thread-3q2roz`). Approved board passed as the first image: `docs/art/reference/enemies/enemies-spillway-moodboard.jpg`. Then the four style masters in `~/scratch/w18/boards/style/`. Mechanics: `sketches/core-loop/design-v3/SPILLWAY-ROSTER.md` on branch `claude/project-thread-e4z0d0`.

Run: `python3 tools/refsheets/split.py <this file> ~/scratch/w19/refsheets/roster` then `tools/refsheets/draw.sh ~/scratch/w19/refsheets/roster boom_tender -- docs/art/reference/enemies/enemies-spillway-moodboard.jpg <style masters>`. Copy keepers to `docs/art/reference/enemies/boom_tender/` as JPEG with REVIEW.md.

## Shared preamble

You are drawing model reference sheets for Scrapkeep, a 3D action roguelite. A 3D modeller will sculpt the machine from these sheets, so accuracy and consistency between views matter more than drama.

Canon to follow:
- This is a working utility machine of the Fleet, the crew of machines that runs a desert dam and its spillway channels. It is doing its old job with too much enthusiasm. No purple, no glowing eyes, no evil face, no weapons.
- All hands: the crew number is stencilled large in bone #d2c5a5 on the body, and a small rectangular HIRED stamp sits near it.
- Look: soft-toy proportions (chunky, slightly oversized, friendly), but a machine: crisp bevelled edges, a bold silhouette, one smooth cast shell for the main hull with panel lines and bolts on it, never a body built from stacked spheres or primitives. Separate parts only for the moving pieces named below.
- It belongs with the board's chaser, lobber, mag trapper, plated brute and winch drone: same oxide-and-petrol enamel, sandstone wear, charcoal running gear, brass fittings, hazard stripes only on the parts that move toward the player.
- Palette, exact hexes: petrol #365754, oxide #9b513a, sandstone #c6a274 wear, charcoal #242a28, brass #d9b44a, copper #b77843, bone #d2c5a5, hazard #ff5a3c (stripe bands only).
- Scale: draw the 1.84 m player ball (a see-through Hoberman-lattice sphere) standing on the ground line in every view, same scale as the front view. The ball is the same size in every panel.
- True orthographic front, side, back and top cameras; the top looks straight down.
- Sheet style: clean model sheet on a flat light grey background, even studio light, no scenery, thin dimension lines with metre labels, view names as small captions. Original design only; imitate no living artist or studio.

Make two images, saved as PNG in the current directory with the exact names given below.

## Boom Tender No. 22 (Spillway: dam and flume), `boom_tender`

Spec:
- Old job: it strings a floating debris boom across a spillway channel to catch driftwood before the gates. It still does: it drags its boom across your lane like a broom across a floor.
- Silhouette: low and wide, a tugboat that drives on land. A squat pontoon hull (3.2 m long, 2.4 m wide, 1.3 m tall) on two short charcoal track pods, a big horizontal cable reel drum on its back (1.6 m across, axle side to side, top of drum 2.3 m from the ground), a short stubby exhaust stack at the back left, and a fairlead roller at the front where the cable leaves the reel.
- The boom: five linked cylindrical floats on one cable, trailing from the fairlead to a small anchor buoy at the end. Each float 0.9 m long and 0.6 m across, oxide with one hazard stripe band and a small brass lamp on top; the gap between floats 0.4 m. The whole boom reaches 6.5 m from the hull. Draw it laid out straight forward in the turnaround.
- Moving parts: TenderReel (spins about its horizontal axle), TenderFairlead (the roller swivels left and right), BoomFloat0 to BoomFloat4 (each float rides its own cable link), BoomBuoy (end anchor buoy), TenderTrackLeft and TenderTrackRight.
- Colour: petrol hull with sandstone wear on the edges, oxide reel drum, charcoal tracks and roller, brass fittings and float lamps, stencil "22" large on the hull side in bone, HIRED stamp on the reel housing.
- Front is the side the fairlead and the boom face.

Images:
1. `boom_tender-turnaround.png`: front, left side, back, three-quarter (front-left, from slightly above) and top views, with the boom laid straight forward and the scale ball in every view. Label overall hull length, width, height to drum top, float length and boom reach.
2. `boom_tender-details.png`: close-up of the fairlead roller with the cable leaving the reel; one float close up (stripe band, brass lamp, cable link ends); the boom swung 90 degrees to the left in a top view (the sweep pose); a float bursting open along its seam (two shell halves and a puff of spray, the pop pose); and an exploded view separating the hull shell from the reel, fairlead, two tracks, five floats and the buoy, each labelled with its part name.
