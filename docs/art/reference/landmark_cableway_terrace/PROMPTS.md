# Exact image generation prompts

Generated with the built-in image_gen tool. All calls used transparent_background=false. Prompts below are verbatim, including correction prompts. Initial generations and rejected correction outputs are retained under review-history/. The final selected outputs use the requested filenames. Input numbering is local to each call.

## Reference paths

1. highdraft-landmark-cableway-terrace.jpg
2. style-palette-moodboard.jpg
3. style-shape-moodboard.jpg
4. style-materials-moodboard.jpg

## landmark_cableway_terrace-turnaround.png

### Initial generation

Inputs in order: Approved board, palette, shape, materials.

```text
Create a high-resolution landscape 3D MODEL REFERENCE TURNAROUND sheet for Scrapkeep's landmark_cableway_terrace. INPUT 1 is the sole approved DESIGN ground truth. Inputs 2–4 are FINISH references only; never import their parts. Reconstruct the actual terraced cableway station in input 1, not a generic cable car station. Accuracy and consistency trump drama. Neutral light grey background, even neutral studio light, no environment, no mountains, trees, sky, sun or smoke. Retain the station's structural sandstone rock terraces and the road between them because these are the landmark itself.

Five complete views in a spacious 3-column by 2-row grid: FRONT, RIGHT SIDE, BACK, THREE-QUARTER FRONT, TOP. Sixth cell reserved for scale legend. All five use exactly the same pixels-per-metre and identical geometry; leave whitespace for the narrower side view instead of enlarging it. Front/right/back/top must be true orthographic with parallel edges, no perspective, top directly overhead. Three-quarter is orthographic axonometric. Nothing cropped.

FRONT convention: face the passage as in input 1, tall idler tower on viewer's LEFT, raised powered winch/work terraces on RIGHT, open road between. One suspended loaded basket crosses overhead between towers. RIGHT SIDE looks at right terrace exterior; back reverses left/right; top preserves the front's left/right and places the approach at bottom.

Part inventory to preserve from input 1 in EVERY view wherever visible:
1. LEFT: tall single chunky rectangular petrol enamel pylon with oxide/copper bolted collar plates, vertical dark rails at its right edge, dark diagonal backstay running to the lower outer rock ledge. Top has ONE large upright circular charcoal sheave with copper rims and a short projecting support arm toward span. Small bolted head blocks. Tower standing on tall irregular sandstone rock.
2. LEFT LOWER FOREGROUND: a huge irregular faceted sandstone boulder, two dark holes in its face, clamped by a petrol rectangular metal restraint frame with copper/oxide corner brackets. Two long horizontal charcoal shafts across it and dark wrapping straps. Do NOT replace it with a winch, barrel, tank, crate, or stacked blocks. Beige rope loop hangs over front-left edge of the base.
3. SPAN: exactly two parallel taut dark cables, no rigid crossbeam. One petrol horizontal trolley with small dark rollers and TWO hanging hook connections. Two thick suspension straps cradle ONE open chunky rectangular rounded-bottom basket. Petrol rim, oxide/copper ribs, beige rope lashings. Basket loaded with the visible irregular charcoal/bone scrap blocks with large holes. No passenger cabin, no extra cars.
4. RIGHT UPPER TERRACE: one stout petrol-and-oxide powered horizontal cylindrical drum/winch with exposed dark cable winding on its LEFT end, bolted corner plates and an upright front support. A narrow dark chimney with copper rim rises behind it. A simple dark timber/metal overhead rear frame, railings, and a small rear amber canvas canopy exactly as input 1.
5. RIGHT MIDDLE TERRACE: larger amber/beige sagging fabric canopy on thin dark posts in front of winch. Small dark stone-arched furnace recess in the rock at its right, only tiny amber heat accent.
6. RIGHT LOWER WORK LEDGE: compact petrol box winch with oxide end drum, two lilac smooth-shell friendly workers in brown scarves/harnesses tending one loose beige rope net between them, as in input 1. No ball-stack anatomy. Foreground dangling bone/brass leather work gloves, loose tools, two leaning rectangular petrol/oxide plates and bags at far right. Preserve placement and don't add text on props.
7. Central open sandstone road passage with its curving rear continuation. No scenic landscaping. Low connected rock shelves provide structural foundations.
8. Put the SAME 1.84 m diameter pilot Hoberman-lattice gyrosphere beside the station, near approach, for scale; petrol scissor lattice, oxide joints, charcoal feet and small fox pilot from INPUT 1. It is a scale reference, not another cable car. No imported coil guns or cockpit glass from other boards.

Keep chunky friendly proportions, crisp bevelled machine edges. Paint is petrol #365754, oxide #9b513a; contact wear sandstone #c6a274; charcoal #242a28 shafts/cables; brass #d9b44a small fittings; copper #b77843; bone #d2c5a5 ropes/gloves; amber #e5a044 canvas/heat. Mint #8bf0d3 only the pilot tool tip already visible in input 1, no new landmark glow or weak points. No hazard-coral body paint. Worker lilac follows input 1. No logos, faction emblems, invented writing, crew numbers or HIRED stamps: these are not legible on input 1. No decorative greebles.

Provisional layout calibration for a consistent drawing, NOT canonical measurements: whole cropped station width 13.0 m, rock-site depth 7.0 m, highest left tower 7.0 m above approach, basket bottom clearance 3.5 m, road width 3.0 m. Use thin dimension lines sparingly: 13.0 m overall front width, 7.0 m height and depth, pilot diameter 1.84 m. Caption all station dimensions 'PROVISIONAL'. Legend verbatim: 'PILOT BALL Ø 1.84 m' and 'STATION DIMENSIONS PROVISIONAL — VERIFY IN 3D'. No other invented numeric claims. Hidden rear surfaces are simple continuation of visible beams and rock, no new machinery. Title small: 'CABLEWAY TERRACE / MODEL REFERENCE'.
```

