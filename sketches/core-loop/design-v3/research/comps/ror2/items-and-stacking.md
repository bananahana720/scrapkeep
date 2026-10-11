# Items and stacking: tiers, families, proc chains and the damage pipeline

Evidence: static code read of a decompiled study copy (level 2, the damage order walked to level 3). Shipped weights and costs live in prefab data and are marked so. One wiki page (public) supplies the difficulty formula cross-check.

## What it does

Every pickup belongs to a tier. A tier is a data object with a color, upgrade links and a drop weight. A chest draws a tier by weight, then an item inside the tier. Chest prices rise with the run's difficulty. Every stat on a character reads item counts from one inventory call and feeds each count through a named formula family. Hits can trigger item effects ("procs"); each effect is gated by a coefficient on the hit and by a bit mask that stops the same effect chaining on itself. Damage then passes through a fixed order of reductions before it reaches health. Unwanted items turn into scrap, and printers and cauldrons trade many items for one of a higher tier.

```mermaid
flowchart LR
  Chest[Chest: price scaled by difficulty] -->|tier by weight| Tier[Tier data object]
  Tier --> Item[Item]
  Item --> Inv[Inventory count n]
  Inv --> Fam{Stack family}
  Fam -->|linear| L[+k n]
  Fam -->|exponential| E[2^n - 1]
  Fam -->|hyperbolic| H[1 - 1/(1+kn)]
  Inv --> Proc[Hit: roll coefficient x count x chance]
  Proc -->|chain mask bit free?| Child[Child effect, own coefficient]
  Child --> Mask[Set bit, chain cannot repeat the type]
  Hit[Damage] --> A[Armor] --> P[Plate flat] --> O[One-shot cap] --> C[Crit] --> B[Barrier, shield, health] --> X[Execute thresholds]
```

## Parameters

| Parameter | Value | Source |
|---|---|---|
| Tier enum | Tier1=0, Tier2=1, Tier3=2, Lunar=3, Boss=4, NoTier=5, VoidTier1-3=6-8, VoidBoss=9, FoodTier=10, Cursed=11, Page=12, Hex=13 | RoR2: ItemTier |
| Tier weights default (Tier1 / Tier2 / Tier3) | 0.8 / 0.2 / 0.01; Boss, Lunar, Void, Hex, Page default 0 | RoR2: BasicPickupDropTable (tier weight fields) |
| Shipped tier weights | not in code | prefab data |
| Chest tier chances default | same 0.8 / 0.2 / 0.01 | RoR2: ChestBehavior (tier chance fields) |
| Chest drop count default | min 1, max 1 | RoR2: ChestBehavior (drop count fields) |
| Difficulty-scaled price | `(int)(base x coefficient^1.25)` | RoR2: Run.GetDifficultyScaledCost |
| Base chest price | not in code | prefab data |
| Difficulty coefficient | `(0.7 + 0.3 players + 0.0506 x scaling x players^0.2 x minutes) x 1.15^stagesCleared` | RoR2: Run (difficulty coefficient update) |
| Difficulty coefficient, wiki form | `(1 + 0.3(N-1) + T x 0.0506 x D x N^0.2) x 1.15^S`, D 1 to 3 | wiki: https://riskofrain2.wiki.gg/wiki/Difficulty |
| Linear damage item | +0.1 damage multiplier per stack | RoR2: CharacterBody (RecalculateStats damage block) |
| Linear attack speed | +0.1, +0.15, +0.075 per stack (three items) | RoR2: CharacterBody (RecalculateStats attack-speed block) |
| Armor item | armor x= 1 + 0.1 n | RoR2: CharacterBody (RecalculateStats armor block) |
| Exponential damage | `2^n - 1` | RoR2: CharacterBody (RecalculateStats damage block) |
| Exponential drone upgrade | `2^n - 1` | RoR2: CharacterBody (drone upgrade block) |
| Hyperbolic helper | `1 - 1/(1 + x)` percent and normalized forms | RoR2: Util.ConvertAmplificationPercentageIntoReductionPercentage |
| Hyperbolic execute-elite threshold | 13% per stack, hyperbolic | RoR2: CharacterBody (execute threshold) |
| Hyperbolic first stack plus smaller per-stack | `GetHyperbolicReductionCoefficient(stacks, base, perStack)` | RoR2: Util.GetHyperbolicReductionCoefficient |
| On-kill chance | `1 - 1/(n+1)^0.33` | RoR2: GlobalEventManager (on-kill roll) |
| Frost slow | `1/(1 - 0.1 n)`; penalty `0.7 x 0.9^n` | RoR2: CharacterBody (RecalculateStats move speed block) |
| Default proc coefficient | 1 | RoR2: DamageInfo.procCoefficient |
| Child orb coefficients | 0, 0.2, 0.3, 0.33 by source | RoR2: GlobalEventManager.OnHitEnemy |
| On-hit chance form | `procCoefficient x count x X` | RoR2: GlobalEventManager.OnHitEnemy |
| Luck roll | `ceil(abs(luck))` extra rolls; positive luck keeps best, negative keeps worst; chance <= 0 always fails | RoR2: Util.CheckRoll |
| Sure-proc flag | bypasses the roll | RoR2: DamageInfo (sure-proc field) |
| Chain mask | 32-bit mask, one bit per proc type, up to 32 types | RoR2: ProcChainMask, ProcType |
| Armor curve | factor `100/(armor+100)` for armor >= 0; `2 - 100/(100 - armor)` below; damage floor 1 | RoR2: HealthComponent.TakeDamageProcess |
| Armor plate | -5 flat per stack, floor 1 | RoR2: HealthComponent.TakeDamageProcess |
| One-shot protection | caps one update's damage at (full health + barrier) x 0.9 | RoR2: HealthComponent.TakeDamageProcess; fraction 0.1 in CharacterBody.oneShotProtectionFraction |
| Crit multiplier | `2 + 1 per crit-damage stack` | RoR2: CharacterBody (critMultiplier) |
| Crit chance per stack | +10 | RoR2: CharacterBody (RecalculateStats crit block) |
| Execution thresholds | low-health 0.25; frozen 0.3; suffocate 0.2 | RoR2: HealthComponent (lowHealthFraction and execute fields) |
| Scrapper batch | up to 10 items per use | RoR2: ScrapperController |
| Scrap tiers | white, green, red, boss, page scrap | RoR2: PickupCatalog |
| Items per scrap | not in code read | prefab data |
| Cauldron input | 3 items to upgrade a tier, up to 6 taken, options `3 + taken/3` | RoR2: DrainItemsAndDropMultiChoicePotentialController, DrainingItems |
| Assembly-station cap | 1 | RoR2: DroneAssemblyStation |
| Interactable credits per stage | 220 to 520 across the base stages | wiki: https://riskofrain2.wiki.gg/wiki/Directors |

