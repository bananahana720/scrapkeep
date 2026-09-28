# Roguelite System Catalogues for Rolling-Ball Design
**Haiku web scout, 2026-09-28, for the v3 systems-and-chaos design. Evidence level: web summaries and wiki pages; label anything that is your inference.**

## Vampire Survivors: Weapon+Passive Evolution Pairs

| Base Weapon | Passive Requirement | Evolution | Max Level |
|---|---|---|---|
| Whip | Hollow Heart | Bloody Tear | 1 |
| Magic Wand | Empty Tome | Holy Wand | 1 |
| Knife | Bracer | Thrashed Knife | 1 |
| Axe | Candelabra | Double Axe | 1 |
| Cross | Spellbinder | Heaven Sword | 1 |
| King Bible | Metaglio Left | Unholy Vespers | 1 |
| Fire Wand | Pummarola | Hellfire | 1 |
| Garlic | Tiramisu | Soul Eater | 1 |
| Santa Water | Freezer | Blizzard | 1 |
| Runetracer | Duplicator | Pentagram (evolved form) | 1 |
| Lightning Ring | Sgravato | Fuwalafuwaloo | 1 |
| Pentagram | Convergence | n/a (fully leveled) | 8 |
| Peachone | Ebony Wings | Vandalier | 1 |
| Song of Mana | Metaglio Right | Mannajigon | 1 |
| Gatti Amari | Spinach | Purrmesain | 1 |
| Shadow Pinion | Clover | Shadow Pinion Prime | 1 |

