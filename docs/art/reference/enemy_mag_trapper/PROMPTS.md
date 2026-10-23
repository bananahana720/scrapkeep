# Exact image prompts

Tool: built-in `image_gen`, `transparent_background: false`. No CLI or external generation service was used. Every prompt block is verbatim. Generated PNGs were copied without image manipulation.

Reference input paths:

1. `enemies-spillway-mag-trapper-reference.jpg`
2. `style-palette-moodboard.jpg`
3. `style-shape-moodboard.jpg`
4. `style-materials-moodboard.jpg`

## enemy_mag_trapper-turnaround.png

Final selection: attempt 3.

### Attempt 1

Inputs: reference paths 1–4. Output: `exec-0d57cef7-4b66-44d6-9871-fd524ea7c8ee.png`. Rejected for angled front/back and six top-view feet.

```text
Use case: stylized-concept.
Create a precise 3D modeller's turnaround reference sheet for Scrapkeep enemy_mag_trapper. Output one high resolution landscape PNG.
INPUT AUTHORITY: image 1 is the approved Mag Trapper / Intake Crew design. Copy that machine, not a redesign. Images 2, 3, 4 govern finish only. No style-board tools or sphere parts transferred to machine.
BACKGROUND: flat light grey, even neutral studio light, minimal contact shadows, no scenery.
LAYOUT: orderly 3 columns by 2 rows, generous gutters. Upper row FRONT, RIGHT SIDE, BACK. Lower row THREE-QUARTER FRONT, TOP, SCALE REFERENCE. Five whole-machine views at identical pixels per metre and same extended-arm pose, no cropping. Front, right side, back and top are genuine orthographic projections, parallel edges, no perspective, top looks vertically down. Three-quarter is orthographic isometric. Small captions. Scale reference is a Hoberman-lattice pilot gyrosphere, diameter 1.84 m, drawn at the same pixels per metre as the machine, beside it in its own cell.
DESIGN LOCK: chunky squat four-foot utility walker with a rectangular low chassis, four short articulated legs, broad bevelled trapezoidal armour boots, charcoal soles, oxide and bone patch plates, large circular steel joint pivots, black curved hydraulic hoses. One tall vertical stack of FIVE separate broad charcoal circular pit discs on the rear of chassis, visible gaps, oxide/sandstone worn rims, plain brass/oxide support underneath. Do not double this stack. One upright forward cab with open dark trapezoidal windshield aperture and the small orange fox intake operator wearing the board's brown cap and cream work shirt, hands at controls. Do not close the cab with glass. A sloped oxide chest/front plate beneath the opening with the board's small square brass plaque and EXACT existing dark geometric winged-diamond emblem copied from image 1. No new symbols or lettering. Copy the chunky side pivot cylinders and lower looped hoses surrounding the chest.
A single long overhead articulated crane arm rises from cab upper rear, has chunky oxide pivot housings and exposed pale bone rectangular beam with thin upper dark hydraulic rod, large round steel pins, then a downturned wrist at its forward end. From the wrist hangs exactly ONE broad horizontal dark magnetic disc with thick worn oxide rim and recessed concentric underside mouth. The suspended disc is ahead of cab and separate from the rear stored stack.
A separate low open circular floor trap ring stands on the floor ahead of the machine underneath the suspended disc, with charcoal thick rim, oxide base flange and a few large bone/brass bolt-on perimeter brackets, copying image 1. Do not turn the open ring into a solid puck. Keep floor ring present at same position in all projections, but visually detached from chassis. Floor warning footprint may be omitted on this neutral modelling sheet; no hazard paint on machine.
CONSTRUCTION: take the main hero panel as the five-disc count authority. Simplest hidden construction: two pairs of matching short leg mechanisms, plain rear bolted oxide/bone closure panels behind the magazine carrier, no engine added, no vents invented, no extra turret, no gun. Rear magazine centred on longitudinal axis behind cab. All five views must depict exactly this same assembly and handedness.
SCALE: proposed overall height to arm pivot 3.10 m, proposed width across feet 2.80 m, proposed body plus forward suspended-disc reach 5.50 m. Thin technical dimension lines with metre labels. Explicit small legend "Machine dimensions proposed • Pilot ball fixed". Show ball diameter "Ø 1.84 m". Use these dimensions consistently, never pretend they were measured from the board. Machine is larger than ball.
PALETTE: oxide #9b513a main armour exactly as image 1, bone #d2c5a5 repair plates and arm beam, charcoal #242a28 discs hoses seams soles, brass #d9b44a plaque and fittings, sandstone #c6a274 restrained wear, copper #b77843 only existing fittings. Petrol #365754 only where source has it, do not recolour whole body teal. No mint glow because image 1 establishes no luminous weak point. Hazard coral #ff5a3c with charcoal belongs only on external danger footprint, not body.
FINISH: friendly chunky soft-toy proportions with crisp bevelled machine edges, physical bolts on panels, worn old enamel, localized rim and joint wear, oil only at pivots, clean readable surfaces, not photoreal grime, not piled primitive spheres.
TEXT: "MAG TRAPPER — MODEL REFERENCE", small captions "FRONT", "RIGHT SIDE", "BACK", "THREE-QUARTER FRONT", "TOP", "SCALE REFERENCE". No invented crew numbers, gloves painted on hull, HIRED stamps, faction marks, logos or real companies. Do not add unseen markings.
Accuracy and view consistency matter more than drama. Resolve occlusion geometrically rather than moving parts to make them visible.
```