### Correction 1

Inputs in order: Approved board, review-history/turnaround-initial.png, palette, shape, materials.

```text
Correct the supplied MODEL REFERENCE SHEET. Image 1 is the approved source board and sole design authority. Image 2 is the first generated sheet to correct. Images 3–5 define finish only. Produce a complete replacement sheet with the same five named views, light grey background, flat neutral studio lighting, consistent pixels per metre, thin dimension lines and provisional metre labels. Do not change the visible approved assemblies in the front view.

The first sheet has critical camera and part errors. FIX THESE:
- RIGHT SIDE must be an actual 90-degree rotation from FRONT. Look along the span from the outside of the RIGHT winch terrace. Cables point away into the page. The narrow end of the station is visible, with the left tower behind the right winch. The repair workers appear in profile and may be partly occluded by the terrace. Do not repeat the frontal work ledge and winch broadside.
- TOP must be a true 90-degree DOWNWARD ORTHOGRAPHIC PLAN. No visible vertical front faces of rock walls, tower posts or wheels. The left tower's upright sheave is seen edge-on from above, not as a circle. See the top of the winch, top of canopy fabric, tops of worker heads and shoulders. Road is a flat plan shape, no horizon or foreshortening. Span horizontal across page; left tower at left, right winch at right, approach at bottom.
- Exactly TWO canvas awnings belong to this landmark: small upper rear canopy and larger sagging canopy over the stone furnace recess. DELETE the extra third tiny awning at lower winch level that image 2 invented in side/top. Keep the workers' front ledge open to the sky.
- The first sheet invents stacked crates on the right side and a back ladder. Remove these additions. Hidden backs are plain bolted enclosure panels and simple rock masses.
- Remove invented human silhouette in legend.
- Retain ONE loaded overhead basket and exactly TWO long parallel cables. Two hooks from trolley, two suspension straps, petrol rim and oxide ribs, beige lashings, dark scrap blocks with irregular large holes.
- Retain the big left pierced irregular sandstone boulder, petrol clamp frame, TWO long horizontal shafts, copper brackets, dark wrapping straps, draped rope. Source boulder has TWO distinct dark irregular cavities, not one large decorative hexagonal ring.
- Retain two friendly lilac smooth-shell workers, one rope net, compact work winch, front hanging gloves, two leaning plates, loose tools and bags. No added text or marks.
- Retain chimney, rear frame and railings, arch furnace and tall left pulley pylon with diagonal backstay, vertical dark rails and bolted collars.
- Pilot gyrosphere is Ø1.84 m at the SAME scale as landmark views. Its body follows image 1 with petrol lattice, oxide joints and fox pilot.

Use five equal-sized cells in a 3 by 2 grid with generous whitespace, plus small scale/notes cell. FRONT upper left, RIGHT SIDE upper middle, BACK upper right, THREE-QUARTER FRONT lower left, TOP lower middle. Same object, same scale in all five. Do NOT enlarge side to fill cell. Dimensions whole front width 13.0 m, height 7.0 m, site depth 7.0 m; ALL labelled PROVISIONAL. Pilot label 'Ø 1.84 m'. Footer 'STATION DIMENSIONS PROVISIONAL — VERIFY IN 3D'.

Finish petrol #365754 enamel, oxide #9b513a plates, sandstone #c6a274 contact wear and rocks, charcoal #242a28 cables, copper #b77843, brass #d9b44a fittings, bone #d2c5a5 rope/gloves, amber #e5a044 canvas/heat. No new mint features. No scenery, trees, plants, sky, smoke. No hazard coral body paint, no logos, no fictitious markings. Crisp bevels, chunky friendly proportions. Exact source design, not a redesign.
```