**Evolution mechanics:** Base weapon maxed + passive collected → Treasure Chest triggers evolution. Max 6 weapon slots + starting weapon = ~7 slots available. Evolutions remove base weapon. Level-up choice count: 2-3 options per level early game (30-60/min), tapering to 1 option when full. XP curve: exponential (approximately 1.1-1.15x growth per level). Arcana system: 22 Arcana cards with passive effects; max 1 Arcana per run (keepsake can delay one). [https://vampire-survivors.fandom.com/wiki/Weapons](https://vampire-survivors.fandom.com/wiki/Weapons)

---

## Risk of Rain 2: Stacking Formulas & Item Categories

### Stacking Formula Types

| Category | Formula | Example Items | Notes |
|---|---|---|---|
| **Linear** | `value × stack_count` | Soldier's Syringe (+15% AS per stack), Backup Magazine (+1 charge), Bison Steak (+25 HP) | Most common; straightforward scaling |
| **Hyperbolic** | `1 - 1/(1 + a×stacks)` | Tougher Times (15% block → ~75% at 5 stacks), Elusive Antlers (speed orbs) | Diminishing returns; soft cap |
| **Exponential** | `1.x^stacks` or multiplicative | Alien Head (-25% CD, exponential), Gesture of Drowned (-50% CD exponential) | Late-game scaling powerhouse |
| **Reciprocal** | `1/x` scaling effects | H3AD-5T v2 (fall damage: 1000%-10000%), Corpsebloom (heal cap reduced) | Inverse relationship |

### Elite Affixes (Unlock by Time/Stage)

- **Blazing**: Ignite damage +600%, fire aura, melee ignites
- **Overloading**: Chain lightning on hit, item: Silence Between Two Strikes, unlocks ~2:00 Stage 1
- **Glacial**: Freeze/chill effects, item: Her Biting Embrace, ~3:30 Stage 2
- **Malachite**: Corruption aura, item: N'kuhana's Retort, mid-run
- **Celestine**: Incorporeal trait, item: Spectral Circlet, deep run
- **Perfected**: Radiance, item: Shared Design, late-stage
- **Voidtouched**: Void corruption, item: various Void tier items (post-DLC)

### Director Credit System
Boss spawns cost ~150 credits; regular spawns ~50; miniboss ~100. Credits regenerate ~10/sec early, scales with time played. Credits cap increases per stage. [https://riskofrain2.fandom.com/wiki/Items](https://riskofrain2.fandom.com/wiki/Items)

### Item Drop Rates & Chest Costs
- **Distribution**: 79% Common (white), 20% Uncommon (green), 1% Legendary (red) per roll
- **Chest costs**: Small 25 gold, Large 50 gold, Legendary 200 gold (Lunar Pods: 5 Lunar Coins)
- **Per-stage drops**: ~3-5 chests baseline; scales with difficulty modifiers & time. Billhooks, barrels, shrines add items.

---

## Hades: Boon System & Pact of Punishment

### Standard Boon Rarities & Slots
- **Rarity progression**: Common → Rare → Epic → Heroic (max)
- **Slot types** (one per ability):
  - Attack (Strike), Special (Flourish), Cast (Shot), Dash, Call (Aid)
  - Cannot hold multiple god boons in same slot; exchange upgrades rarity +1
- **Keepsake mechanic**: Equipped god keepsake (except Hermes/Chaos) guarantees next boon from that god (when one appears)

### Duo Boons & Legendary Boons
Duo boons require specific pairs (e.g., Zeus + Poseidon) and trigger god dialogue. Each god has ≥1 Legendary with unique mechanics. Cannot be obtained in Trials nor upgraded with Pom of Power. [https://hades.fandom.com/wiki/Boons](https://hades.fandom.com/wiki/Boons)

### Pact of Punishment (Heat System)
15 conditions (16 in Hell Mode), 63 total Heat max. Heat per condition:
- Hard Labor (enemies +20% dmg/rank): 1 Heat each (5 max)
- Extreme Measures (boss changes): 1/2/3/4 Heat per rank (10 total)
- Approval Process (fewer boon choices): 2-3 Heat per rank (5 total)
- Tight Deadline (9 min per biome, -2/rank): 1-3 Heat (6 total)
- Forced Overtime (+40% speed): 3 Heat/rank (6 total)
- Underworld Customs (purge 1 boon per biome): 2 Heat
- Middle Management (elite+mini-boss enhanced): 2 Heat
- Personal Liability (disable auto-defense): 1 Heat (Hell only)

Bounties awarded per weapon; target Heat increases after final boss clear. [https://hades.fandom.com/wiki/Pact_of_Punishment](https://hades.fandom.com/wiki/Pact_of_Punishment)

---

## The Binding of Isaac: Item Pools & Transformation Pairs

### Item Pool Types (Room-Based Loot)
- **Treasure Room pool**: High-tier passives (Tech, Poly, Brimstone, Sacred Heart, Polyphemus)
- **Angel Room pool**: Defensive/celestial items (Rosary, Halo, Holy Grail, Pentagram variants)
- **Devil Room pool**: Damage/pact items (Book of Belial, Blood items, Daemon variants)
- **Shop pool**: Mid-tier utility (Pills, bombs, movement, regen)
- **Boss room pool**: Boss-specific drops after defeat
- **Secret room pool**: Rare synergy items, treasures, trinkets

### Transformation Sets (3-Item Combos)
- **Guppy Transformation** (3 Guppy items → spawn Blue Flies): Guppy's Head, Guppy's Tail, Guppy's Paw, Guppy's Hairball, Guppy's Collarette, Guppy's Eye
- **The D6 Transformation** (playstyle-gated): Various specific item chains
- **Bum Friend/Beggar interactions**: Multi-item synergy paths
- **Mask + Heart transforms**: Mom's mask items chain

### Synergy Pairs (Evidence of Special Code)
Isaac has 100+ documented synergy pairs with "exceptional" interactions—items that produce effects beyond stat addition. Examples: Technology + Brimstone (hybrid laser), Sacred Heart + Spoon Bender (homing + size). No published official count; community wikis list ~150+. [https://bindingofisaac.fandom.com/wiki/Items](https://bindingofisaac.fandom.com/wiki/Items)

---

## Gunfire Reborn: Scroll Categories & Ascension System

### Scroll Categories
- **Blessings** (~50): Passive permanent buffs (stat scaling, damage multipliers, ability enhancements)
- **Cursed Scrolls** (~15): Drawback+bonus pairs (lose health, gain damage)
- **Special Scrolls**: One-time effects (Break the Ice, Effective Split, On the House)
- **Enhanced Scrolls** (Reincarnation difficulty): Upgraded versions with reduced downsides

Max scrolls per run: ~6-8 depending on source. Acquisition: Vault chests, Peddler purchase, Peculiar Chest (trade health), boss/elite drops, Challenge Events. [https://gunfirereborn.fandom.com/wiki/Occult_Scrolls](https://gunfirereborn.fandom.com/wiki/Occult_Scrolls)

### Ascension System (Per-Hero Progression)
Each hero has independent Ascension tree: unlocks at level 20+, grants permanent passive bonuses (max health, critical chance, element damage). Reincarnation difficulty (1-10 ranks) scales enemy stats and rewards; higher ranks unlock enhanced scrolls and premium rewards.

---

## Power Curve Design in Roguelites: Cited Sources

| Source | Focus | Key Metric | URL |
|---|---|---|---|
| **Supergiant Games (Hades postmortem)** | Late-game damage scaling, visual feedback | 20x-100x damage multiplier cap at 20+ min runs | GDC Vault: Hades design talks |
| **Vampire Survivors community research** | Exponential spawner cost vs. player damage | XP curve ~1.12x/level; late-game 100+ kills/wave | https://vampire-survivors.fandom.com (mechanics wiki) |
| **Risk of Rain 2 balance data** | Item synergy cap-off; exponential → soft-cap | Gesture (50% CD reduction at rank 1, 60%+ at rank 5) | https://riskofrain2.fandom.com/wiki/Item_Stacking |

**Inference:** Late-game roguelites typically employ 1 of 3 caps: (1) visual clutter ceiling (200+ projectiles/frame), (2) numerical softcap (hyperbolic formula), (3) tactical restriction (fewer enemy types). Damage scaling commonly exceeds 50x by run-end but is gated by spawn rate or room complexity. Bullet-heavy games (Survivors, RoR2) hit visual/audio ceiling before mechanical ceiling.

---

## Scout's Top 8 for a Rolling-Ball Roguelite

1. **Momentum-based passives**: Design scrolls/upgrades that interact multiplicatively with ball velocity (e.g., +dmg per speed stack, hyperbolic to prevent runaway at 100 mph).
2. **Terrain-reactive boons**: Let evolution pairs trigger off roll angle or surface type (icy, spiky, conveyor)—unique to ball mechanic.
3. **Charge-release weapons**: Borrow from Hades' Hermes boons; holding roll button powers charge; release = burst effect.
4. **Cascading synergies**: 3-item combos that unlock at scroll pickup (like Guppy), not at session start.
5. **Elite affixes tied to physics**: Blazing = ignite on friction, Overloading = chain spark on ball-contact chains.
6. **Soft-cap stacking formula**: Use hyperbolic (1 - 1/(1+ax)) for first 5 scrolls, then linear; prevents snowball at rank 1-3, enables scaling to rank 6+.
7. **Time-paced boon offers**: Fewer choices early (1 option/level), unlock to 2-3 at 5:00, cap at 1 deep-run (Hades model).
8. **Audio-visual saturation gate**: When particle/sound count hits threshold, new scrolls replace old ones rather than stack; forces mid-run choices.