### Attempt 2

Inputs: reference path 1 and attempt 1. Output: `exec-b41deb2e-42f0-422d-89bd-05f1324faebd.png`. Improved projection and foot count; scale and missing ring elevations required correction.

```text
Correct the attached generated Mag Trapper turnaround (image 2) against approved board (image 1). Produce a replacement full reference sheet. Preserve the approved machine design, five stored discs, one suspended magnetic disc, one separate open floor ring, single open cab with fox operator, brass chest plaque and its existing emblem, oxide/bone armour, hoses, crane beam and pivots. Do not use image 2 as design authority where it disagrees with image 1.
CRITICAL CORRECTION: there are exactly FOUR legs, one at each corner of one rectangular chassis. The prior TOP view incorrectly has six feet, remove the middle-front and middle-back feet. Top must show four corner feet only. No extra boots, toes, stabilizers or central legs. Front looks straight at cab, rear looks straight at rear magazine. Longitudinal direction is cab/front to magazine/rear. Front should be bilaterally aligned with cab centred and the rear disc stack occluded behind it, not offset to viewer left like a three-quarter illustration. The crane points straight forwards, so front and back see its beam foreshortened/end-on, NOT its long side silhouette. Back shows rear stack centred with the cab mostly hidden behind it. RIGHT SIDE shows the long crane silhouette, magazine on LEFT and suspended disc on RIGHT. TOP shows rear stack, cab, suspended disc and open floor ring along one centreline. Front and rear leg pairs overlap correctly in side projection. Do not shift parts sideways to reveal them.
Every orthographic panel must represent the same single 3D object rotated, not repeated three-quarter poses. No visible top surfaces in FRONT/RIGHT SIDE/BACK beyond bevels that face the camera. Strict technical front, right side, back, top. Only THREE-QUARTER FRONT may expose two body sides. Floor ring is hollow through its middle, light grey ground seen through it, no dark solid bottom, no added central disc. In top it lies directly BELOW the suspended disc; show it separately next to the top projection in a small accessory inset labelled "FLOOR RING — SEPARATE", do not move it sideways in the assembly.
Flat light-grey background. Even studio lighting, crisp chunky friendly bevelled mechanical modelling reference, no scenery. Two rows and three columns. FRONT, RIGHT SIDE, BACK upper row; THREE-QUARTER FRONT, TOP, PILOT BALL lower row. Machine views at one identical pixels-per-metre scale, no duplicate smaller machine in ball cell. Ball alone Ø 1.84 m at same scale. The complete 3.10 m machine height must be 1.685 times the ball diameter in pixels, so ball must NOT be miniature. Machine proposed width 2.80 m, arm reach envelope 5.50 m; dimension each only in its true matching projection. Caption "Machine dimensions proposed; pilot ball fixed". Do not put length dimension on FRONT. Put thin "3.10 m" height and "2.80 m" width on FRONT; put "5.50 m" horizontal reach on RIGHT SIDE. Those are proposed working values, preserve source proportions as closely as possible.
Copy image 1 markings only. Never add HIRED, crew numbers, symbols, mint emitters, teal repaint, gun, closed glass canopy, engine or vents. Oxide #9b513a, bone #d2c5a5, charcoal #242a28, brass #d9b44a, sandstone #c6a274 wear, copper #b77843 fittings. Restrained edge wear. Existing source emblem not a new logo.
Prioritize accurate projection and matching parts over decorative layout.
```