### Correction 2, selected final

Inputs in order: review-history/turnaround-correction-1.png, approved board.

```text
Edit this reference sheet, preserving all approved design parts and its layout. Image 1 is the sheet to correct. Image 2 is the original approved landmark design. Change ONLY its RIGHT SIDE and TOP cells and the mismatches specified here. Do not redraw the other cells unnecessarily.

TOP cell must be a literal plan drawing from straight overhead: camera points vertically downward, zero tilt, orthographic. Think architectural roof plan. Paint the objects in the same material colours as the other cells but use flat top-down geometry. The entire upright left pylon is foreshortened to its small rectangular top footprint; you CANNOT see its long vertical face. The tall vertical sheave is a skinny edge-on rectangle, you CANNOT see its circular face. Worker heads are circles viewed from above with shoulders and arms; you CANNOT see their faces. Rock terraces show only horizontal top surfaces with outline contours, not vertical cliff fronts. See the top of the horizontal winch as a long petrol/oxide capsule, and two fabric roof footprints. Front approach at bottom. Span runs left-right. One trolley and one loaded basket directly beneath it, only its visible top, no basket side walls. The scale ball is a circle viewed down from above.

RIGHT SIDE cell must be a flat orthographic side elevation at a strict 90-degree angle to FRONT. Look from the outside of the winch rock toward the left tower. The winch drum axis and connecting cables are aligned with viewing direction, so the drum is seen end-on and the two cables disappear into depth. The left pylon is behind the right winch and is occluded as required. Road extends horizontally across the drawing from foreground approach at left to rear at right. Worker ledge and furnace occupy approach side at left; rear canopy at right. This view cannot have a frontal net between two full-face workers; they are profile/occluded. Use flat architectural elevation presentation rather than a pleasing oblique scene.

EXACTLY TWO canvas canopies anywhere in station: small rear canopy behind the power winch and large one over furnace. Delete the THIRD tiny lower awning behind the workers from TOP and RIGHT SIDE. Nothing added in its place.
The left boulder has two separate irregular holes, not one big polygonal crater. Keep petrol clamp frame, two horizontal rods, copper collars and rope.
BACK: remove the newly invented huge square stacked box on rear of winch. Rear of the same horizontal cylindrical winch stays cylindrical with simple end cap and original support frame. No giant box cabinet.
Keep the existing five views, same pixels-per-metre, no extra inset, no extra parts. Preserve scale pilot and provisional dimension labels. Light grey, no scenery. Do not invent labels or symbols. Priority is correct projection, honest occlusion and consistent parts, not dramatic depth.
```

## landmark_cableway_terrace-details.png

### Initial generation

Inputs in order: Approved board, palette, shape, materials.

