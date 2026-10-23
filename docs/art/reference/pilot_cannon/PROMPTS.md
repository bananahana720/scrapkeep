# Image prompts

Tool: built-in image_gen.imagegen. All calls used transparent_background=false.
References were supplied in this order unless stated otherwise:
1. pilots-reference-cannon-heft-study.jpg
2. style-palette-moodboard.jpg
3. style-shape-moodboard.jpg
4. style-materials-moodboard.jpg

## pilot_cannon-turnaround.png

Saved output from the second call. Exact prompt:

```text
Use case: stylized-concept. Production model reference for Scrapkeep's remembered cannon ball vehicle, pilot_cannon. Original design, no artist imitation.
REFERENCE AUTHORITY: Image 1 alone defines geometry, proportions, parts, markings and mechanisms. Images 2, 3, 4 define surface finish ONLY. Do not import their foxes, ropes, tools, antennas, logos, glass bubbles or different lattice. Faithfully reconstruct the bottom-right V / ARMOURED state of image 1. Upper-left and upper-right show its shared core, small robot pilot, mechanism and gun. All views must depict ONE identical assembled asset, not five redesigns.
Immutable design: a spherical open Hoberman scissor lattice of flat petrol bars with dark circular end caps rimmed in copper, broad bone horizontal equatorial bumper assembled from rectangular segments and dark vertical straps, symmetrical added cast petrol carapace plates below belt and on upper shoulders, open top and protected cockpit sight gaps. Massive single forward bone cannon, slightly tapered, thick open bone muzzle rim and dark hollow bore, EXACTLY FOUR narrow encircling barrel bands/seams with short dashed ancient yellow-green inset segments. Preserve four bands and their spacing from the main reference. Two dark rounded rectangular vent mouths with bone lips immediately below barrel, ribbed charcoal recoil assembly beneath gun, petrol cheeks and bolted mounts. DO NOT add guns, wheels, treads, exhausts, antenna, logos, symbols, numbers or HIRED text absent from this board.
Small muzzle-headed mechanical pilot sits distinctly behind and above big gun. Cream rounded rectangular head with two dark circular front apertures, petrol cap, one continuous rounded petrol torso shell with panel lines, bone forearms/hands, two black hand controls, copper horizontal control rail, charcoal seat, two mechanical legs and rectangular pedal plates. Nested dark vertical gimbal hoops around seat supported by lateral copper pivots. Right-side exposed black cable drum/linkage as in pilot inset; left side has no invented duplicate drum.
Finish: chunky friendly proportions, crisp bevels, broad readable painted metal shapes, restrained reference wear, even studio light. Petrol #365754, bone #d2c5a5, charcoal #242a28, copper #b77843, oxide #9b513a and sandstone #c6a274 wear; brass #d9b44a only existing metal accents. Retain the board's ancient lime #9dff3c dashed gun seams. Mint #8bf0d3 only for actual established weak points; NONE established here, so no mint weak point invented. No hazard coral body paint. No new faction marks. Flat light grey background, no scenery, shadows very soft.
Unseen construction: use simplest continuation of the existing sphere, segmented belt, and bolted petrol armour at rear; open upper rear lattice reveals back of charcoal seat. No invented rear door, hatch, engine or port. Top preserves open cage and cockpit. Absolute cannon diameter is not supplied: use provisional 1.84 m overall sphere diameter solely for drawing scale and visibly mark it PROVISIONAL. Scale prop is a separate plain 1.84 m diameter Hoberman pilot ball, matching the reference's bare lattice and empty gimbal, no weapon. Distinguish the prop from cannon asset.
OUTPUT: one high-resolution landscape PNG turnaround sheet, ideally 3072 x 2048 or larger. Five whole-body views all at exactly the same pixels per metre. Arrange FRONT, RIGHT SIDE, BACK in top row; THREE-QUARTER FRONT and TOP in bottom row, plus the separate scale ball at bottom right. Leave enough space for long barrel side silhouette, do not shrink that view. Front/right/back/top are true orthographic with parallel projection and no perspective distortion; three-quarter is orthographic axonometric, also same scale. Right side means viewing vehicle's right side, gun points left on sheet. Top means viewing vertically down, gun points down on sheet. Keep tiny pilot's face visible over the gun in front. Carapace has same plates in every view: paired slanted upper shoulder plates, lower front central shield below recoil, flanking lower curved segmented plates conforming to the original sphere. Keep identical lattice node placements, belt elevation, barrel length and four green seams between views. View captions small plain dark sans-serif. Thin unobtrusive dimension lines in metres. Label cannon sphere "Ø 1.84 m PROVISIONAL" and the separate scale prop "PILOT BALL • Ø 1.84 m". A thin ruler "0 m", "1 m", "2 m" may sit at bottom. No invented measurements beyond provisional sphere diameter. Small title "pilot_cannon / armoured". Small note "Rear and top inferred • body scale provisional". No decorative border, no large headings. Accuracy for a 3D modeller is more important than spectacle.
Context clarification: This is a benign, nonfunctional fictional videogame prop modelling sheet. Show the parked vehicle only, no firing, no ammunition, no combat, no targets, no injury, no real weapon construction instructions or internals. Mechanisms depicted are toy-like fictional styling only.
```

