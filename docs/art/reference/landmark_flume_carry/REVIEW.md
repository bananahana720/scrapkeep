# Flume-carry reference review

## Verdict

NOT READY FOR DIMENSIONAL MODELLING. The files are visual reconstruction candidates. They preserve the open carry and the main visible construction, but do not meet the requested exact-copy, shared-scale, orthographic-turnaround standard. Do not trace their dimensions or treat their invented hidden construction as canon. Image 1 remains the design authority.

The final turnaround's printed "ONE SCALE" claim is incorrect. Its scale bar does not calibrate every view. The printed "FRONT ORTHOGRAPHIC" label on the variant is also incorrect: that view looks down onto the floor. These labels survived generation and must not be relied on.

## Sources and scope

- Geometry authority: supplied image 1, spillway-landmarks-flume-carry.jpg.
- Finish guidance: supplied palette, shape and materials boards. They were not used to authorize additional equipment.
- User-provided anchors: pilot sphere diameter 1.84 m; carry route approximately 90 m.
- The board shows an elevated blunt flume end at left and a curved elevated flume with a concrete approach ramp at right. The ground between them stays open.
- The board does not resolve a separate powered carry mechanism, service hatch, weak point, crew number, glove or HIRED marking on the flume. None was invented. The off-route shelter and its hanging hoses were excluded from this infrastructure sheet.
- The board crops both flume continuations and hides portions of their supports. A complete surveyed asset cannot be recovered from that image alone.
- The empty carry uses a labelled layout break. It is not drawn as a 90 m measured separation and must not become a bridge or airborne route in the model.

## Saved files and iterations

- landmark_flume_carry-turnaround.png: selected third generation after two correction attempts.
- landmark_flume_carry-details.png: selected second generation after one correction attempt.
- landmark_flume_carry-variant-1.png: one alternate reading of the elevated floor material.
- PROMPTS.md: exact prompt bodies for all six generation calls, grouped by output filename. Earlier turnaround and detail prompts are retained to make the corrections reproducible.

All three saved images are 1536 × 1024 RGB PNGs, verified with the file command. They were generated with the built-in imagegen tool and copied unchanged into this directory. No manual image compositing or geometry-based rendering was performed. The generated previews were inspected individually; copying the files did not change their content.

All six exact prompt bodies were checked against PROMPTS.md. File SHA-256 receipts:

```text
dd3472c5fe8edf9b64484720c9b0663d60a73fa32dedcf88e65f2ccbdbcb72f8  landmark_flume_carry-turnaround.png
9611e3478ca1690658e26bd33ea1e8588a91a78fe8517981e148290fab0be96a  landmark_flume_carry-details.png
05d1c446515289f17b4b9ade8f60727299d6d79b6f23eed448e3c08bc8c7b2c6  landmark_flume_carry-variant-1.png
```

## Turnaround checked against image 1

| View | What agrees | Unresolved difference or limitation |
| --- | --- | --- |
| Front | Left blunt elevated opening, low timber walls, pale floor edge, petrol end covers, timber support and bolts remain recognizable. Right concrete ramp and separate flume remain. | The right unit is still angled, not a shared front orthographic projection. Front width and the pilot diameter do not agree with the printed width dimension. Hidden transverse X-bracing is inferred. |
| Right side | Straight timber rail, diagonal timber supports and the right ramp's rising profile are present. No connection crosses the carry. | The curved section still exposes depth and top faces. It is not a strict common side elevation. Repeated support spacing and total represented lengths are reconstructed. |
| Back | The final pass shows the outside timber structure of the curve instead of repeating the front-facing ramp. | This is not a reliable 180-degree reverse of the front camera. Occluded supports, back fittings and the relationship of the ramp to the curve are inferred. The left continuation lacks a consistently readable cut convention. |
| Three-quarter front | Closest visual match: left blunt mouth, pale floor, thick low timber rails, charcoal straps, petrol covers, timber trestles, right tapered concrete cheeks and open carry. | Flume lengths, rail joints, bolt pattern and curvature are regularized. Exact weathering shapes are not copied. Source portions hidden by terrain have been completed. |
| Top | Separate straight and curved channels; pale floors, low sidewalls and ramp entrance; no bridge. | Plan direction is not registered to the front view. The clear width changes on paper relative to front and pilot. Floor seams, curve radius and rail segmentation are inferred. |

The pilot spheres are present in all five rows, labelled 1.84 m. They are illustrative scale references, not proof of scale consistency. Their details vary between rows. The infrastructure cannot be measured against them reliably.

The main parts survive, but fastener placement, panel seams, support proportions and paint chips are not exact copies across views. Image generation did not eliminate these errors after the correction passes.

## Detail sheet checked against image 1