```text
Create a detailed high-resolution landscape model-reference CLOSE-UP SHEET for the Scrapkeep cableway terrace landmark. Image 1 is the sole design ground truth. Images 2, 3, 4 provide materials/finish ONLY, never new design. Flat light grey background, even studio illumination, clean separated panels, small captions, no scenery. Show the exact parts and proportions from image 1. Chunky friendly bevelled old utility machines, no industrial redesign. Eight captioned panels in a clean 4 by 2 grid:

1 'IDLER HEAD / CABLE ROUTE': enlarge the tall LEFT tower head from source. One upright charcoal wheel with copper rims, petrol bolted axle housing and oxide collars, short support arm toward span, exactly two parallel dark cables, small plain guides, vertical rails and diagonal backstay connection. Preserve the source's wheel orientation and asymmetry.
2 'TROLLEY / TWO HOOKS': close-up of petrol horizontal trolley, small dark rollers, the source's two visible ring/hook connections and the upper parts of two broad basket straps. Exactly TWO cables, TWO suspension points, ONE trolley. No extra cable lanes, cabins, third strap or chain hoist.
3 'LOADED BASKET': the source's ONE open rounded rectangular utility cargo basket, chunky petrol rim and bottom frame, oxide/copper ribs, beige rope bindings, two rising straps. Same irregular charcoal/bone scrap chunks with large holes visible in source. Include front and small side close-up of the same basket, never replace it with a round hanging cage or passenger pod.
4 'ROCK RESTRAINT': the left foreground irregular faceted sandstone boulder with TWO irregular dark cavities, chunky petrol clamp frame, copper bolted collars, TWO long horizontal charcoal shafts and wrapping dark bands, beige rope loop at lower left. Not a drum, barrel or tank. Show source geometry only.

5 'POWER WINCH / CLOSED': source's upper-right cylindrical petrol/oxide drive housing, exposed dark cable drum at LEFT, tall front upright and bolted plates, chimney behind. Circle one existing plain bolted oxide housing panel as the service cover. NO invented hinge, door handle, lettering, glow or weak point.
6 'POWER WINCH / COVER REMOVED — INFERRED': exact same winch orientation, silhouette and parts as panel 5. ONLY lift the existing bolted cover a short distance away with a fine dashed indication; shallow dark service cavity, plain axle/bearing behind it, no invented gears, electronics, glowing core, sci-fi engine, extra cylinders. Caption underneath 'Cover removal and hidden bearing are inferred; not visible on board.' This is an explanatory unapproved construction proposal, not an approved new hatch.
7 'REPAIR LEDGE / NET / GLOVES': faithfully enlarge lower right source ledge: compact petrol work winch behind two lilac friendly smooth-shell crew in brown scarves/harnesses, one loose beige net between their hands. Front stone edge has TWO leaning metal panels, hanging bone/brass work gloves, a few tools, and bags at far right. Crew are smooth continuous silhouettes, never stacked spheres. Do not add canvas above this open lower ledge.
8 'CANOPIES / FURNACE / SURFACE WEAR': source's TWO amber canvas canopies, smaller at upper rear and larger above the stone-arched furnace niche. Show full relationship in a compact diagram with the large power winch, narrow chimney and timber/metal railings. Tiny amber fire inside arch, no dramatic flame or smoke. Include tiny swatches of petrol/oxide paint edges and brass plain bolts; do not invent symbols.

Machine base colours exactly petrol #365754, oxide #9b513a, sandstone #c6a274 wear, charcoal #242a28, brass #d9b44a, copper #b77843, bone #d2c5a5, amber #e5a044. Worker lilac matches source. No mint landmark weak point exists in source, so do not invent one. No hazard coral body paint. Gloves only where shown. There are no readable HIRED stamps, crew numbers, logos or faction symbols on source, so do not add any. Footer verbatim 'NO LEGIBLE MARKINGS ON SOURCE • HIDDEN SERVICE CONSTRUCTION IS PROVISIONAL'. Thin leader lines, small readable technical captions, no dramatic lighting. Geometry and matching between closed/open winch are more important than decoration.
```

### Correction 1, selected final

Inputs in order: review-history/details-initial.png, approved board.

