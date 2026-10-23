# Waking reference-sheet review

## Result

The two requested sheets and one ambiguity variant are saved. They are visual construction studies, not approved geometry or reliable dimensioned tracing references. The image generations retain the recognizable assembly, but do not satisfy the requested exact part, proportion, marking and common-scale consistency. Do not use the printed scale bar to size a mesh.

The approved Waking board remains the geometry authority. The palette, shape and materials boards were supplied as finish references only. No gameplay implementation or rig behavior was verified.

## Files and verification

| File | Size | Purpose |
| --- | --- | --- |
| boss_waking-turnaround.png | 1086 x 1448 | Five whole-body views and a pilot-ball reference |
| boss_waking-details.png | 1536 x 1024 | Six captioned closeups |
| boss_waking-variant-1.png | 1536 x 1024 | Alternative reading of the cropped upper column |
| PROMPTS.md | Text | Exact prompts for saved images and rejected attempts |

All PNG signatures, chunk checksums and compressed image streams passed validation using Python's standard library. Pillow was unavailable; no installation was needed. Visual checks used the actual generated images against the supplied board. No code altered image pixels. This directory is not a Git repository, so no commit was made.

## Turnaround checked against image 1

| View | Checked and retained | Remaining discrepancies |
| --- | --- | --- |
| Front | Upright stepped column, broad collars, heavy intake vanes, paired closed covers, two bone handles, lime central seam, rightward bore housing | The covers and handles are shorter relative to the column than in the board's closed inset. Tier heights and collar thicknesses are interpreted. Wear patches and rune sequence are not exact copies. |
| Right side | Bore faces the viewer, column remains vertical, outer intake vanes surround the opening | Distal opening, concentric mouth rings and connection are inferred. A pointed cover above the opening is not established by the board. The view repeats front-like rune placement without proof of side placement. |
| Back | Bore extends left, plain vanes replace the front handles | Rear panels, glyph distribution and supports are invented continuations of visible construction. Front and rear outlines are close but not identical in pixel size. Rear pipe length/rib spacing does not exactly agree with the front. |
| Three-quarter front | Closed paired covers, right-side bore, nested collars and flared intake remain recognizable | Scale differs from the elevations. Cap rim appears as an extra inset ring. Vane spacing, wear and proportions do not exactly match the front. |
| Top | Circular cap, concentric structure, radial vanes and rightward conduit; improved from the tilted first attempts | Hidden construction is inferred. Vane sectors spread like petals, which may not reconstruct the board's heavier overlapping vanes. Door handles remain faintly visible near the front edge despite the requested vertical plan. Cap and collar diameters are not dimensionally reconciled with the elevations. |

The pilot ball is present and labelled 1.84 m. Its drawing is too large relative to the labelled 8.0 m machine. Visual estimates put the ball near 29 percent of the front-view height, while those labels require 23 percent. The printed 60 pixels-per-metre note also disagrees with the image. These are illustration errors, not alternative measurements.

## Details checked against image 1

| Panel | Checked and retained | Limits |
| --- | --- | --- |
| Service seam, closed | Two broad petrol plates, central lime band, one bone handle with two dark fasteners on each plate | Wear pattern, glyph shapes and handle dimensions are approximate. |
| Bore jam, open | Plates displaced to either side; horizontal bone shaft, annular lime-marked sleeve, dark supports and lower support | The unseen hinge axes, opening travel and rear support geometry are not established. The image adds minor fastener detail to the shaft. Left handle is occluded; do not delete it in the model. |
| Charged reel | Same open bay, pilot gyrosphere, mint charge at the left hub, rope and right-hand reel | Reel mounting and rope attachment are unresolved. The initial invented yellow feet were removed. Remaining dark support under the reel is still not confirmed. Gyrosphere details are illustrative, not a replacement for its own approved model reference. |
| Collars and ancient seam | Stepped shell, raised collar and vertical lime channels | Collar count and spacing around the crop are interpreted; small panel fasteners and exact glyph sequence are not proven. |
| Intake and bore | Heavy vanes, closed paired service covers and adjacent segmented bore | First generation lost the handles and introduced coral paint. Correction restored the paired covers and removed the bright coral patch. Bore rib spacing and termination remain unverified. |
| Crew bridge | Separate timber deck, posts, simple rails, braces and metal connections beside the column | It is an isolated representative section, not the board's complete multilevel bridge. Bracket and bolt arrangement was elaborated by the generator. Do not treat this as a full bridge fabrication reference. |

## Inferred construction