### Attempt 3 — saved

Inputs: reference path 1 and attempt 2. Output: `exec-7570f30d-4855-42b3-b39e-dc11477138d3.png`. Remaining defects in REVIEW.md.

```text
Edit image 2, the current Mag Trapper turnaround, using image 1 as approved design authority. Keep its layout and all correct parts. Correct only these remaining drafting errors:
1. Same pixels per metre in ALL FIVE MACHINE VIEWS and pilot ball. Establish 112 pixels per metre on a 1536x1024 sheet, or proportionally equivalent if larger. Proposed machine height 3.10m means 347px; width 2.80m means 314px; longitudinal total 5.50m means 616px. Ball diameter 1.84m means 206px. The previous ball is too big relative to machine height. Reduce it so machine height divided by ball diameter is 1.685. Front and back machine width must be consistent with right side and top. Scale entire views uniformly, never distort their geometry to fit labels. Arrange the panels with wider centre column if necessary. No sixth smaller machine.
2. Front held disc width must match stored disc width, approximately the same diameter, as in right side and top. It was much smaller in the previous front. Correct it. In FRONT and BACK the crane and discs are centred on the same fore-aft axis; shoulder pivot axles run left-right so the camera must NOT see an enormous circular side-on axle facing the front. Show narrow end face of shoulder housing, preserving the proper side-facing axle circles only in side and three-quarter views.
3. In FRONT and BACK include the separate floor ring on the ground under suspended disc, drawn as a low wide rectangular side elevation with bevels, occluded naturally where feet are in front of it. It is part of the deployed assembly and must not disappear from those views. In TOP ring lies directly under held disc and is occluded; retain the detached accessory ring inset to show its hole, with caption "FLOOR RING — SEPARATE".
4. Strict orthographic FRONT, RIGHT SIDE, BACK, TOP with no top ellipses visible in level elevations except tiny bevels; THREE-QUARTER FRONT is sole angled view. Four legs only at four chassis corners, five stored discs only, one held disc only. Preserve original reference's chunky chassis proportions and magazine behind open fox cab. No six-legged top.
Unchanged: exactly source oxide and bone armour, charcoal discs, square brass plaque with SAME source geometric emblem, open cab with fox crew in cap, source crane with bone beam, upper dark hydraulic rod, oxide pivot housings, lower black loop hoses and chunky bevelled boots. No new hatches, no guns, no mint glow, no extra markings. No repaint. Flat light-grey background, neutral even studio lighting, restrained worn edges. Header "MAG TRAPPER — MODEL REFERENCE". Captions FRONT, RIGHT SIDE, BACK, THREE-QUARTER FRONT, TOP, PILOT BALL. Thin metre dimension lines on matching projections. Caption "Machine dimensions proposed; pilot ball fixed". Respect image 1 above the generated sheet.
```

## enemy_mag_trapper-details.png

