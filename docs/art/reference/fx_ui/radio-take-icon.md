# Radio take icon (purpose note)

Written before drawing. Concept only. Follows `sketches/core-loop/VISUAL-LANGUAGE.md` section 5 and the generator `sketches/core-loop/tools/icons/generate_icons.py` (id `radio_take`, no backplate, near-white glyph so the card can tint it).

- **Fact it carries:** this card is a radio take, not a jukebox record. It shows on the HUD plate beside the name when a take is found (`hud.gd`), at 26 px, tinted by tier: mint for a take, sandstone for a B-side, brass for a legend (the legend edge `radio_page.gd` already uses).
- **Mark it echoes:** the radio chip's knob, drawn in code in `src/ui/radio_dial.gd`: a ring round a dial with its needle pointing off-centre. Same silhouette, so the plate and the chip read as one thing.
- **How it differs from the record's wave at 26 px:** the record wears the drawn wave, a horizontal sine band with no closed shape. The take is a closed ring with a centre dot and one diagonal needle. A band and a ring do not share a silhouette, so the two cards stay apart with the words covered.
