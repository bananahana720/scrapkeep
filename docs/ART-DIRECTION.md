# Scrapkeep art direction

**Historical first-proof art record.** The [Art & Game Bible, Section 7](../BIBLE.md#7-art-direction) now owns the approved visual direction: greasy electromagnetic salvage, internal fabrication and Southwest landscapes. The clean miniature palette and finish below remain evidence of the earlier prototype, not instructions for new art. Original prompts and implementation history are preserved.

The governing rule is a miniature salvage yard: warm ivory concrete, deep petrol shadows, safety orange machinery, and mint energy. Low-poly silhouettes and repeatable geometry keep the concept buildable in real-time WebGL.

Both concepts were generated with the built-in Codex imagegen tool. They are visual targets, not baked backgrounds. All scenery, enemies, the rolling sphere and turret attachments in the game are real 3D geometry.

## Concept 1: yard overview

Saved in `public/art/01-yard-concept.png`.

Prompt:

Use-case: stylized-concept. Create a polished 16:9 target gameplay art concept for SCRAPKEEP, an original Katamari-like 3D tower-defense game. Render a clean, genuinely buildable low-poly 3D diorama seen in orthographic isometric view, 3/4 overhead from (24,32,26). A floating rectangular miniature salvage-yard island of warm ivory concrete has a clearly readable zigzag serpentine maze road, low pale retaining walls with dark petrol inset faces and safety-orange edges, tiny industrial plants, orange traffic cones, mint energy crates, copper pipes and compact machine turrets scattered for collection. Central focus is one sticky dark petrol spherical rolling robot covered in radially outward-facing scavenged orange cannons, mint coils and small yellow machine pieces, all mounted on its visible sphere; several tiny red-orange angular robot bugs follow the road toward a luminous mint crystal reactor on a tiered platform. Golden tracer projectiles, a few tiny cubic particles, little dust clouds, warm directional shadows. A few chunky conifer silhouettes and dark teal rocks on edges, high craft, restrained geometry, clear silhouettes, soft ambient occlusion. Entire board visible in a deep nearly black petroleum-blue empty background with subtle atmospheric haze. Large board occupying almost all image with modest margins. Material palette strictly warm ivory #d4d3bf, petrol #183b3e, deep navy #0c1e23, amber-orange #ff9c52, mint #a6f4d6. Flat matte surfaces, crisp beveled cubes, premium miniature photography, beautiful soft shadows. No photographic textures, no realistic grass, no clutter, no HUD, no text. This is the target visual quality for real-time WebGL game geometry, keep the objects simple and repeatable.

## Concept 2: rolling arsenal

Saved in `public/art/02-arsenal-concept.png`. The first image was supplied as the visual reference.

Prompt:

Use-case: stylized-concept. Reference image: the previously generated SCRAPKEEP isometric salvage yard. Create a second 16:9 art-development concept image for the same original 3D game, a close isometric real-time-renderable view of the sticky rolling sphere and its scavenged turret machinery in the warm ivory concrete maze. Dark petrol matte sphere with subtle polygon facets, about 10 geometrically simple outward-mounted turrets attached to its surface: orange pipe mortar elbows, yellow bolt-repeater barrels, mint luminous coils, a few sage cactus thorn launchers. Charming little mint slit eyes set on sphere front. Sphere visibly collecting one orange machine object through an arc of floating tiny mint particles; several yellow tracer shots leaving the attached turrets toward angular vermilion robotic beetles on dark petrol lane. Tiered mint crystal reactor visible in rear, low pale concrete maze walls with safety orange trim, copper pipes and a few deep teal conifers and chunky rocks. Cohesive miniature industrial salvage diorama aesthetic, soft warm directional shadows, ambient occlusion, bevels, no complex photographic texture, no text or interface. Preserve the reference palette and low-poly buildable geometry. Premium game art, readable at small scale, no realistic rust.

## Visual iteration

- The first real browser pass matched the palette, orthographic view, layered concrete island, orange-edged maze and crystal reactor. The island edges were too plain and the title-screen ball was too small.
- The second pass added exposed rock blocks and copper piping, a larger armed sphere in the title scene, enemy silhouettes, brighter projectile trails and health bars. Live gameplay still starts with two turrets so collecting scrap produces a visible change.
- Final captures and measured performance are recorded in the verification report. The generated concepts have richer ambient occlusion and finer detail than the live geometry; the renderer targets the same art direction, not pixel identity.


## Concept-to-render pass, 5 September

The first playable version matched the palette but used long straight lanes, small turret shapes and simple slab walls. A second pass rebuilt the world from the generated targets:

- Reversed and lowered the orthographic camera, placing the taller reactor behind the action. Enlarged the mature rolling arsenal to approximately 12 percent of the overview width, close to the target's 13 percent.
- Replaced the three long lanes with a stepped route and machinery courts. Added low cream road curbs, irregular paving, layered perimeter stone, copper plumbing and clustered trees.
- Rebuilt cannon receivers, muzzle collars, coil cages and cactus mounts. Collected items use spherical attachment positions; loose cannons have horizontal silhouettes, while energy cells use square mint cages.
- Replaced flat orange enemies with armored vermilion beetles, black articulated legs and mint eyes.
- Added ground-truth ambient occlusion, variance shadow filtering, bloom and four-sample antialiasing. The static yard and reusable models batch their color data into opaque and emissive meshes.
- Reconciled the larger physical body with the raised courts, and changed shots from horizontal arrival checks to full 3D homing.

Saved comparisons in `artifacts/visual-iterations/`: `00-before.png`, `01-rebuilt-arena.png`, `02-masonry-and-props.png`, and the final overview/detail captures. The comparison scenes deliberately stage a mature arsenal and enemies using the actual game geometry. The separate combat stress scene runs continuously through the normal simulation and renderer.

The result follows the target's composition, scale, palette and machinery language. The concepts still contain finer sculpted irregularity and authored surface detail; the screenshots are real-time procedural geometry rather than exact reproductions of generated pixels.