```text
Correct Image 1, the generated close-up sheet, using Image 2, the approved source board, as the sole design authority. Keep the 8-panel layout, exact mechanisms and material treatment unchanged except the following concrete errors. High-resolution, light grey background, evenly lit.
PANEL 8 CANOPIES: image 1 accidentally shows THREE awnings at three elevations. Source image 2 has TWO. Delete the entire middle awning and its extra dedicated support poles, the one directly behind and above the furnace canopy but below the small uppermost rear awning. Leave only SMALL REAR UPPER AWNING and LARGE FURNACE AWNING, exactly two cloth surfaces. Keep upper power winch, narrow chimney, simple rear timber frame, railings and the large furnace canopy in the original source relationships.
PANEL 7 REPAIR LEDGE: source compact work winch is a plain squat petrol housing with side drum, not an added tall steampunk machine. Reduce rear vertical extensions to match source. Keep two smooth-shell lilac workers with scarves/harnesses, one net, leaning metal plates, hanging gloves, loose tools and bags in source positions. Remove any small extra awning on this lower open ledge.
PANEL 4: source has two separate dark irregular holes in the boulder's front face. Show both distinctly. Keep rock faceted and irregular, not a round stone drum. Preserve clamp frame and two horizontal shafts.
PANEL 1: label 'Trolley support arm to span' is inaccurate. Change it to 'Sheave support arm'. This is an idler pylon head, not the traveling trolley.
PANEL 3: remove false claim '(same basket as source)' and '(same as source)'; captions simply 'Front' and 'Right side'. Preserve source petrol rim and oxide ribs, two straps and irregular holed scrap.
PANELS 5 AND 6: use precisely the same winch, scale, angle, support and exposed left drum. Closed view has the plain oxide bolted panel. Open view lifts ONLY that panel with simple shallow axle/bearing cavity. Keep explicit caption 'INFERRED: cover removal and hidden bearing'. Do not add decorative invented mechanisms. Source does not establish removable service panel; make that caveat legible.
Preserve exact colour labels in footer: SANDSTONE #c6a274, OXIDE #9b513a, PETROL #365754, CHARCOAL #242a28, BONE #d2c5a5, COPPER #b77843, BRASS #d9b44a, AMBER #e5a044. Worker lilac is source matched; do not invent a fixed numeric hex for it. No logos, HIRED stamps, crew numbers or mint weak points. No new parts. Footer 'NO LEGIBLE MARKINGS ON SOURCE • HIDDEN SERVICE CONSTRUCTION IS PROVISIONAL'.
```

## landmark_cableway_terrace-variant-1.png

### Initial generation

Inputs in order: Approved board only.

```text
Create a clean MODEL LAYOUT VARIANT sheet for Scrapkeep's cableway terrace, using the provided approved board as the only design authority. This is an explicitly UNAPPROVED alternative reading of the board's open layout question: move the working transport line farther behind the terrace instead of immediately above the foreground road. Do not redesign the component assemblies.

Flat light grey background, even neutral studio light, no scenery, mountains, trees, sky, smoke or landscaping. Title 'CABLEWAY TERRACE / VARIANT 1'. Subtitle 'PROPOSED REAR TRANSPORT LINE — NOT APPROVED'. One large clear three-quarter axonometric view on left and a clean flat top-down layout plan on right. Small footer 'Layout proposal only. Source does not establish rear depth or cable clearance.' Thin metre dimension line on pilot ball: 'Ø 1.84 m'. All other dimensions omitted because unmeasured.

Show the same two structural sandstone rock sides around an open road. Right repair terraces stay at the front: two smooth-shell lilac workers with brown scarves/harnesses handle one beige net on open ledge, compact petrol work winch behind them, hanging work gloves and two leaning panels at front, bags and tools. Above them is one large amber canvas over the stone-arched furnace niche. Behind and higher is the original petrol/oxide cylindrical powered winch, dark wound cable drum, narrow chimney, timber rear frame, railings and one small rear canopy. Exactly TWO canopies total.
The left foreground pierced faceted boulder retains its petrol clamp frame, two horizontal charcoal shafts, copper collars, dark bands, beige rope. Move the tall petrol pulley tower and its dark diagonal backstay together farther back on the LEFT rock side, and put the existing right power winch toward the back edge of the right upper terrace. This is a rearward station placement proposal; do not invent a third tower, extra winch, extra cable or rail gantry.
The connecting span has TWO parallel dark cables and ONE petrol trolley with TWO hooks, two straps and ONE open petrol/oxide basket loaded with irregular holed grey/bone scrap. It crosses the REAR road continuation beyond the foreground work terrace, leaving the approach visually open. Pilot Hoberman-lattice ball at front for 1.84 m scale.
In the top-down plan use simple coloured footprints and clear small captions 'APPROACH', 'REPAIR LEDGE', 'REAR TRANSPORT LINE'. Only the rearward-placement change is proposed. Do not claim this is what the source proves.
Part materials copy input: petrol #365754 enamel, oxide #9b513a metal plates, sandstone #c6a274 rock/contact wear, charcoal #242a28 cables, copper #b77843, brass #d9b44a bolts, bone #d2c5a5 ropes, amber #e5a044 canvas/fire. No new glow, no logos or invented markings, no hazard body paint. Chunky friendly proportions, crisp metal bevels. Preserve the original single left pylon, single right power unit, single suspended scrap basket and smooth crew silhouettes. This is an annotated alternative spatial arrangement, not a new design.
```