No PNG returned by generation. Permission requested for a local captioned-crop fallback. These prompts do not establish an image exists.

### Attempt 1 — rejected

Inputs: reference 1 and turnaround attempt 2. Output moderation: violence. Request ID `f4f4ae78-4031-409b-9633-d353b9d9ec5f`.

```text
Use case: stylized-concept. Create one high resolution landscape PNG details reference sheet for a 3D modeller of Scrapkeep enemy_mag_trapper. Image 1 is the sole approved DESIGN authority. Image 2 is the selected turnaround for continuity, subordinate to image 1. Preserve exact source parts and proportions, do not add mechanisms from imagination. Flat light grey background, even studio lighting, isolated close-ups, crisp bevelled chunky stylized old utility machinery. No scenery, no dramatic lighting.
Six large cells, 3 columns by 2 rows, small readable captions and fine leader lines:
1 "DISC MAGAZINE / FEED LATCH". Five broad charcoal stored pit discs in a single vertical stack on its oxide/brass carrier. Copy the source main hero FIVE-disc count. Beside stack show two small identical crops of the observed side latch: "CLOSED" and "RELEASED — INFERRED". Copy the cylindrical hinge and chunky oxide plate/roller beside disc edge from source inset DISC FEED LATCH. Only rotate the existing latch outward in released view, do not invent a new hatch or internal engine. Small caption "Motion inferred; hidden feed path unresolved". No ghost extra discs or diagram arrows that become parts.
2 "CRANE / WRIST". Exact single crane from board: oxide shoulder with round steel axle, bone rectangular forearm, parallel thin dark top hydraulic rod, oxide elbow with steel pin, downturned chunky wrist and axial connection onto TOP CENTRE of held disc. Show full beam plus closeup of wrist, matching source component ordering. Do not add pistons, claws, hooks, jaws, wires or antennae.
3 "HELD MAGNETIC DISC / UNDERSIDE". One thick solid charcoal circular held magnetic disc, worn oxide rim, underside concentric recessed circular launcher mouth. This is a shallow recess with a circular inner plate, not a hollow floor ring. Show top three-quarter and underside side by side, EXACT SAME single component. Top has central wrist attachment. Caption "Held disc; recessed mouth". No mint light or invented weak point.
4 "FLOOR TRAP RING". Separate low open ring from board, charcoal cylindrical wall, oxide base flange, bone/brass bolted perimeter brackets. Show three-quarter and overhead view of SAME component. Light grey background visible THROUGH the centre hole; no solid centre plate. Add small side profile. Thin dimension annotation "Diameter unresolved" rather than made-up number. Optional coral #ff5a3c danger outline only OUTSIDE ring on ground, never body paint; otherwise omit warning. Keep held disc and floor ring distinct.
5 "LEG / PIVOT / HOSE". One exact source front boot with broad bevelled trapezoid silhouette, oxide main plate, bone edge repair plate, charcoal sole, round steel upper axle and lower dark transverse toe pivot, black flexible hydraulic hose curving into brass coupler. One short chunky articulated leg, not a wheel or track, not claw toes. Physical oil limited to joint. Copy board arrangement.
6 "CAB / CREW / EXISTING PLAQUE". Open trapezoidal cab with dark interior, bone border, orange fox crew operator in brown cap and cream work shirt at controls. Same source character, not a new body. Under cab an oxide front panel with square brass plaque, dark winged diamond emblem faithfully copied from image 1. Include a larger straight-on inset of that EXACT plaque, preserving symbol rather than designing one. Caption "Existing board marking". No other markings, no invented HIRED stamps, crew numbers, glove icon, logos or real companies.
Heading "MAG TRAPPER — PART DETAILS". Small footer "Five-disc reading from main view. Released latch inferred. No weak point specified by approved board."
Colour roles match original: oxide #9b513a main enamel, bone #d2c5a5 plates/beam, charcoal #242a28 discs/hoses/soles, brass #d9b44a plaque/couplers, sandstone #c6a274 sparse wear, copper #b77843 only fittings where shown. Do not repaint petrol. No mint illumination. Slightly oversized friendly machine forms and crisp bevels, not organic ball shapes. Wear localized to disc rims, edges and exposed joints. Each cell must show the same parts as the board and turnaround, not decorative variants. No explosion diagrams that invent hidden technology.
```

