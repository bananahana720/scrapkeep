# Customize: the scaffold and the earned items

Status: design spec, wave 13 unit A4, written 2026-10-10 on `cand/alpha-w13`. Nothing here is built or played. Paths without a prefix are under `sketches/core-loop/`. A number marked (start) is a starting value to tune in play.

Reads with: [ROSTER-LOOK.md](ROSTER-LOOK.md) (section 0 is the Hoberman mecha: the rolling lattice with its hubs and gaps, the level weapon ring and the gimballed cockpit; sections 0.3 and 5 set the gap panels by heft class and their budgets), [PILOTS.md](PILOTS.md) and the six sheets in [pilots/](pilots/) (each sheet's section 7 proposes that pilot's items), [SKILL-BAR.md](SKILL-BAR.md) (the signals the grants listen to, section 7, and B5's touch points, section 10), and `adr/TADR-004-persistence.md` (the save rules this schema change follows).

Settled today (session plan, "Decisions settled today"): scaffold the system and ship 2 or 3 earned items per pilot; leave room for pilot outfits, ball shell variants, companion skins and bay decoration beside today's paint, trail, decal and companion paint; achievements and discoveries only, nothing bought. Plan call: the mecha gains scrap gap panels by heft class (ROSTER-LOOK section 0.3), and the shell-variant slot and the heft layers share one loader path.

**Terms, once.** A **slot** is one kind of look (paint, trail, and so on). A **row** is one item in `cosmetics.gd`. The **owner** is who wears a slot: a pilot id, `spil9` for the companion, or `bay` for Moss's workshop. A **grant** is the achievement row that unlocks an item. A **discovery** is a codex trick that kit code detects and the codex announces once. A **heft layer** is one detail shell that shows at one heft class: gap panels, thicker tread caps on the hubs, or the heavy hub modules (ROSTER-LOOK section 0.3). A **variant** is a shell-slot item: a different lattice build for one pilot.

## 1. What exists today

- Four slots: `paint`, `trail`, `decal`, `companion_paint` (`src/core/cosmetics.gd:17`). A row may carry only `slot`, `pilot`, `name`, `starter`, `tint`, `asset`, `mask` (`:18`), and `validate` refuses any other key (`:99-101`). A price or cost key cannot exist, so "nothing bought" is already structural.
- 38 rows (`cosmetics.gd:23-62`). Every non-starter row is the reward of one achievement row today (`src/core/achievements.gd:36-93`).
- Equipped items save as `"<owner>/<slot>"` in one flat string map (`src/core/profile.gd:28`, `:206-211`). The companion's owner is `spil9` (`cosmetics.gd:137-138`).
- Grants: an achievement row counts a bus fact, earns once, and pays `{"cosmetic": id}` through the settle-once ledger (`src/core/progress.gd:290-299`, `:132-148`). A row cannot test which pilot is flying: `need: "class"` only checks that a class is chosen (`progress.gd:263-264`, `:283-284`). Every sheet worked round this with pilot-only ids (ability ids, ultimate ids, discovery ids).
- "Is this item worn?" is decided in three places with three copies of the ownership rule: `customize_page.gd:129-131` and `:155-160`, `cosmetic_presentation.gd:42-51`, and `hero_assets.gd:335-353`.
- The page is a column of six buttons cycled with left and right (`src/ui/customize_page.gd:13`, `:200-210`). It has no preview. Locked items are invisible; the tooltip only says they unlock through achievements (`:177`).
- One shell per pilot: `SHELLS` maps class id to one GLB (`src/presentation/hero_assets.gd:55-62`). `_fit` loads it, splits Core and Pod, paints both, and frees the old pair on a class swap (`:362-405`). The class card preview copies that split by hand (`src/ui/class_preview.gd:143-160`). No heft layers load anywhere.

## 2. Slot kinds

Eight slots. The first four exist; the last four are new.

| Slot id | Node it changes | Owner and saved key | How it renders | Budget class |
| --- | --- | --- | --- | --- |
| `paint` | every `paint` surface on HeroCore, HeroPod and every heft layer | per pilot, `<pilot>/paint` | the cached `paint` material for that tint (`hero_assets.gd:174-250`), attached by `paint()` (`:259-277`). Lattice struts and gap panels use `paint`, so a class-up keeps your colour (ROSTER-LOOK section 5). A tinted paint lerps the baked vertex colour `PAINT_TAKE` (0.6, start) toward the tint instead of multiplying, so the dark lattice takes the hue (2026-10-16, PAINT-TRACE card A2; `cosmetic_apply_test` checks that Cobalt and each pilot's starter paints pull every pilot's Core at least halfway to the tint) | none, a tint |
| `trail` | `BallTrail`, a top-level pool beside the ball (`cosmetic_presentation.gd:36-39`) | per pilot, `<pilot>/trail` | pooled cards, at most 24, never instanced per frame (`:5`, `:225-311`). New: it also draws along a set piece's flight (section 4) | `scenery`, 120 tris and 2 draws per card, as the delivered trails are (`assets/registry.json:114-116`) |
| `decal` | Pod > `DecalPlate`, the seat-back plate P-D adds (ROSTER-LOOK section 7). Fallback: the same projection onto the `paint` surfaces of the gap panels and the ring band, never the tumbling Core lattice (`cosmetic_presentation.gd:109-112` projects onto Core today) | per pilot, `<pilot>/decal` | a mask tile on one cached decal material per tile and tint. Tile size shrinks from 0.65 m (`:87`) to the plate's 0.36 m | a tile in the mask atlas; tiles 0 to 15 (today 0 to 7, `cosmetics.gd:111`) |
| `outfit` | the pilot's `Skeleton3D` under Pod > AnimatedPilot: one `BoneAttachment3D` per top-level outfit node, named for a `pilot-v1` bone such as `head` or `spine_02` (`tools/blender/PILOT-RIG.md:23-40`) | per pilot, `<pilot>/outfit`; a row must name a pilot | painted from the shared cache. An optional `AnimationPlayer` in the outfit holds clips named like the pilot's clips; `react()` plays the outfit clip with the same name (`hero_assets.gd:572-595`), so Rivet's hood snaps down on `ult_windup`, as both his hands take the copper lap bar (Q: Foundry Cutter). A node named `Replace.<name>` hides the pilot's node `<name>` while the outfit is worn (section 6) | `detail` (cap 1,500 tris, 1 draw); target 400 tris (start) |
| `shell` | HeroCore and HeroPod base, plus heft layers C2 to C5 | per pilot, `<pilot>/shell`; a row must name a pilot | the one lookup in section 6 | base under `shell` (cap 11,000 tris, 10 draws; target 6,600); each layer under `detail` (ROSTER-LOOK section 5) |
| `companion_paint` | SPIL-9's Hull and Deck enamel | shared, `spil9/companion_paint` | vertex-alpha mask on a private mesh copy (`cosmetic_presentation.gd:137-215`) | none |
| `companion_skin` | SPIL-9's skeleton: a `BoneAttachment3D` on `Hull` or `Deck` (`cosmetic_presentation.gd:173`) | shared, `spil9/companion_skin` | add-on parts painted from the cache. Riding bones instead of replacing the model keeps it working on every socket pair, since the body is one GLB per pair (`src/presentation/companion_body.gd:65-68`) | `detail`; target 600 tris (start) |
| `bay_decor` | Moss's workshop on the barge (`hero_assets.gd:1497-1515`), at a `DecorSpot` empty in `moss_workshop.glb`, else at a fixed spot (-12.6, 1.2, 1.8) (start) | shared, `bay/bay_decor`; one item at a time | one prop scene painted from the cache. Adds no light: the bay already holds two OmniLight3D nodes (`:1549-1567`) | `prop` (270 tris, 1 draw) |

**Rules every slot keeps.**

1. Looks only. No row key can carry a stat (`cosmetics.gd:99-101`).
2. No hostile hue. Every row has a `tint`, refused within 0.2 of hazard or brass (`cosmetics.gd:19-20`, `:83-88`). The tint is also the swatch colour on the page card.
3. No light node and no per-instance material on anything a slot mounts. Materials come from the shared cache, which outlives every node, so nothing a slot frees can take a material or a light with it. The wave 11 Vulkan crash was a light freed with its owner (ROSTER-LOOK section 8, `design-v3/HANDOFF.md:11`). `air_cue` builds and frees a `material_override` per ring (`hero_assets.gd:447-463`); no slot copies it.
4. A variant never moves the weapon ring, the hubs, the hub modules, sockets or kit nodes, and never enters the sight cone (ROSTER-LOOK section 3, rule 3; section 7).
5. A missing asset warns once and shows the default look (`cosmetics.gd:177-232`). A missing look never hides gameplay information; for gap panels see section 6.

## 3. Data model

### Rows (`src/core/cosmetics.gd`)

```gdscript
const SLOTS := ["paint", "trail", "decal", "companion_paint", "outfit", "shell", "companion_skin", "bay_decor"]
# Slots worn by someone other than the pilot. Every other slot is worn per pilot.
const OWNERS := {"companion_paint": "spil9", "companion_skin": "spil9", "bay_decor": "bay"}
# Slots whose rows must name a pilot: they fit one body.
const PILOT_ONLY := ["outfit", "shell"]
const MASK_TILES := 16
# Row ids whose art has not landed. The page hides them; a grant still records them.
# The art unit removes its id here, as PENDING_PILOTS works (achievements.gd:31-33).
const PENDING_ART := []
```

`ALLOWED` does not change. No new row key.

**Ids.** `<slot>_<pilot short or any>_<word>`, as today (`paint_sable_lagoon`, `cosmetics.gd:26`). A shell row's `asset` is its GLB stem and equals the row id: `shell_sable_felt` loads `world_one/shell_sable_felt.glb` and its layers `shell_sable_felt_c2.glb` to `_c5.glb`. Asset ids resolve to paths through the registry, as every delivered asset does (`cosmetics.gd:157-169`).

**Validation added to `validate` (`cosmetics.gd:92-134`).**

| Rule | Why |
| --- | --- |
| `slot` is one of the eight | today's rule with the new list (`:102-103`) |
| every non-paint row has an `asset` | today's rule already covers new slots (`:105-107`) |
| decal `mask` is 0 to `MASK_TILES - 1` | Sable's Spool needs tile 8 and Curtain Call tile 9 |
| an `OWNERS` slot names no pilot | generalises the companion rule at `:115-116` |
| a `PILOT_ONLY` slot names a real pilot | an outfit or shell fits one body |
| `starter` is true only on a paint | every other slot's default is the empty choice |
| every `PENDING_ART` id is a row and not a starter | the list cannot hide a typo |

**Ownership in one place.** `owner_for(pilot, slot)` returns `OWNERS.get(slot, pilot)`. `fits(id, owner, slot)` requires the owner `OWNERS[slot]` for those slots, and for pilot slots an owner that is not `spil9` or `bay` and a row pilot of `""` or the owner. A new static replaces the three copies listed in section 1:

```gdscript
# The id worn in a slot, or "" when nothing fitting and owned is equipped.
static func worn(profile, owner: String, slot: String) -> String
```

The page, `cosmetic_presentation.gd` and `hero_assets.gd` all call it. `paint_tint` keeps its warn-once reasons (`hero_assets.gd:335-353`) and asks `worn` for the id.

**`resolve` accepts the new slots** (`cosmetics.gd:192`): outfit, shell, companion skin and bay decoration resolve to a `PackedScene` with today's trail checks (a `Node3D` root, meshes with materials, no `CollisionObject3D`, `:193-214`), plus one new refusal: any `Light3D` node. A shell row resolves its base GLB only; layers are `hero_assets.gd`'s job.

### Grant rows (`src/core/achievements.gd`)

Three changes to the grammar, all small.

1. **`at_least`**, a new optional field: `{argument name: number}`. The fact counts only when each named argument is at or over its number. `validate` checks every key is an argument of `on` and every value a number, beside the `where` check (`achievements.gd:169-175`). `_evaluate` checks it after `where` and before the count (`progress.gd:244-251`). Rivet's and Tarn's "one set piece on six machines" need it, since `where` is exact match only (`progress.gd:245-247`).
2. **A grant on one named discovery never filters `first_time`.** `validate` refuses a row whose `where` names a `synergy_id` and also `first_time`. The codex emits `first_time: true` only on the first find ever (`src/core/codex.gd:144-157`), so such a row could never pay a player who found the trick before the row existed. Without the filter, the next run that pulls the trick pays it. The existing distinct-discovery counters keep `first_time` and name no `synergy_id` (`achievements.gd:72-73`, `:78`, `:93`), so they are untouched.
3. **A new grant names a condition, not a grind.** A row added from wave 13 on is met in one run or one moment: a discovery the kit detects, a `count` of 10 or less, or a run-summary condition. A lifetime count above 10 is refused by `validate` for new ids; the rows that predate the rule are listed by id in `GRANDFATHERED` until their cosmetics are re-granted.

A new static `for_cosmetic(id) -> String` returns the row whose reward is that cosmetic, as `for_pilot` does (`achievements.gd:120-124`). The page uses it for the locked card's words.

**Invariant, tested:** every non-starter cosmetic is the reward of exactly one achievement row. Today's table already holds it; the test keeps it true, so no item is unobtainable and none is sold.

## 4. The grant flow

```
COUNTED FACT (cross-run)                        ONE-TIME TRICK (discovery)
kit or combat emits a bus signal                kit code calls codex.mark_discovered(id)   codex.gd:143
  line_skill_fired, ultimate_landed, ...          codex emits synergy_discovered(id, ...)  codex.gd:157
            |                                                  |
            +-----------------> progress._fact  progress.gd:220 <+
                                     |
                         _evaluate  :240   where, at_least (new), sum, count
                                     |
                         _earn :290 --> profile.earn
                                     |
                         grant_once("reward:<row>:cosmetic")  :132   settle-once, then unlock_cosmetic :142
                                     |
                         profile.save  :145, :296          achievement_earned  :299
                                                                  |
                                              HUD toast queue (hud.gd:289): row name, then "New look: <item>"
                                              Camp: Customize button shows a mint dot and the count of unseen items

AT SETUP (progress.setup, progress.gd:41-69)
  backfill_rewards        :74   pays rewards of rows already earned (existing)
  backfill_discoveries    new   earns rows on synergy_discovered whose synergy_id the codex already knows (codex.known, codex.gd:85-86)
```

- **Two routes, one rule for choosing.** A count across runs is an achievement row on the fact's own signal. A one-time feat that needs the pilot, a single moment or facts from more than one event is a discovery detected in kit code, granted by a row on `synergy_discovered`. This is the route the Rivet, Kest, Tarn and Cannon sheets already chose (`pilots/rivet.md:307`, `pilots/kest.md:389`, `pilots/tarn.md:353`, `pilots/cannon.md:449`).
- **Retroactive grants.** `progress.setup` gains an optional fifth argument, the codex. `game.gd:288` passes it. `backfill_discoveries()` earns every row on `synergy_discovered` whose `where.synergy_id` the codex knows, through `_earn`, so the settle-once ledger keeps it idempotent. A player who found Parting Shot in wave 12 gets Sable's Spool decal at the next launch.
- **The toast.** `Achievements.toast_text` (`achievements.gd:114-117`) gains a second line for a cosmetic reward that is not pending art: "New look: Felt Rig". A pilot reward keeps its beat line. A pending item's toast shows the row name only, so a toast never names a look the page cannot show.
- **New marks.** An item is new when it is owned, not a starter, not pending, and not in the profile's `seen` list (section 5). The camp's Customize button shows a mint dot with the count. Mint means "ready to use" (LEGIBILITY.md:23), which an unworn item is.
- **What the sitting profile does.** `--profile=sitting` (B7) opens all six pilots. It opens no cosmetics: the sitting is the first real test of the grants.

## 5. Profile schema 4

### What changes

One field: `seen`, the cosmetic ids the player has looked at on the page. It drives the new marks and the camp count.

| Part of `profile.gd` | Today | Schema 4 |
| --- | --- | --- |
| `SCHEMA` | 3 (`:14`) | 4 |
| `MIGRATIONS` | `{0, 1, 2}` (`:17`) | adds `3: "_migrate_3"` |
| `SHAPE` | 8 keys (`:23-32`) | adds `"seen": SafeStore.STRINGS` |
| `_defaults` | `:350-364` | adds `"seen": []` |
| `merge` | unions `pilots`, `worlds`, `cosmetics`, `settled` (`:123`) | adds `seen` to that union list |
| API | none | `is_seen(id) -> bool`, `mark_seen(id) -> bool` (true the first time; memory only, `save()` writes), `seen_ids() -> Array` |
| `equipped` | flat `"<owner>/<slot>"` string map (`:28`, `:206-211`) | unchanged. `pylon_engineer/shell`, `spil9/companion_skin` and `bay/bay_decor` fit the same map |

**Why a version bump for one field.** `_read` fills missing keys from `_defaults` (`:328-330`), so a v3 file would load with `seen: []` and every item a returning player owns would glow as new. The bump lets one migration tell "a v3 file that never had `seen`" from "a v4 file with nothing seen", and it makes a wave 12 build refuse to save over a v4 file (`:318-319`, `:64-65`), as TADR-004 requires for newer formats (`adr/TADR-004-persistence.md:34`).

### The migration

```gdscript
# Schema 3 to 4 adds the seen marks. Everything a v3 profile owned counts as seen, so only
# items earned after the upgrade glow as new. A seen list already in the file (from a tool)
# is kept and unioned. Nothing is removed.
func _migrate_3(doc: Dictionary) -> Dictionary:
	var out := _defaults()
	for key in doc:
		out[key] = doc[key]
	var seen: Array = (out["seen"] as Array).duplicate() if out["seen"] is Array else []
	if out["cosmetics"] is Array:
		for id in out["cosmetics"]:
			if id is String and not seen.has(id):
				seen.append(id)
	out["seen"] = seen
	out["schema"] = 4
	return out
```

- It reads only the document's own `cosmetics` list. `profile.gd` must not load `cosmetics.gd` (`tests/profile_store_test.gd:495-507`), and it does not need to: starters never glow, by the page's rule.
- A malformed `cosmetics` value is left for `_shape_ok` to reject after migration (`profile.gd:326-327`), the same path every bad file takes today.
- Older files chain through: v0, v1 and v2 reach v3 by today's steps (`:322-325`), then `_migrate_3`.
- The original bytes are kept as `profile.json.v3` on the first save, by today's backup path (`:71-73`, `:96-102`). Unresolved equipped ids stay in the file and render as the default look; nothing is deleted (TADR-004, line 34).

### Test plan

| Test | What it proves |
| --- | --- |
| New fixture `tests/fixtures/profile_v3.json`: 3 pilots, 5 cosmetics, equipped paint, trail and `spil9/companion_paint`, 2 achievements with times, stats, settled ids, a companion, `rewards_settled`, and an unknown key `kept_from_a_tool` | the shape of a real wave 12 save |
| New `_v3_migrates_to_4` in `tests/profile_store_test.gd` | loads; every v3 field equal after load; `seen_ids()` equals the 5 cosmetics; no `.v3` before save; save writes schema 4 and generation +1; `.v3` holds the original bytes; the unknown key rides through; reload keeps all; resave makes no `.v3.1` |
| `_v3_seen_already_present` | a v3 file carrying `seen: ["x"]` ends with `x` plus the owned ids, no duplicates |
| `_seen_merge` | two writers mark different ids seen; the file holds both (the union at `:123`) |
| `_v1_migrates_to_2` re-pin | the literal 3 at `profile_store_test.gd:443` becomes `Profile.SCHEMA`; the v1 fixture's 2 cosmetics are seen. Dated header |
| `KNOWN_FIELDS` re-pin | `profile_store_test.gd:9` gains `seen`. Dated header |
| `_schema_3_never_saves` | logic unchanged (it writes `SCHEMA + 1`, `:55`); the label becomes "newer schema never saves". Dated header |
| `pilot_locks_test.gd:128` re-pin | `Profile.SCHEMA == 3` becomes 4; the v2 fixture now chains v2 to v3 to v4 and still opens Sable, Rivet, Kest and Tarn. Dated header |
| Must pass unchanged | the purity block (`profile_store_test.gd:495-507`), `profile_purity_test`, `profile_unlock_gate_test`, `profile_unlock_sequence_test` |
| Downgrade | covered by the dynamic future fixture: a file one schema ahead plays read-only and its bytes stay untouched (`profile_store_test.gd:483-492`) |

## 6. One loader path: shell, variant and heft layers (`hero_assets.gd`)

### The lookup

```gdscript
const HEFT_LAYERS := [2, 3, 4, 5]

# The one lookup: the GLB for a pilot's shell, by variant and heft class. Class 1 is the base;
# classes 2 to 5 are its detail layers, named <base>_c<N>.glb. variant "" is the pilot's
# default (SHELLS); otherwise it is a shell row's asset id, resolved through paths
# (Cosmetics.asset_paths(), or a test's own map). "" for an unknown pilot, variant or class.
static func shell_path(pilot: String, variant: String, heft_class: int, paths: Dictionary) -> String

# The five paths a fit loads, index 0 the base, after the fallback rules below.
func shell_layers(pilot: String, variant: String, paths: Dictionary) -> Array[String]

# Builds the shell under ball: HeroCore and HeroPod plus one holder per layer, painted with tints,
# layers shown up to heft_class. The game's _fit, the class card preview and the customize preview
# all call it. Returns {core, pod, layers: {2: {core, pod}, ...}, variant} or {} when even the
# default base is unavailable.
func fit_shell_into(ball: Node3D, pilot: String, variant: String, heft_class: int, tints: Dictionary) -> Dictionary

# Shows layers up to heft_class; animates the change when animate is true.
func set_heft_class(rec: Dictionary, heft_class: int, animate := true) -> void
```

`SHELLS` stays keyed by class id (`hero_assets.gd:55-62`), so tests and kit code keep their hooks (ROSTER-LOOK section 9, step 5).

### Fallback rules

| Missing | Shows | Warns |
| --- | --- | --- |
| the variant's base GLB | the default base and the default layers, all five | once per variant |
| one of the variant's layers (base loaded) | the default variant's layer for that class | once per variant and class |
| a default layer too | nothing for that class | once per pilot and class |
| the default base | today's primitive fallback (`hero_assets.gd:381-389`) | as today |

**Why the second row.** Gap panels are armour you can see (principle 19, ROSTER-LOOK sections 0.3 and 5). A cosmetic must never cost that read, so a variant missing a layer borrows the default panels rather than showing a bare lattice with every gap open at class IV. Variant layers are used only on the variant's own base, because panel shapes fit their lattice's gaps.

### Mounting

```
ball (rolling mesh)                              juice node
 '-- HeroCore  (base Core: lattice, tumbles)      '-- HeroPod  (base Pod: gimballed cockpit, upright, yaws)
      |-- Hub.00 .. Hub.31, Gap.00 .. Gap.NN           |-- WeaponRing  (level, yaws to aim)
      |-- HeftC2 .. HeftC5  (Core part)                |-- HeftC2 .. HeftC5  (Pod part)
      |                                                |-- Dome > AnimatedPilot > Skeleton3D > Outfit.<bone>
      '-- (hub and tread caps only, see below)         '-- DecalPlate
```

- A layer GLB has the same top-level `Core` and `Pod` split as the base. The loader moves each part into a holder named `HeftC<N>` under HeroCore or HeroPod at identity, as `_fit` moves the base today (`hero_assets.gd:390-404`).
- **Painted like the base.** `paint(holder, tints)` with the same `tints` (`:395-399`), so the equipped paint reaches every panel.
- **Lights stripped before the tree.** Any `Light3D` in a base, layer, outfit, skin or decoration scene is removed and freed while the scene is still outside the tree, so the renderer never pairs it, and the loader warns once. The base unit's contract test also refuses it at build time (`cage_contract_test`, ROSTER-LOOK section 9; the unit is HOBERMAN-BASE after section 0.6).
- **`Replace.<name>`.** A layer or outfit node named `Replace.CoilMast` hides the base node `CoilMast`, Sable's light coil mast on its 11 o'clock gap bracket, while it shows, with `hide_placeholder` (`:279-281`), and restores the node's saved `layers` mask when it hides. The base node stays alive, so kit code that reads `RopeExit`, `VaneL` or `ClawTip.R` keeps working. This is how class V's heavy hub modules replace the light ones (ROSTER-LOOK section 0.3, class V) and how Tarn's Steady Cap replaces his battered cap.
- **Hide, never free, during a run.** All four layers load once at fit and toggle `visible`. Only `_fit`'s swap frees them, with the pair they belong to (`:369-374`). `_fit` refits when the class, the paint tint or now the variant changes (`:367`).

### Heft class

- At fit: the run's `heft_class()` (`src/core/run_state.gd:249-265`); 1 when no run is live (camp and menus), or the preview's chosen class.
- In play: `heft_class_changed` means the class rose; `heft_class_dropped` means it fell (`src/core/game_events.gd:36-37`, `run_state.gd:277`).
- **Class up:** each new holder shows; each of its meshes slams in from 0.10 m outward over 0.18 s, ease out with a 1.2 overshoot (ROSTER-LOOK section 5). Several classes at once stagger by 0.06 s (start).
- **Class down:** each lost holder's meshes fling outward over 0.45 s (`FLING_SECONDS`, `src/build/accretion.gd:28`), then the holder hides and the meshes return to rest.
- Tweens run on the holder (`holder.create_tween()`), so a refit that frees the holder ends them. They move position and scale only. A fade would need a per-instance material, which rule 3 forbids.

### Core or Pod: where gap panels go

ROSTER-LOOK section 0.3 fills lattice gaps with panels, and section 0.1 puts the gaps on Core, which tumbles. A panel that tumbles crosses the sight cone (ROSTER-LOOK section 3, rule 3) every turn of the ball; one mesh per layer (ROSTER-LOOK section 5, "One surface per plate shell") cannot tuck panel by panel the way chunks tuck (`hero_assets.gd:642-657`). **Default for P-D:** a layer's Core part holds only thin hub and tread caps, which rule 3 allows because they are thin and moving; gap panels mount on the Pod part, below the cone. This is ROSTER-LOOK's own resolution (ROSTER-LOOK, "Conflicts resolved", last item). The loader supports either parent, so P-D can change the default without touching B5. A separable extra, if Andrew wants panels that tumble: a sight-cone cutout in a cached panel shader driven by one global uniform, with panel centres baked into UV2 by the recipe.

### Ready glow, through the same cache

SKILL-BAR asks the mecha's machinery to glow when the ultimate is ready (`design-v3/SKILL-BAR.md:225`, `:608`). On `ultimate_ready` the loader swaps every `class_accent` surface on HeroCore, HeroPod and the visible layers from the cached `class_accent` material to a second cached key, `class_accent_ready`, emission 1.6 instead of 0.5 (`hero_assets.gd:88`) (start). On the set piece's start or cancel it swaps back. Two shared materials per class colour; no per-instance material; no light.

### Outfits, skins and decorations use the same helpers

`fit_outfit(pilot_node, id)`, `fit_companion_skin(model, id)` and `fit_bay_decor(workshop, id)` each load through `_scene` (`:284-291`), strip lights, apply `Replace.`, and paint through `paint()`. One code path for "mount an add-on scene safely".

## 7. The customize page

### Layout, mouse first

```
+-------------------------------------------------------------------------------------+
| CUSTOMIZE                                                            [ Back  Esc ]  |
+------------------------------------------------+------------------------------------+
|                                                | (Sable)(Rivet)(Kest)(Tarn)(Tally)(?)|  pilot strip
|                                                +------------------------------------+
|        LIVE PREVIEW                            | BALL    Paint     Lagoon            |
|        your pilot in its mecha's cockpit,      |         Shell     Default        o  |  o = new items
|        turning slowly on Moss's bench          |         Trail     Salt Skip         |
|                                                |         Decal     None              |
|        drag to turn, wheel to zoom             | PILOT   Outfit    None           o  |
|                                                | SPIL-9  Paint     Night Slate       |
|                                                |         Skin      None              |
|   HEFT   (I) (II) (III) (IV) (V)               | (Bay row hidden while it has no item)|
|          panels show the armour you carry      +------------------------------------+
|                                                | [Default][Felt Rig][  lock  ][ ? ]  |  card grid
|                                                |                                     |
|                                                | Cable Stitch. Land 20 Cable Runs    |  hover line
|                                                | across your runs.  12 / 20          |
+------------------------------------------------+------------------------------------+
```

At 1920 by 1080 the preview takes 55% of the width and the cards are 132 px square in 4 columns; at 1280 by 720, 3 columns (start). Every row fits the viewport, as today's test checks (`tests/ui_customize_page_test.gd:113`).

- **Pilot strip.** Six round portraits in roster order. A locked pilot shows a silhouette and a lock; hover shows its unlock text (`Achievements.for_pilot`, `achievements.gd:120-124`). Click picks an unlocked pilot.
- **Slot list.** Grouped by owner: Ball (paint, shell, trail, decal), Pilot (outfit), SPIL-9 (paint, skin), Bay (decoration). Each row shows the worn item's name and a mint dot when it holds new items. A slot with no row that fits the pilot is hidden, so an empty kind never shows an empty tab.
- **Card grid.** "Default" (paint, companion paint) or "None" first, then the slot's rows for this owner. States, each with its own shape and colour:

| State | Card |
| --- | --- |
| worn | copper ring and a check mark |
| owned | plain swatch in the row's tint |
| new | a mint dot at the top right until the card has been on screen 0.6 s (start); then it joins `seen` |
| locked | swatch at 35% value with a lock; hover shows the grant's name, text and progress (`progress.count_of`, `progress.gd:89-90`) |
| hidden grant | a "?" card; hover shows "Hidden. Keep playing." and no progress (`achievements.gd:17`) |
| pending art | not shown |

- **Heft strip.** Five pips under the preview. Hover a pip to preview that class, with the real slam; click to pin it. The first time each variant is shown, the preview steps I to V once at 0.4 s per class (start), so the player sees the gap panels accrete. Any click stops it.

### Interaction and transitions

| Action | Result | Time (start) |
| --- | --- | --- |
| open from camp (button or C, `customize_page.gd:266-268`) | the page slides in from the right; camp controls fade | 0.22 s ease out; 0.15 s fade |
| hover an owned card | the preview tries it on; nothing saves | 0.12 s swap |
| mouse leaves the grid | the preview returns to what is worn | 0.12 s |
| click an owned card | equip and save (`customize_page.gd:134-144`); the part pops | 0.18 s, 1.2 overshoot |
| click a locked card | the card shakes 3 px; nothing equips | 0.15 s |
| change shell | the old panels fling out, the new lattice snaps in | 0.20 s, then 0.18 s |
| change pilot | the pilot hops out of the seat and the next hops in | 0.25 s |
| switch slot | the grid cross-fades | 0.12 s |
| close | `seen` marks save once, then the page slides out | 0.22 s |
| reduced motion (the saved setting from the polish lane) | no turntable spin, no shake, no hop; every change is a 0.08 s cross-fade; the I to V step shows the pinned class only | |

Sounds reuse what `src/presentation/audio.gd` already plays, so B5 does not touch the file B3 edits. A bespoke "fit" chime (a ratchet click, then two rising notes in the pilot's motif key, the rice-cooker end-of-cycle reference) is a separable extra for the audio lane.

Keyboard and pad keep working: up and down move between the pilot strip and the slot rows; left and right cycle the grid and equip owned items, as today (`customize_page.gd:224-254`); Enter equips; Esc goes back. `rows`, `focused_id()`, `focus()`, `press()`, `handle()`, `equip()`, `owns()`, `backfill()` and `effective()` keep their names, so `ui_customize_page_test` re-pins its layout checks, not its flows.

### The live preview

- A `SubViewportContainer` with its own world, as the class card's preview does (`src/ui/class_preview.gd:73-74` sets `own_world_3d`). Update mode "when visible", so it costs nothing while closed.
- Content: `fit_shell_into` (section 6), then `fit_pilot_into` (`hero_assets.gd:516-529`), then the outfit and the decal through the same helpers the game uses. It is the ball you will ride, built by the same code.
- The painter is a `HeroAssets` instance that never enters the tree, as `class_preview.gd:138-139` does today, so it never connects `node_added` (`hero_assets.gd:142-144`) and cannot dress a second copy of the world.
- Camera: the close camera, 3.6 m at 17 degrees down and 65 degrees lens (ROSTER-LOOK section 3); wheel zooms 3.0 to 5.0 m. Turntable at 0.2 turns a second; drag turns 0.5 degrees per pixel; the spin resumes 1.5 s after release (start).
- Light: one `DirectionalLight3D` and a `WorldEnvironment`, created once when the page attaches and never freed until quit. Nothing in the preview adds a light per item.
- Trail tab: the ball rolls in place at a simulated 6 m/s and the trail's real pooled cards spawn behind it. SPIL-9 tabs: the companion stands beside the ball. Bay tab: the item sits alone on the bench.
- The class card's preview moves to `fit_shell_into` too (`class_preview.gd:137-162`), so the card shows the equipped variant and paint, not the default shell.

## 8. Earned items, all six pilots

Twenty-one rows: three per pilot from the sheets, and three shared rows for the skill bar's framework (SKILL-BAR B5 touch points, `SKILL-BAR.md:608`). Row ids are normalised to `ach_<owner>_<word>` so one grep finds a pilot's grants. The sheets' own ids are listed where they differ. Every row that needs art enters `PENDING_ART` until its art lands; a paint row, such as Rigger Blue, needs none and never does.

**Route** says how the grant fires: **count** is an achievement row on the fact's own signal; **discovery** is kit code calling `codex.mark_discovered`, granted by a row on `synergy_discovered` with `where: {"synergy_id": <id>}` and no `first_time`.

### Sable (`pylon_engineer`)

| Item id | Name | Slot | Grant row | Route and condition | Art from |
| --- | --- | --- | --- | --- | --- |
| `trail_sable_cable` | Cable Stitch | trail | `ach_sable_cable_runs` "Cable Runner": "Land three Cable Runs in one run." (sheet: `sable_cable_runs`) | discovery `sable_cable_runs` (PC-SABLE detects it) | trail art unit |
| `decal_sable_spool` | Spool and Wrench | decal, tile 8 | `ach_sable_parting_shot` "Parting Shot": "Kill a machine within a second of a pylon slingshot." | discovery `parting_shot`, which exists (`src/combat/codex_entries.gd:37-42`, detected at `src/combat/combat.gd:2551-2552`). The sheet's `first_time: true` is dropped; backfill pays players who already found it | decal tile unit |
| `shell_sable_felt` | Felt Rig | shell | `ach_sable_switchback` "Switchback", hidden: "Bank Shot off a stake your Cable Run left." | discovery `switchback` (PC-SABLE detects it, `pilots/sable.md:334`); `first_time` dropped | P-D Sable |

### Rivet (`runner_gunner`)

| Item id | Name | Slot | Grant row | Route and condition | Art from |
| --- | --- | --- | --- | --- | --- |
| `trail_rivet_swarf` | Swarf Curl | trail | `ach_rivet_line_true` "Line True": "Land ten Line Drive punches in one stage." | discovery `rivet_line_true` (PC-RIVET detects it) | trail art unit |
| `outfit_rivet_hood` | Welding Hood | outfit | `ach_rivet_shrugged` "Shrugged Off": "Shrug off 30 holds and knocks in one run." | discovery `rivet_shrugged`, detected in Rivet's code on the 30th ignored hit of a run (`pilots/rivet.md:307`). The hood carries a clip named `ult_windup`, so it snaps down with the pilot's wind-up | outfit art unit |
| `shell_rivet_calibrated` | Calibrated | shell | `ach_rivet_full_breach` "Full Breach": "Land one Foundry Cutter on six machines." | count: `on: ultimate_landed`, `where: {ultimate_id: foundry_cutter}`, `at_least: {hits: 6}`, `count: 1` | P-D Rivet |

### Kest (`demolitions_caster`)

| Item id | Name | Slot | Grant row | Route and condition | Art from |
| --- | --- | --- | --- | --- | --- |
| `trail_kest_fuse_smoke` | Fuse Smoke | trail, tint `8c8577` | `ach_kest_blast_vault` "Blast Vault", hidden: "Let your own Cable Charge throw you clear." | discovery `kest_blast_vault` (`pilots/kest.md:402`) | trail art unit |
| ~~`outfit_kest_rigger`~~ | ~~Rigger Harness~~ | outfit | `ach_kest_homecoming` "Homecoming": "Fly Kest into the Highdraft." | discovery `kest_homecoming`, detected in `kest_kit.gd` on entering world 3 (`pilots/kest.md:389`) | **Cut for alpha** (Andrew, 2026-10-16; [COSMETICS-ART-BRIEFS.md](COSMETICS-ART-BRIEFS.md)). Homecoming pays a new Kest paint, `paint_kest_rigger` "Rigger Blue" `4f6f9a`, instead: every achievement must carry a reward (`achievement_fill_test` F1; the six wave 20 record-only rows in `achievements.gd` `RECORD_ONLY` are the named exception), and a paint needs no art |
| `shell_kest_roost` | Roost Frame | shell | `ach_kest_tick_tick_boom` "Tick, Tick, Boom": "Strike eight machines with one Windhover." | discovery `kest_tick_tick_boom`. **Changed from the sheet's achievement** (`pilots/kest.md:390`): eight different enemies across the volleys and the landing span several events, which a row cannot see; Kest's code counts distinct targets for the set piece and fires the discovery | P-D Kest |

Kest's amber cannot be a tint: it sits 0.09 from brass, inside the 0.2 refusal (`pilots/kest.md:384`). Her items use smoke grey and bone. Every new tint in this section sits 0.39 or more from brass and 0.53 or more from hazard in RGB (`src/core/palette.gd:19`, `:21`), clear of the refusal.

### Tarn (`tarn`)

| Item id | Name | Slot | Grant row | Route and condition | Art from |
| --- | --- | --- | --- | --- | --- |
| `trail_tarn_claw_marks` | Claw Marks | trail | `ach_tarn_dragged` "Ten in the Claws" (was "Fifty Dragged"): "Drag ten machines into your claws in one stage." (sheet: `tarn_dragged_50`) | discovery `tarn_dragged` (PC-TARN detects it) | trail art unit |
| `shell_tarn_redjaw_teeth` | Redjaw Teeth | shell | `ach_tarn_six_at_once` "Six at Once": "Land Redjaw Rend on six machines at once." | count: `on: ultimate_landed`, `where: {ultimate_id: redjaw_rend}`, `at_least: {hits: 6}`, `count: 1` | P-D Tarn |
| `outfit_tarn_steady_cap` | Steady Cap | outfit | `ach_tarn_hold_still` "Hold Still", hidden: "Break a hold with Redjaw Rend three times." | discovery `tarn_hold_still`, counted in Tarn's code from `hold_broken` with method `ultimate` (`pilots/tarn.md:353`). The outfit's `Replace.Cap` node hides the battered cap, which the P-D or P-E pilot rebuild must split into its own `Cap` node | outfit art unit |

### Tally (`tally`)

| Item id | Name | Slot | Grant row | Route and condition | Art from |
| --- | --- | --- | --- | --- | --- |
| `trail_tally_punch_tape` | Punch Tape | trail, tint `f7f1e3` | `ach_tally_punch_tape` "Punch Tape": "Fire the ledger clip ten times in one stage." | discovery `tally_punch_tape` (PC-TALLY detects it) | trail art unit |
| `outfit_tally_eyeshade` | Eyeshade | outfit | `ach_tally_eyeshade` "Eyeshade": "Settle twenty clips with Plate Return in one run." | discovery `tally_eyeshade` (PC-TALLY detects it). Needs B3 to count each settled clip in Plate Return's `hits` | outfit art unit |
| `shell_tally_abacus` | Abacus Lattice (working name) | shell | `ach_tally_books_balanced` "Books Balanced", hidden: "Settle six clips with one landing." | discovery `tally_books_balanced` (`pilots/tally.md:308`) | P-D Tally |

### The Cannon (`remembered_cannon`)

| Item id | Name | Slot | Grant row | Route and condition | Art from |
| --- | --- | --- | --- | --- | --- |
| `trail_cannon_recital` | Recital | trail, tint `6fb3a6` | `ach_cannon_recital` "Recital", hidden: "Land the four families in the order the gun hums." | discovery `cannon_recital` (`pilots/cannon.md:487`); the sheet's `first_time: true` is dropped | trail art unit |
| `paint_cannon_lens` | Lens Glass | paint, tint `d4f2b0` | `ach_cannon_time_on_target` "Time on Target": "Land a Fire Mission on eight enemies at once." | discovery `cannon_time_on_target` (`pilots/cannon.md:488`); `first_time` dropped | none: a paint is a tint |
| `shell_cannon_choir` | Choir Barrel | shell | `ach_cannon_old_tune` "Old Tune", hidden: "Quiet the Mind with its own gun." | discovery `cannon_old_tune` (`pilots/cannon.md:489`); `first_time` dropped | P-D Cannon |

### Shared: the skill bar's three (B5 ships these rows)

| Item id | Name | Slot | Grant row | Route and condition | Art from |
| --- | --- | --- | --- | --- | --- |
| `trail_any_downbeat` | Downbeat | trail | `ach_any_set_piece` "Set Piece": "Land your first ultimate." | discovery `set_piece` (B6, `SKILL-BAR.md:461`) | trail art unit. Copper ticks spaced one beat apart along the path, so the trail shows the set piece lands on the music |
| `decal_curtain_call` | Curtain Call | decal, tile 9 | `ach_any_curtain_call` "Curtain Call": "Shatter an open Warden core with an ultimate landing." | discovery `set_piece_core` (B6, `SKILL-BAR.md:462`) | decal tile unit |
| `companion_skin_till_bell` | Till Bell | companion skin | `ach_any_cash_in` "Cash In": "Pay a chain of three with an ultimate landing." | discovery `set_piece_cash_in` (B6, `SKILL-BAR.md:463`). **Changed:** SKILL-BAR's B5 note says "Cash In 6"; the discovery's threshold is a chain of 3, and a separate 6 would need a chain argument no signal carries | skin art unit. A small copper till bell on SPIL-9's deck; the first companion skin, so that slot is proven end to end |

### Totals and what is not shipped

| Slot | Items | Pilots |
| --- | --- | --- |
| trail | 7 | all six, plus Downbeat |
| shell | 6 | all six |
| outfit | 4 | Rivet, Kest, Tarn, Tally |
| decal | 2 | Sable, plus Curtain Call |
| paint | 1 | the Cannon |
| companion skin | 1 | shared |
| bay decoration | 0 | room only |

**Set-piece grants count the base ultimate only.** Rivet's, Tarn's, Sable's and Tally's rows name the base id. A depth-3 variant has its own id (`SKILL-BAR.md:439`, `variant_of`), and every run starts on the base, so each grant stays reachable in world 1 of any run.

**Discoveries the P-C units must declare**, because their sheets' section 8 tables lack a codex row: `rivet_shrugged`, `kest_homecoming`, `kest_tick_tick_boom`, `tarn_hold_still`. A discovery that is detected but never declared still emits, with a warning (`codex.gd:149`), so a missing row is a defect, not a crash.

## 9. Unit B5: implementation map

Fable review: this unit changes the save schema, the merge rule and the migration chain, which is the data-loss class.

**Order.** B5 builds beside B1 and merges after it. Two changes make that safe:

1. B1 hands its pre-seeded per-pilot blocks in `cosmetics.gd` and `achievements.gd` (`SKILL-BAR.md:685`) to B5. B5 owns both files, seeds the six empty marked blocks, and the two units stay on disjoint files.
2. B5's rows name only `synergy_discovered` (declared today, `game_events.gd:42`) and its listeners on `ultimate_started` and `ultimate_ready` connect behind `has_signal`, so nothing breaks before B1's signals land. The scripted set-piece acceptance runs after B1 and B3 merge.

The six P-C units then add their three rows each inside their own block, their discovery detection and codex rows, and their `PENDING_ART` entries. P-D removes a shell id from `PENDING_ART` when its variant GLB and four layers land; the art units do the same for theirs.

### SCOPE

All under `sketches/core-loop/`.

- `src/core/cosmetics.gd`: `SLOTS`, `OWNERS`, `PILOT_ONLY`, `MASK_TILES`, `PENDING_ART`, the `validate` rules (section 3), `owner_for`, `fits`, `worn`, `resolve` types and the light refusal, six empty per-pilot blocks and three shared rows.
- `src/core/achievements.gd`: the `at_least` field and its validation, the `first_time` rule, `for_cosmetic`, the toast's item line, six empty per-pilot blocks and the three shared grant rows.
- `src/core/progress.gd`: `at_least` in `_evaluate`, the optional `codex` argument to `setup`, `backfill_discoveries`.
- `src/game.gd`: one line at `:288`, passing the codex.
- `src/core/profile.gd`: schema 4 as section 5 lists.
- `src/presentation/hero_assets.gd`: `HEFT_LAYERS`, `shell_path`, `shell_layers`, `fit_shell_into`, `set_heft_class`, the heft signal listeners, `Replace.`, light stripping, `fit_outfit`, `fit_bay_decor`, the ready glow; `_fit` reads `worn` for paint and shell.
- `src/presentation/cosmetic_presentation.gd`: decal to `DecalPlate` with a cached material and the gap-panel and ring-band fallback; `fit_companion_skin`; the set-piece trail (cards keep spawning between `ultimate_started` and its landing or cancel, at the ball's height instead of the ground's, `:245`, `:275`); `effective` reads `worn`.
- `src/ui/customize_page.gd`: section 7.
- `src/ui/class_preview.gd`: `_build_shell` through `fit_shell_into` (`:137-162`).
- `src/core/content_registry.gd`: re-pin the `achievements.ROWS` and `cosmetics.ROWS` hashes (`:73-75`) with dated comments.
- Tests and fixtures listed below. Nothing else.

### ACCEPTANCE

- `Cosmetics.validate(Cosmetics.ROWS, pilots)` is empty, and each new rule rejects its bad row: an unknown slot, a shell with no pilot, an outfit with a pilot that does not exist, a companion skin naming a pilot, a decal mask of 16, a starter trail, a `PENDING_ART` id that is not a row.
- Every non-starter cosmetic is the reward of exactly one achievement row.
- Every row not in `PENDING_ART` resolves to delivered art; every `PENDING_ART` id is hidden on the page.
- `at_least`: a fact under the number neither counts nor earns; a fact at the number earns once. `validate` refuses an `at_least` key that is not an argument of `on`.
- A grant row naming one `synergy_id` with `first_time` fails validation.
- With the codex already knowing `parting_shot`, `progress.setup` grants `decal_sable_spool` once and saves; a second setup grants nothing.
- Schema 4 as section 5's test plan; `merge` unions `seen`.
- `shell_path` returns the expected path for all six pilots, the default and one fixture variant, and classes 1 to 5; "" for class 0, class 6, an unknown pilot and an unknown variant.
- `fit_shell_into` with a fixture variant missing its C4 layer shows the default C4 at class IV and warns once over 100 refits.
- Across five class changes up and down in a headless run, each layer holder keeps its instance id (hidden, never freed), and only a pilot or variant swap frees them.
- After any fit, no `Light3D` and no `material_override` exists under HeroCore, HeroPod, an outfit, a companion skin or a bay decoration, including a fixture layer that ships an `OmniLight3D`.
- An equipped paint tint reaches every `paint` surface on every visible layer.
- `Replace.Cap` hides the pilot's `Cap` node while the outfit is worn and restores its `layers` when it is removed.
- The decal lands on `DecalPlate` when it exists and on the gap panels and ring band otherwise; two refits reuse one material instance.
- The ready glow swaps between exactly two cached material instances per class colour.
- With B1 and B3 merged: a scripted run that lands a set piece earns `ach_any_set_piece` once and saves it, and the equipped trail draws cards along the flight (`SKILL-BAR.md:609`).
- The page: hover tries on without saving; click equips and saves; a locked card shows its grant and progress; a hidden grant shows "?"; new marks clear and `seen` saves once on close; slots with no fitting row are hidden; every control fits at 1280 by 720 and 1920 by 1080; reduced motion drops the spin, shake and hop; keyboard and pad flows still work.
- The class card preview shows the equipped variant and paint.

### TESTS

- New `tests/customize_slots_test.gd`: `owner_for`, `fits` and `worn` for all eight slots and three owner kinds; the equip refusals (`customize_page.gd:134-144`).
- New `tests/shell_layers_test.gd`: the lookup, the fallback table, mounting, visibility by class, instance-id stability, light stripping, paint on panels, `Replace.`. Fixtures are scenes the test packs and saves under `user://`, fed to `shell_path` through its `paths` map.
- New `tests/grant_grammar_test.gd`: `at_least`, the `first_time` rule, `backfill_discoveries`, the toast's item line, the one-grant-per-item invariant.
- New fixture `tests/fixtures/profile_v3.json` and the schema 4 cases in `tests/profile_store_test.gd` (section 5).
- Re-pins with dated headers: `profile_store_test.gd:9`, `:443`, the `:483` label; `pilot_locks_test.gd:128`; `customization_system_test.gd:198` (mask 8 becomes valid, 16 invalid) and `:181-183` (exempt `PENDING_ART`); `ui_customize_page_test.gd` layout checks; `customization_presentation_test.gd` decal placement.
- Must pass unchanged: `cosmetic_apply_test`, `cosmetic_trail_allocation_test`, `hero_assets_test`, `hero_assets_missing_glb_test`, `profile_purity_test`, `profile_unlock_gate_test`, `profile_unlock_sequence_test`, `progress_bus_test`, `ledger_leaf_test`, `achievement_fill_test`, `roster_test`.

### VERIFY

- `tools/coordinator/compile_check.sh` and `node scripts/sketch-lint.mjs --sketch core-loop`.
- The new and re-pinned tests, red then green, each reporting a nonzero check count.
- `npm run sketch:smoke -- --sketch core-loop`.
- A fence check: `git diff --name-status` against SCOPE.
- The `uat` runner on the export's camp with a scenario: open Customize with the mouse, hover a locked card and read its grant, hover an owned card and see the preview change, click to equip, change the heft pip, close and reopen to confirm the item stayed equipped and its new mark stayed cleared. Expected PASS; open `actions.jsonl` and the shot at the equip step before counting it as level 5.
- Perf: class V with a variant and an outfit against the pre-wave base on card 1, under the 1.3x rule (ROSTER-LOOK section 8).

### Measures, so each part shows it works

| Part | Measure |
| --- | --- |
| Grants | every P-C unit's scripted test earns its three rows once and saves; the sitting's run log shows which grants fired |
| New marks | the profile's `seen` list after the sitting; an item earned and never seen means the camp dot did not land |
| Page | in the sitting, Andrew finds and equips one earned item within 30 s of opening the page, unaided (checklist item) |
| Equip use | `add_stat("cos.equip.<slot>")` on each equip (no schema change; `profile.gd:218-219`) |
| Variants | the greyscale identity test (ROSTER-LOOK section 3, rule 10) still names all six pilots with every variant equipped; class I against class V stays 3 of 3 per variant |
| Loader | zero lights after fit; holder instance ids stable; perf ratio under 1.3x |

### Not owned by any unit yet

Update 2026-10-16: the five built shell variants are live, and the Rigger Harness is cut for alpha, so 13 items wait in `PENDING_ART`: seven trails, two decal tiles, three outfits and one companion skin ([COSMETICS-ART-BRIEFS.md](COSMETICS-ART-BRIEFS.md)). The original note follows.

Seven trails, two decal tiles, four outfits and one companion skin need art. P-D builds the six shell variants and their layers. Nothing in the plan builds the other fourteen. One art unit (or a Codex visual-track wave once Codex reopens on 2026-10-11) should own them. Until then those rows sit in `PENDING_ART`, the grants still record, and nothing breaks.

## 10. Separable extras (not in B5)

- **Warden trophies for the bay.** Breaking each Warden kind for the first time hangs its trophy in Moss's workshop: a reactor relic's valve wheel, a swarm remnant's queen hatch, a hand's finger joint. It gives `bay_decor` its first items and turns the bay into a record of the run's high points.
- **A fit chime per pilot**, in the motif key (section 7).
- **Felt Rig's muffled roll.** Sable's sheet wants the felt shell to turn the roll's rattle into a thump (`pilots/sable.md:322`). That needs an audio hook per variant; rows stay looks only.
- **Tumbling panels** with a sight-cone cutout shader (section 6).
- **A per-pilot "wardrobe" photo** on the class card: the preview's frame saved as the card portrait.

## 11. Veto list

Calls made under the creative charge. Say "veto" on a line and it changes.

1. Schema 4 adds one field, `seen`, for new-item marks; a returning profile's owned items count as already seen.
2. A shell variant missing a heft layer borrows the default panels for that class, so the armour read never vanishes for a cosmetic.
3. Gap panels mount on the upright Pod and the tumbling Core takes only thin hub caps, which keeps the pilot visible (default for P-D; the loader supports either).
4. One new grant field, `at_least`, used by Rivet's and Tarn's six-machine shells.
5. Kest's eight-enemy shell grant becomes a discovery her code fires, because it spans several events.
6. Grants on one named discovery never require a first-ever find, and discoveries already found pay out at the next launch.
7. SKILL-BAR's "Cash In 6" becomes the Cash In discovery at a chain of 3.
8. The three framework items are the Downbeat trail, the Curtain Call decal and the Till Bell, SPIL-9's first skin.
9. Bay decoration ships with no items; its row stays hidden until one exists.
10. Only a paint can be a starter; every other slot starts on its empty choice.
11. Hover tries an item on without saving; click equips and saves.
12. The sitting profile opens pilots only; cosmetics stay earned.
13. B1 hands its `cosmetics.gd` and `achievements.gd` pre-seed blocks to B5, so the two units never share a file.
14. Outfits use the `detail` class at a 400-tri target; the ball at class V with an outfit is 16,400 tris and 20 draws.
15. Set-piece grants count the base ultimate only, never a depth-3 variant.
16. The decal atlas grows to 16 tiles.
17. The ready glow swaps between two cached materials; no light.
18. Grant rows are renamed `ach_<owner>_<word>`.