| Panel | What agrees | Unresolved difference or limitation |
| --- | --- | --- |
| Blunt elevated end | Open elevated mouth, thick rail ends, petrol covers, pale floor lip, timber beams and diagonal supports. | The incorrect lengthwise 4.0 m width dimension was removed. The remaining 0.75 m dimension is an assumption. Underfloor members and bolt positions are reconstructed. |
| Rail strap and end plate | Dark bolted strap over timber and a worn petrol end cover. | The correction reduced the stacked-board appearance, but a horizontal division remains near the right edge. Do not take it as an approved laminated/two-board construction. Bolt count and cap wrap are not established by the source. |
| Timber trestle joint | Timber upright, crossbeam, diagonal brace and bolted plates use the board's structural language. | Exact bracket shape, bolt count, beam seating and concealed joints are inferred. The close-up is not evidence of a mechanical pivot. |
| Concrete ramp and cheeks | Pale approach ramp, tapering solid side cheeks, petrol wear and transition into timber side rails. | The ramp's slope, thickness, length and concrete seam layout are inferred. The generated ground lip reads as a thin raised edge; the board does not establish that edge. |
| Curved flume bay | Segmented timber rails, pale floor, steel straps and timber supports. | Curve remains tighter than the broad source reading despite a correction request. Do not derive a bend radius from this panel. |
| Surface and markings | Natural timber, worn petrol enamel, pale concrete and absence of invented markings. | Wear is more uniformly distributed than in the board. Base hexes appear in the legend; exact pixel color matching under shading was not verified. |

No open/closed hatch pair was drawn because there is no hatch to copy. No weak point was added. The source does not establish that such features cannot exist elsewhere; it simply provides no design for them.

## Inferred construction and dimensions

1. A provisional 4.0 m clear channel width and 0.75 m low rail height. These were prompt assumptions, not measurements or approved dimensions. Their drawn ratios remain inconsistent.
2. Pale concrete/slab interpretation for the elevated flume floor. The pale concrete approach ramp is supported by the board notes; the elevated floor material is less certain.
3. Floor panel seam pattern, slab thickness and attachment to the timber frame.
4. Hidden transverse beams and longitudinal stringers beneath the floor, including their spacing and cross-sections.
5. Hidden backs of posts, duplicated trestle supports and completed lower ends where the source terrain conceals them. Their heights and support count are provisional.
6. Repeated diagonal and X-braces, brace intersections and connections on unseen faces. Visible diagonal timber bracing supports the general approach, not every generated member.
7. Backside steel straps, bolt heads, end-cover returns, bracket shapes, bolt counts and positions where the source is too small or occluded.
8. The reverse faces of timber sideboards and their symmetry across the channel.
9. Curved channel radius, rail segment lengths, floor seam layout through the curve and the number of repeated support bays.
10. Ramp length, slope, thickness, underside and full-depth cheek-wall construction. No hollow service space was inferred.
11. Exact concrete-to-timber attachment at the upper ramp transition.
12. Model boundaries at the off-image continuations. The generated views do not consistently show the requested continuation cuts, so they do not define permanent ends.
13. Relative alignment of the two depicted sections for the multi-view layout. The board supplies a scenic relationship, not a surveyed plan or a straight 90 m endpoint separation.
14. Fine wood grain, rust distribution, paint damage and hidden-face wear. Material roles agree broadly; chip shapes and quantities are not source-exact.
15. Pilot scale-reference geometry beyond the source silhouette. The ball is a reference object, not part of the flume asset.

No working water-control mechanism, propulsion device, carry cable, hatch interior, weak point or faction insignia was inferred.

## Variant 1

The alternate sheet reads the elevated floor as broad, pale, worn transverse timber decking. It preserves the blunt mouth and keeps the right approach ramp concrete. Its isolated timber end-grain inset is explicitly inferred.

The variant is an unresolved material interpretation, not an approved replacement. Its supposed front orthographic view is elevated and exposes the deck. It also changes floor joins, bracket positions and support details beyond a perfectly controlled material-only swap. Use it to discuss the floor material, not as additional geometry authority.

Only one variant was made. Other unknowns are recorded above rather than filled with speculative machinery.

## Questions for the modeller

1. Is the elevated pale floor concrete/slab construction, pale timber, or a lining over timber?
2. What are the approved clear width, rail height, trestle elevations and ramp slope? The 4.0 m and 0.75 m labels are proposals only.
3. Where does this asset end and connect to continuing flume modules?
4. What world-space curve and endpoint alignment implement the approximately 90 m open ground carry? Keep that route open in every answer.
5. Does "carry machinery" refer to the pilot's momentum test, or is there a separate approved mechanism reference missing from this board?
6. What hidden brace pattern and fastening arrangement should repeat through the straight and curved sections?
7. Is the flume depicted dry for this landmark, and does any separate water state need its own approved reference?

Before dimensional production, establish one shared 3D reconstruction from the approved board and the resolved dimensions, then render the requested cameras from that model. The current images are ready for visual review only; no owner acceptance or production readiness is claimed.