1. A finite 8.0 m machine height. The board crops the upper column, so its total height cannot be recovered.
2. A flat circular terminal cap. The inset perimeter ring in the three-quarter view was not requested and is unsupported.
3. A 6.0 m radial base, 3.8 m upper cylinder, 2.2 m bore and 10.5 m overall width. All are proposed proportions, not measured canon. They are also not faithfully drawn to scale.
4. Eight intake sectors, with the front sector divided into paired covers. The board does not establish the hidden vane count.
5. Plain repeated rear vanes, rear shell panels and continued longitudinal glyph channels. Their exact positions are unknown.
6. A low lateral connection between the base and horizontal bore housing. The board shows the visible external relationship but hides the internal junction.
7. A plain terminal bore opening. Its concentric end rings, wall thickness and full housing length are not visible enough to establish.
8. Dark internal supports, shaft fasteners and the arrangement behind the open service bay. Visible source supports guided the drawing, but hidden construction remains guessed.
9. Outward plate motion and hidden hinges. The board shows states, not a complete kinematic mechanism. No hinge location or clearance has been proven.
10. A supported right-hand reel and its rope attachment. Ownership, exact mount and the complete load path are unclear.
11. The bridge's hidden bracing, attachment clearances and metal brackets. It remains a separate environment asset.
12. Wear and rune placement on surfaces not shown in the board. Generated wear is not a consistent texture map.

No legs, wheels, weapons, eyes, faction marks, HIRED stamps, crew numbers or gloves were added. None of those body markings are visible on this board. Caption text is annotation, not a decal specification.

The ancient lime #9dff3c follows the approved board even though it is absent from the user's shortened palette list. Mint #8bf0d3 is confined to charged interaction. Hazard coral was treated as a danger footprint, not body paint. Exact albedo hex values cannot be certified from shaded generated pixels; assign the supplied hexes explicitly in the material setup.

The surrounding canyon, rubble, hazard footprint and complete crew workshop were intentionally excluded from the body turnaround. The bridge appears separately in the details sheet.

## Variant

boss_waking-variant-1.png shows the upper cylindrical shell continuing beyond the approved board's crop instead of terminating at an invented cap. The zigzag is a drawing break, not a broken metal edge. This is a local ambiguity study; it does not replace the entire body sheet.

The variant's lower crop and collar arrangement remain approximate. Its boundary bracket indicates the conceptual crop, not a surveyed source-image coordinate. Total height and terminal shape remain open.

## Regeneration record

- Turnaround initial generation added rubble, a raised cap, a tilted plan and inconsistent view scales.
- First correction did not resolve those defects sufficiently.
- Regeneration from the original boards improved the layout, removed rubble and produced a more useful plan. It still failed exact scale, wear, rune and part consistency.
- Details initial generation added yellow reel feet, a coral pipe patch and a front seam without the paired handles.
- Details correction removed the yellow feet and coral patch and restored paired handled covers in the intake panel.
- One upper-column variant records a genuine source ambiguity.

Rejected PNGs remain in review-history. PROMPTS.md records the exact text sent for all six generation calls. The remaining differences above are unresolved, not accepted changes to the design.

## Questions for the modeller and art owner

1. Does the column terminate above the crop, or continue into larger machinery? Confirm total height and top construction before modelling the cap.
2. What are the boss dimensions relative to the fixed 1.84 m pilot ball? Resolve these before using any sheet as a background reference.
3. How many intake vanes exist around the base, and which sectors make the service covers and bore connection?
4. Do the paired covers pivot, slide or combine both motions? Confirm axes, travel and collision clearance around the shaft and pilot sphere.
5. Does a bore jam open the service seam, or does the opening follow a floor breach? The board's proposed default remains bore jam.
6. What is the complete bore length, distal opening and connection to the column?
7. Is the right-hand reel part of the boss, fixed site equipment or the interaction apparatus? Confirm its mount and rope endpoints.
8. Where does the independent crew bridge attach, if anywhere?
9. Which rune sequence and wear patches need exact preservation? Build one shared texture layout after geometry is settled.

The next reliable modelling step is one shared blockout viewed through orthographic cameras, with the approved board controlling visible parts. That would resolve cross-view geometry and scale together. These generated sheets alone do not establish that consistency.

## Saved image hashes

- boss_waking-turnaround.png SHA-256: 05d0f3d5607af26fc936edab97412bf3618dfcb15cbc0d50b0de1c54d6d48a24
- boss_waking-details.png SHA-256: 3137593eaebb7c1a9d913b6b3a68115db6009ed0a4e97c59a8c3bb52fefb16d6
- boss_waking-variant-1.png SHA-256: 1daa0be727d6678db4beea341884903c1d43edf9b87b5c5ec73e73297836ae1a