### Attempt 2 — rejected

Inputs: reference 1 and turnaround attempt 3. Output moderation: violence. Request ID `8e016327-a5d6-412e-8404-a3528f33862b`.

```text
Create a clean mechanical model-reference details sheet for the fictional "MAG TRAPPER / INTAKE CREW" utility machine in the first reference image. The first reference is the approved design; copy its visible parts exactly. The second reference gives the current whole-machine sheet for continuity only. This is a workshop modelling document of a friendly stylized industrial vehicle.
Landscape sheet, flat light grey background, even studio lighting, six captioned closeup panels in two rows. Original design, crisp bevelled chunky metal parts with restrained worn enamel. No scenery.
Upper left: "DISC MAGAZINE / FEED LATCH". Copy the five broad charcoal discs stacked on an oxide/brass carrier from the main scene. Show small closed and released views of the board's visible cylindrical hinge and chunky oxide feed latch next to disc rim. Label "CLOSED", "RELEASED — INFERRED", and "Hidden feed path unresolved". Released view only rotates that same latch; do not add parts.
Upper middle: "CRANE / WRIST". The board's single articulated overhead arm: oxide round-pin shoulder housing, bone rectangular beam, parallel dark upper hydraulic rod, oxide elbow and downturned wrist attached to top centre of circular disc. Same parts, order and scale as reference.
Upper right: "HELD DISC / UNDERSIDE". Top and underside views of exactly the same suspended dark circular component. Thick worn oxide rim, central wrist boss above, concentric shallow recessed circular mouth underneath with a closed inner plate. Copy source, no illuminated interior.
Lower left: "FLOOR RING". The separate low circular ring with charcoal wall, oxide bottom flange, broad bone/brass brackets and large dark bolts from source. Three-quarter and overhead view of SAME ring. It is hollow through the centre, so light grey background is visible in the hole. No solid bottom. Small side profile. No ground graphics.
Lower middle: "LEG / PIVOT / HOSE". Single source front leg, broad bevelled trapezoidal oxide boot with bone patch, charcoal sole, round steel upper joint, dark transverse lower toe pivot, short joint linkage and black curved hose with brass coupler. No wheel, no track, no extra toes.
Lower right: "CAB / EXISTING PLAQUE". Same open trapezoidal cab and orange fox operator in brown cap, cream work shirt. Show exact existing square brass plaque beneath cab and a straight-on enlargement of its existing dark winged-diamond symbol. Copy source symbol, do not invent lettering or any new marks.
Heading "MAG TRAPPER — PART DETAILS". Footer "Five-disc reading from main view. Latch motion inferred."
Match image 1 colours: oxide #9b513a enamel, bone #d2c5a5 repair plates and beam, charcoal #242a28 discs hoses soles, brass #d9b44a plaque couplers, sandstone #c6a274 localized rim and edge wear. No overall teal repaint. No added light emitters. No new accessories or internal machinery. Every closeup must show the same construction as image 1.
```

### Attempt 3 — rejected

Inputs: reference 1 and turnaround attempt 3. Output moderation: violence. Request ID `761f8859-1177-46d3-923d-d36de073767a`.

