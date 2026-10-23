# Vent Louvre reference review

Status: generated reference art with unresolved specification deviations. Not approved as exact construction drawings.

## Files and method

- `panel_vent_louvre-onball.png`: single-panel and six-panel installation views.
- `panel_vent_louvre-details.png`: face, edge, back with socket boss, closed/open slats, and hinge close-up.
- Both PNGs were generated and revised with the built-in image_gen tool. No programmatic painting or retouching. Prompts are in `PROMPTS.md`.

## Checked

- Six-sided stamped frame, raised rim, bevels, panel seams, four corner mounting bolts, fleet stencil `17`.
- Detail sheet shows five horizontal blades, closed and open, a common link bar, hinge/crank close-up, and small white steam puff. Edge view is captioned OPEN to match its blade pose.
- Bone faces, steel edges and charcoal recesses; petrol lattice and brass joints confined to the ball. No glow, prohibited accent colours, characters, scenery or unrelated logos. Shaded pixels are not exact hex-colour samples.
- Both on-ball spheres have matching visible diameter and 1.84 m labels. One and six installed panels are shown. Plate width is labelled 0.45 m; mounting radius is 0.92 m; projection limit is below 0.25 m.
- The 0.30 m plate height, 35-degree opening and fleet number 17 are design choices for this sheet, not externally verified canon identifiers.

## Remaining deviations

- **Blade-count mismatch:** the selected on-ball grilles still read as four blades, unlike the five-blade detail sheet. Multiple edits and a full redraw did not reliably fix this. Model exactly FIVE blades from the detail sheet.
- **Scale/drafting mismatch:** the on-ball centre panel is approximately 27% of the sphere diameter; the specified ratio is 24.46%. Some dimension extension lines terminate inside the true extents. The detail back view is slightly larger than the face view. Use the stated dimensions, not pixel tracing.
- The on-ball closed grille appears partly open. Four charcoal fasteners and stencil 17 are clearer in the detail sheet; their shape/size varies in the small installation views.
- Face, edge and back use orthographic-style presentation, but generated images do not prove true parallel cameras or exact cross-view geometry. Spherical fit, socket alignment, hinge clearance and simultaneous blade motion require reconstruction and checking in 3D.
- The lattice conveys an articulated hollow sphere; its Hoberman folding mechanism is not validated. Colour-free recognition at 20 m has not been tested in-game.

Earlier rejected passes had an eight-sided frame, oversized installation panels, inconsistent slat counts and misleading hinge leaders. Revisions improved these, but the outstanding items above prevent a full specification pass.