## Why it works

Three structural choices keep high stack counts readable. The first two are code facts, the third is the code shape plus an inference:

1. **One input, named formulas.** Every stat reads a stack count from one inventory call (`CharacterBody.cs:4905-4986`). The only item input is the count, so a player's mental model is "more of this item makes this number move", and each item names its formula family. Linear is plain, exponential is a big spike, hyperbolic approaches a ceiling.
2. **Tiers and weights are data.** The economy changes by editing a tier object, not stat code. Upgrade links connect tiers, so a printer or cauldron move is a data relationship.
3. **Proc coefficient plus chain mask.** Each source rolls on its own coefficient (child effects are weak, 0 to 0.33). A mask bit forbids the same type repeating in one chain, so a chain ends instead of exploding. Distinct sources can still combine. Inference: many weak sources beat one stacked item, which is why build variety survives high counts.

Hyperbolic stacking adds less per stack and approaches but never reaches 100%. That readable-ceiling shape is inference from the formula, not a developer statement.

One flagged oddity: the cauldron's cost expression uses integer division and looks like an operator-precedence bug (`DrainingItems.cs:277`; inference, not run).

## What Scrapkeep borrows

Principle: **readable-capped scaling**. The relationship is: stat value comes from a count through a small set of named curves, a ceiling curve is the default, and the chain of effects is bounded by a per-hit mask. Bible sections it would amend: "Inventory, equipment and transformations" (`BIBLE.md:546`) and "Themed loot, attunement and fixed secrets" (`BIBLE.md:556`). It would also give the "powerful build earns an additional energetic layer, not an indefinitely rising master volume" line of the music section (`BIBLE.md:749`) a matching rule in items: power earns breadth and a visible layer, not an unbounded number. Proposed rules (design inference):

- Three families only: linear (flat numbers), ceiling (hyperbolic; default for percent effects), spike (exponential; at most one per tier and always capped).
- A per-hit chain mask so bot, weapon and item effects cannot loop through each other.
- A small proc coefficient table: heavy hits 1, child effects 0.2 to 0.35.
- A scrap economy where the scrap type matches the tier, and where a conversion step has a visible, fixed ratio (RoR2's ratio is not in the code read, so Scrapkeep must set its own).

## What it must not copy

- Item names, tier colors and the item list.
- Exponential families without a cap. RoR2 ships `2^n - 1` for damage and a lunar curse, and drone upgrades; at 6 stacks that is 63 times base.
- A difficulty coefficient that scales player count and time together. The Bible wants an open stage and readable pressure, not a time-hardened clock (see TADR-010 for the open-stage direction).
- Hidden loot weights. Weights live in prefab data in the source, so a player cannot read them. Scrapkeep should show what a chest can yield.

## Lab measure

Add a headless "stack sweep": for each item family, apply stacks 1 to 20 to the same dummy and print the stat, then print the time to kill a fixed target. Pass when (a) every ceiling-family stat at stack 20 is below its stated cap and rises monotonically with decreasing steps, (b) no item spike exceeds a declared multiple of base (propose 8x), and (c) a chain test with five distinct effect sources fires each at most once per hit, with zero repeats of any type within a single chain.