```text
Reformat the visible exterior details of the approved stylized utility vehicle in reference image 1 as a clean modeller's closeup sheet. Reference image 2 is its current turnaround. Copy existing visible components and their colours exactly, no redesign. Title "MAG TRAPPER — DETAILS". Six captioned panels on a flat light-grey background with even studio lighting and thin leader lines.
Panel 1 "FIVE-DISC MAGAZINE": closeup of the main board's five stacked charcoal discs, worn edges, brass/oxide support and adjacent black hose. Exactly five separate discs.
Panel 2 "FEED LATCH": faithfully enlarge the same visible exterior assembly from image 1's DISC FEED LATCH inset. Show its circular pin, oxide bracket and rim contact. Label "Closed exterior; motion unresolved". Do not open it or add hidden parts.
Panel 3 "CRANE JOINTS": show the entire single overhead arm from source as an isolated side view: oxide shoulder and elbow housings, circular dark metal pins, bone rectangular beam, parallel dark upper rod, downturned wrist. Include the suspended round disc beneath the wrist, preserving its thick rim and concentric underside recess.
Panel 4 "LEG AND HOSE": one large closeup of the approved broad bevelled oxide front foot, bone patch, charcoal sole, round axle, short linkage, black hose and brass fitting. Copy source shape; no wheel or track.
Panel 5 "FLOOR RING": the separate low charcoal circular ring, oxide base flange, broad bone brackets with dark bolts. Three-quarter and top view, same object. Centre is an open hole with light grey background visible. Label "Through-hole reading; bottom unresolved".
Panel 6 "CAB AND PLAQUE": closeup of the source open cab, small friendly orange fox operator in brown cap and cream shirt, and the square brass plate beneath. Exactly reproduce the dark geometric emblem on that plate from approved board, with an enlarged straight-on plaque inset. No new marks or lettering on the body.
Small footer "Visible exterior reference. Hidden construction and release motion unresolved."
Oxide #9b513a, bone #d2c5a5, charcoal #242a28, brass #d9b44a, sandstone #c6a274 localized wear. Match existing chunky friendly proportions and crisp metal bevels. No scenery, no drama, no luminous parts, no invented accessories. Every closeup depicts the approved machine, not a new version.
```

## enemy_mag_trapper-variant-1.png

Input: reference path 1 only. Output: `exec-02293438-1326-4964-9849-209419915f59.png`. Two independent alternate readings on one sheet.

```text
Create one clean model-reference VARIANT sheet for the fictional Mag Trapper utility machine. The attached approved board is the sole design source. This is a two-panel comparison of uncertain details, not a redesign. Flat light grey background, even studio light, chunky crisp bevelled machinery, restrained worn enamel, no scenery.
Title "MAG TRAPPER — ALTERNATE READINGS". Subtitle "Unapproved alternatives; resolve against source before modelling".
LEFT panel "A · SIX-DISC MAGAZINE". Show a large closeup of the rear magazine carrier and its nearby oxide/bone chassis plates and black hydraulic hose copied from image 1's HOME NICHE inset. Exactly SIX broad charcoal discs in one vertical stack, with five clearly separate gaps. No seventh cap that looks like a disc, no doubled stack, no other new mechanism. This explores whether that inset shows six stored discs rather than the main image's five. Retain disc thickness and rim profile; the stack therefore rises by one disc pitch. Thin leader to "Six stored discs; count unresolved". No new logo or lettering on the machine.
RIGHT panel "B · SHALLOW FLOOR PAN". Show the board's circular floor component in three-quarter and straight-down views. Same thick charcoal outer ring, oxide base flange, broad bone/brass bracket plates and large dark bolts as main board. Alternate reading: the central dark region is a shallow recessed charcoal bottom plate rather than an open through-hole. Make this floor plate clear, a single plain recessed circle. No emitter, no spokes, no motor, no invented pattern. Caption "Closed shallow bottom; underside unseen". Thin section diagram below with a simple U-shaped cross section, caption "SECTION — INFERRED". No dimensions, because not established.
Footer "Independent alternatives. Neither changes the crane, cab, crew, legs or existing markings."
Use oxide #9b513a, charcoal #242a28, bone #d2c5a5, brass #d9b44a, sandstone #c6a274 localized wear. No mint, no hazard body paint, no scenery, no extra accessories. Exact approved style, original design only.
```

## Generator output directory

All named generator outputs are under `<local path>`.