### Correction 1, selected final

Inputs in order: review-history/variant-1-initial.png only.

```text
Edit the attached CABLEWAY TERRACE / VARIANT 1 sheet. Preserve the rearward transport-line proposal, all captions, overall composition, parts, colours, pilot scale label and camera layout. Only fix these errors:
1. In the large left view, remove the small THIRD triangular yellow cloth behind the rightmost worker and beside the compact repair winch. There should be TWO fabric canopies total: small high rear canvas behind main power winch, and larger middle canvas above the furnace. Leave the lower worker ledge open, preserving the winch, workers and net.
2. Remove the tiny green plants at the foreground rock edges. Background stays flat light grey, rocks remain structural landmark foundation.
3. In the right plan panel do not show the vertical face of the left pylon or the front face of its circular sheave. Make these top-facing silhouettes so this is closer to a straight overhead layout. Preserve placement and all labels.
4. Keep two separate dark irregular cavities in the big foreground boulder, its clamp frame and two shafts.
No additional parts. No layout redesign. No new markings. Keep header 'PROPOSED REAR TRANSPORT LINE — NOT APPROVED'.
```

## landmark_cableway_terrace-variant-2.png

### Initial generation

Inputs in order: Approved board only.

```text
Create a clean model-reference ambiguity variant for Scrapkeep's cableway terrace, based solely on the attached approved board. Flat light grey background, neutral even studio light, no landscape. This image shows ONLY the right-hand workshop terrace in close-up, using the same design, proportions, materials and parts as the source. Title 'CABLEWAY TERRACE / VARIANT 2'. Subtitle 'LOWER CANVAS AS A SEPARATE COVER — UNCONFIRMED'.

The ambiguous area is the cropped yellow fabric at the far right edge of the approved board, behind the rightmost lilac worker and next to the small repair winch. Show the alternative interpretation that this is a THIRD, separate small sloping fabric cover extending out of the right crop, with simplest dark post support. Do not make it a building, extra room, tent or rigid roof. Its outer extent and post are inferred. Show its near edge exactly where the source's yellow triangle appears. A fine leader labels it 'Possible separate lower cover; outer edge and support inferred'.

Keep the source's other TWO canopies separately identifiable: large sagging amber cloth above the stone-arched furnace niche and small high rear canopy behind the powered winch. Therefore this VARIANT has three cloth pieces; it does not assert the source proves three structures. Keep a narrow chimney, original petrol/oxide horizontal power winch with exposed wound cable at left, bolted frame, rear timber posts and railing.
Below, preserve two lilac friendly continuous-shell workers in brown scarves/harnesses handling one beige net, a squat petrol repair winch with oxide side drum, work gloves hanging over the foreground stone edge, two leaning petrol/oxide plates, tools and bags at right. No added symbols, numbers, text on parts, logos, mint weak points or hazard paint. Same sandstone rock terrace shapes; limit reconstruction to the right-side source crop. Crisp metal bevels and chunky proportions. Petrol #365754, oxide #9b513a, sandstone #c6a274, charcoal #242a28, copper #b77843, brass #d9b44a, bone #d2c5a5, amber #e5a044. Footer 'Ambiguity study only. Confirm canopy count before modelling.'
```

### Correction 1, selected final

Inputs in order: review-history/variant-2-initial.png only.

```text
Correct the attached VARIANT 2 sheet with minimal local changes. Keep all source-derived winches, workers, net, rock, gloves, leaning plates and the three intended canvas pieces unchanged. Remove the large EXTRA yellow fabric extension stretching horizontally from the middle canopy to the isolated far-right post. Remove that isolated far-right post too. Keep the small sloping yellow cloth immediately behind the right worker and beside the repair winch: THAT is the proposed separate lower cover. Redirect the existing 'Possible separate lower cover; outer edge and support inferred' leader to THIS small sloping cloth. The final image must contain exactly three cloth pieces: small high rear canopy, large middle furnace canopy, small sloping lower repair cover. Remove the invented open tool crate full of tall tools and the brown bottle at far right; replace with only the simple soft bags already visible in the source. Remove the added hanging chain at the foreground edge beside gloves. Keep the middle terrace source hook. No other edits, no added objects. Flat light grey background, even studio light. Retain all title and footer text.
```
