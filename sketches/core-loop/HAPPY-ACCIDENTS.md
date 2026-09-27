# Happy accidents

Andrew's rule (2026-09-27): "making sure we do things in a standardized manner so we wouldn't have any unforeseen bugs or hidden glitches or exploits ... But also exploits can be fun too if they're accidental in a fun way."

This file is where the two meet. The item fuzzer (`tools/item_fuzz.gd`, DESIGN-V2 section 7) plays random legal builds and lists anything that escapes an invariant or runs far past its peers. Andrew marks each line **KEEP** or **KILL**:

- **KEEP** promotes the combination to a named or unnamed synergy row.
- **KILL** becomes a bug card.

Nothing here is patched silently.

## Designed happy accidents (shipped)

These five are bounded on purpose. They are fun because they are rare and capped, not unlimited (I2 section 3).

| Part | Rarity | Trigger | What happens | The bound |
| --- | --- | --- | --- | --- |
| Scrap Geyser | rare | on_pickup | 4% of pickups burst nearby enemies outward, fast enough to pin | one burst per pickup, at most 6 enemies, 1 copy counts |
| Echo Charge | rare_plus | on_charge_release | 10% chance a release echoes as a smaller ring | one echo per release, 1 copy counts |
| Feedback Loop | rare, Kest | on_kill | a kill while cloaked extends the cloak 0.4 s | waits on combat's `extend_cloak`, so it is not offered yet |
| Momentum Thief | uncommon | on_damage_taken | a chip hit pushes you 5% faster | 5 copies at most, never past 40 m/s |
| Domino Wire | rare_plus | on_smash | after a smash, a pin has a 20% chance to fling its victim into the next enemy | chain depth 1, at most 3 per smash window |

## Fuzz anomalies for KEEP or KILL

Pending the 200-seed run.