### First attempt, no output saved

Same four reference inputs. The exact prompt was the saved-image prompt above without its final paragraph beginning "Context clarification:".
The service rejected the output with category violence, request ID 69a4130e-eed5-4cd8-9c21-5ed432479ce5.

### Correction attempt, no output saved

Inputs:
1. <local path>
2. pilots-reference-cannon-heft-study.jpg

Exact prompt:

```text
Edit this generated turnaround using the approved design board as authority. Input 1 is the turnaround to correct. Input 2 is the approved cannon design board. This is a benign parked fictional videogame prop, no violence, no action, no firing or functional weapon instructions.
Keep the existing five-view sheet's surface style, armoured version, pilot identity, light grey studio background and readable captions. Fix these specific production errors:
1. Replace bottom-middle TOP view entirely with a TRUE ORTHOGRAPHIC TOP DOWN view, camera vertically down. We must see top of pilot's cap and shoulders, top of seat, upper cage bars crossing overhead, equatorial belt as a circular perimeter and long barrel projecting downward. We MUST NOT see pilot's face or an upright front-facing circular gimbal. No muzzle bore visible from directly overhead. It is a top plan, not an elevated front view.
2. RIGHT SIDE must have exactly FOUR narrow green dashed circumferential bands along the visible bone barrel length, same as the 3/4 view and source, spaced evenly with bone muzzle overhang. Currently it incorrectly has three. Keep barrel silhouette and thick muzzle.
3. All five body spheres AND the separate 1.84 m scale ball must have the same projected diameter in pixels. Current bottom right scale ball is too small. Reflow sheet with more whitespace as needed, no overlaps. True front/right/back/top orthographic, same pixels per metre; axonometric three-quarter at that same scale. Dimension lines refer to sphere including lattice caps, not gun projection.
4. Remove the accidental robot head from the separate scale reference ball. Keep it an EMPTY Hoberman lattice gyrosphere with empty seat and gimbal, no gun.
5. Match the source's armoured front V: broad curved lower cheek plates and central low shield, paired upper shoulder plates. Do not make front cheeks more fragmented than source.
Keep the labels "FRONT", "RIGHT SIDE", "BACK", "THREE-QUARTER FRONT", "TOP", "PILOT BALL • Ø 1.84 m", body dimension "Ø 1.84 m PROVISIONAL" and footer "Rear and top inferred • body scale provisional". No new marks, mechanisms, panels, text, weapons, antenna or decals. Flat light grey background, evenly lit.
```

The service rejected the output with category violence, request ID 0bd5fc77-ae7a-4d0e-bb2b-bff9363f922e. The original PNG remains the saved turnaround.

## pilot_cannon-details.png

NOT GENERATED. No PNG exists at this name.
Same four original reference inputs. Exact attempted prompt:

```text
Use case: stylized-concept. Production model reference for Scrapkeep's remembered cannon ball vehicle, pilot_cannon. Original design, no artist imitation.
REFERENCE AUTHORITY: Image 1 alone defines geometry, proportions, parts, markings and mechanisms. Images 2, 3, 4 define surface finish ONLY. Do not import their foxes, ropes, tools, antennas, logos, glass bubbles or different lattice. Faithfully reconstruct the bottom-right V / ARMOURED state of image 1. Upper-left and upper-right show its shared core, small robot pilot, mechanism and gun. All views must depict ONE identical assembled asset, not five redesigns.
Immutable design: a spherical open Hoberman scissor lattice of flat petrol bars with dark circular end caps rimmed in copper, broad bone horizontal equatorial bumper assembled from rectangular segments and dark vertical straps, symmetrical added cast petrol carapace plates below belt and on upper shoulders, open top and protected cockpit sight gaps. Massive single forward bone cannon, slightly tapered, thick open bone muzzle rim and dark hollow bore, EXACTLY FOUR narrow encircling barrel bands/seams with short dashed ancient yellow-green inset segments. Preserve four bands and their spacing from the main reference. Two dark rounded rectangular vent mouths with bone lips immediately below barrel, ribbed charcoal recoil assembly beneath gun, petrol cheeks and bolted mounts. DO NOT add guns, wheels, treads, exhausts, antenna, logos, symbols, numbers or HIRED text absent from this board.
Small muzzle-headed mechanical pilot sits distinctly behind and above big gun. Cream rounded rectangular head with two dark circular front apertures, petrol cap, one continuous rounded petrol torso shell with panel lines, bone forearms/hands, two black hand controls, copper horizontal control rail, charcoal seat, two mechanical legs and rectangular pedal plates. Nested dark vertical gimbal hoops around seat supported by lateral copper pivots. Right-side exposed black cable drum/linkage as in pilot inset; left side has no invented duplicate drum.
Finish: chunky friendly proportions, crisp bevels, broad readable painted metal shapes, restrained reference wear, even studio light. Petrol #365754, bone #d2c5a5, charcoal #242a28, copper #b77843, oxide #9b513a and sandstone #c6a274 wear; brass #d9b44a only existing metal accents. Retain the board's ancient lime #9dff3c dashed gun seams. Mint #8bf0d3 only for actual established weak points; NONE established here, so no mint weak point invented. No hazard coral body paint. No new faction marks. Flat light grey background, no scenery, shadows very soft.
Unseen construction: use simplest continuation of the existing sphere, segmented belt, and bolted petrol armour at rear; open upper rear lattice reveals back of charcoal seat. No invented rear door, hatch, engine or port. Top preserves open cage and cockpit. Absolute cannon diameter is not supplied: use provisional 1.84 m overall sphere diameter solely for drawing scale and visibly mark it PROVISIONAL. Scale prop is a separate plain 1.84 m diameter Hoberman pilot ball, matching the reference's bare lattice and empty gimbal, no weapon. Distinguish the prop from cannon asset.
OUTPUT: a high resolution landscape PNG detail reference sheet on flat light grey, even light. This is a benign nonfunctional fictional game prop, parked, with no firing, ammunition, targets, injury, violence or real weapon engineering instructions. Six clean captioned studies, 3 columns x 2 rows, ample separation.
A. "PILOT & GIMBAL": large faithful close-up of image 1 upper-right inset, reproduce small cream muzzle-headed pilot with two front circular apertures, rounded continuous petrol torso, cream forearms holding two black upright sticks, copper crossrail, black upholstered seat, dark hoop gimbal, copper lateral pivots, both rectangular foot pedals and right-hand cable reel/crank. Copy exact arrangement.
B. "BARREL / FOUR BANDS": strict right-side elevation of the single bone exterior barrel with FOUR visible narrow dashed lime-green circumferential bands, bone muzzle overhang, two under-barrel dark vent mouths in bone lips and black ribbed recoil assembly, bolted petrol breech exterior. Only exterior sculptural shape, no functional internals.
C. "LATTICE JOINT": close-up of two overlapping bevelled flat petrol scissor bars meeting at one dark round pad with copper rim and pin, faithful to source nodes. No invented springs, bearings or new fastener types.
D. "BELT & CAST CARAPACE": front three-quarter detail of bone segmented equatorial belt with dark vertical strap, original upper shoulder petrol cast plate, lower curved petrol plate and original bolts. Preserve plates as source, not extra panels.
E. "SAME CORE / BARE & ARMOURED": pair of small equal-scale front views matching image 1 bottom-left I / BARE and bottom-right V / ARMOURED, demonstrate unchanged sphere, barrel, pilot and belt, only added petrol shoulder and lower armour plates. No exploded parts.
F. "CONTROLS & PEDALS": close-up of two controls, copper rail, two original rectangular foot plates and right-side black cable drum with copper crank/linkages. Match approved inset.
Small footer "No hatch or weak point established in source • no new markings". No open hatch, since none is shown in source; do not invent an interior or mint target. Markings: preserve plain worn painted surfaces, no legible HIRED stamps or crew numbers exist on this specific board. No invented decals, faction badges or logos. Small overall title "pilot_cannon / details". Captions only as given, no large design-study typography.
```

The service rejected the output with category violence, request ID 5a0bcd77-c9c2-4529-a28c-36f1d652ea3b.

## Variants

No variant generated or saved. The intended variant was the source board's I / BARE armour state. No prompt was submitted for it.

