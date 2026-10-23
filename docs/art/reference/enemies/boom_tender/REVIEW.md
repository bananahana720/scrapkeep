Lane review (23 Oct, 4080 lane): both sheets match the spec in parts, dimensions, palette and moving-part names, and the 1.84 m ball sits in every view. Deviations for the modeller: the HIRED stamp is repeated on the hull (the spec wants one small stamp by the 22, plus one on the reel housing); the turnaround draws the left side only, as asked, so the right side is a mirror apart from the exhaust stack at back left.

# Boom Tender No. 22 — reference review

Both PNGs were generated and revised with the built-in image_gen tool. Reviewed each returned image visually; checked saved PNG chunk checksums and image-data decompression with Python's standard library because Pillow was unavailable. These are useful design references, but **not dimensionally reliable sculpting turnarounds**. Repeated correction passes improved counts, markings, track separation and sweep pose without resolving all projection errors.

## Checked

- Turnaround includes front, left side, back, front-left three-quarter and overhead panels. Details include fairlead, float/link, overhead left sweep, two-half opening with water spray, and exploded assembly.
- Five floats plus one smaller buoy are visible in each unoccluded straight boom and in the sweep. Each float has a stripe band and brass lamp. Front floats are occluded.
- Exploded sheet has all eleven labels: HullShell, TenderReel, TenderFairlead, TenderTrackLeft, TenderTrackRight, BoomFloat0–BoomFloat4 and BoomBuoy. Final revision removed the third, attached track.
- Cast pontoon silhouette, petrol hull, oxide reel/floats, charcoal tracks, brass fittings, sandstone wear, bone 22 and HIRED marks are present. No purple, face, glowing eyes or weapons. Hazard orange is restricted to float bands.
- Dimension text covers 3.2 m hull length, 2.4 m width, 1.3 m hull top, 2.3 m drum top, 1.6 m drum diameter, 0.9 m float length, 0.6 m float diameter, 0.4 m gaps and 6.5 m reach. Float close-up has clearer length/diameter leaders than the turnaround.
- Palette names and all eight requested hex codes appear on the details sheet. Shaded pixels were not certified as exact albedo values.

## Remaining deviations — resolve before tracing or sculpting

1. **Scale is inconsistent.** All five turnaround panels contain a labelled 1.84 m lattice sphere, but their apparent diameters and ratios to the machine vary. Details use small reference icons rather than a common physical drawing scale; the sweep icon is smaller. Do not derive measurements from image pixels.
2. **Turnaround overhead reel axis is wrong.** Its flange edges remain along the hull length, implying a fore-aft axle. Use the transverse axle shown in the side/three-quarter views and the details sweep as the mechanical intent. Correct top projection must have the axle across hull width.
3. Front/back retain slight elevated-camera cues; front occlusion improved but is not a certified orthographic projection. The overhead panel reads as a plan, but component projections are not fully consistent.
4. Cable routing still appears to originate near the reel flange/axle rather than a clear tangent to the wound cable. The fairlead does not consistently prove a free cable path between rollers. Resolve both mechanically rather than copying the silhouette.
5. The turnaround 0.9 m leader still straddles a gap/adjacent float instead of cleanly bracketing one float. Reach/gap/diameter captions do not establish geometrically accurate proportions. The sweep's 6.5 m leader omits part of its curved connection.
6. HIRED is present near 22 and on the turnaround support, but the detail close-up puts an additional stamp on the reel flange. Hull/reel-support shapes, buoy size and fairlead mounting vary between panels. The exploded hull opening is a proposed interpretation, not a verified assembly fit.

Dimensional intent: five 0.9 m floats + four 0.4 m gaps = 6.1 m, leaving 0.4 m of the specified 6.5 m reach for end connections/terminal allowance. The 1.6 m reel measure was interpreted as flange diameter. Exact endpoint allocation needs modelling resolution.

Generation history: six returned images and one service-rejected correction. Selected the final turnaround and revised details. Full prompts: GENERATION-PROMPTS.md. No 3D geometry, assembly validation or human acceptance is claimed.
