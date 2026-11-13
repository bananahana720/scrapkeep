extends RefCounted

# T5: content is data. Validation never edits a source table or instantiates a scene.
# Reachability means selectable by the data API, not an emitter or a playable encounter.
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Events := preload("res://src/core/event_kinds.gd")
const Objectives := preload("res://src/core/objectives.gd")
const Lore := preload("res://src/core/lore_rows.gd")
const Music := preload("res://src/presentation/music_rows.gd")
const Windup := preload("res://src/presentation/windup_rows.gd")
const PhaseMusic := preload("res://src/presentation/phase_music.gd")
const TuneMoments := preload("res://src/presentation/tune_moments.gd")
const Trees := preload("res://src/core/upgrade_tree.gd")
const CombatCodex := preload("res://src/combat/codex_entries.gd")
const BossCodex := preload("res://src/boss/codex_entries.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Roster := preload("res://src/combat/roster.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Icons := preload("res://src/ui/icons.gd")
const Worlds := preload("res://src/core/worlds.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const PartDef := preload("res://src/build/part_def.gd")

const RULES := ["well_formed", "references", "reachable", "minimum_rows", "golden_hash"]
# A number accepts int or float, but always has to be finite.
const NUMBER := -1
const EVENT_SCHEMA := {"group": TYPE_STRING, "color": TYPE_COLOR, "shape": TYPE_STRING,
	"sound": TYPE_STRING, "hud": TYPE_STRING, "objective": TYPE_STRING, "priority": TYPE_INT}
const STATE_SCHEMA := {"color": TYPE_STRING, "motion": TYPE_STRING, "shape": TYPE_STRING,
	"sound": TYPE_STRING, "verb": TYPE_STRING, "word": TYPE_STRING}
const ACTIVITY_SCHEMA := {"color": TYPE_STRING, "motion": TYPE_STRING, "shape": TYPE_STRING,
	"sound": TYPE_STRING, "word": TYPE_STRING}
const TREE_SCHEMA := {"id": TYPE_STRING, "name": TYPE_STRING, "effect": TYPE_STRING,
	"key": TYPE_STRING, "icon": TYPE_STRING, "tags": TYPE_ARRAY}

# Each minimum is an admission floor, separate from the exact golden content pin.
const TABLES := {
	"achievements.ROWS": {"kind": "achievements", "minimum": 8, "schema": {"name": TYPE_STRING, "text": TYPE_STRING, "on": TYPE_STRING, "count": TYPE_INT, "reward": TYPE_DICTIONARY}},
	"cosmetics.ROWS": {"kind": "cosmetics", "minimum": 6, "schema": {"slot": TYPE_STRING, "pilot": TYPE_STRING, "name": TYPE_STRING, "starter": TYPE_BOOL}},
	"event_kinds.ROWS": {"kind": "signals", "minimum": 1, "schema": EVENT_SCHEMA},
	"event_kinds.LINE_ROWS": {"kind": "states", "minimum": 1, "schema": STATE_SCHEMA},
	"event_kinds.STATE_ROWS": {"kind": "states", "minimum": 1, "schema": STATE_SCHEMA},
	"event_kinds.CAUSE_ROWS": {"kind": "causes", "minimum": 1, "schema": {"color": TYPE_STRING, "shape": TYPE_STRING, "motif": TYPE_ARRAY}},
	"event_kinds.ACTIVITY_ROWS": {"kind": "activities", "minimum": 1, "schema": ACTIVITY_SCHEMA},
	"event_kinds.LOOT_ROWS": {"kind": "events", "minimum": 1, "schema": EVENT_SCHEMA},
	"event_kinds.UI_ROWS": {"kind": "events", "minimum": 1, "schema": EVENT_SCHEMA},
	"event_kinds.WORLD_ROWS": {"kind": "events", "minimum": 1, "schema": EVENT_SCHEMA},
	"event_kinds.THREAT_ROWS": {"kind": "events", "minimum": 4, "schema": EVENT_SCHEMA},
	"event_kinds.ATTACK_ROWS": {"kind": "attacks", "minimum": 1, "schema": {"label": TYPE_STRING, "group": TYPE_STRING, "owner_kind": TYPE_STRING, "owner": TYPE_STRING, "allegiance": TYPE_STRING, "threat": TYPE_STRING, "glyph": TYPE_STRING, "color": TYPE_COLOR, "pose": TYPE_STRING, "warn": TYPE_STRING, "release": TYPE_STRING, "floor": TYPE_STRING, "open": TYPE_ARRAY}},
	"event_kinds.IMPACT": {"kind": "impact", "minimum": 1, "schema": {"knock": NUMBER, "lift": NUMBER, "stop": TYPE_STRING, "shake": NUMBER, "react": TYPE_STRING}},
	"event_kinds.REACTIONS": {"kind": "reactions", "minimum": 3, "schema": {"angle": NUMBER, "rise": NUMBER, "hold": NUMBER, "recover": NUMBER, "overshoot": NUMBER, "tumble": NUMBER, "limit": NUMBER}},
	"event_kinds.CODEX_CATEGORIES": {"kind": "categories", "minimum": 1, "schema": {"label": TYPE_STRING, "color": TYPE_COLOR, "shape": TYPE_STRING, "reserved": TYPE_BOOL}},
	"objectives.ROWS": {"kind": "objectives", "minimum": 1, "schema": {"glyph": TYPE_STRING, "words": TYPE_STRING}},
	"lore_rows.ROWS": {"kind": "lore", "minimum": 1, "schema": {"id": TYPE_STRING, "kind": TYPE_STRING, "zone": TYPE_STRING, "text": TYPE_STRING}},
	"music_rows.ROWS": {"kind": "music", "minimum": 1, "schema": {"synth_theme": TYPE_INT, "ace_manifest": TYPE_STRING}},
	"windup_rows.ROWS": {"kind": "windup", "minimum": 1, "schema": {"color_role": TYPE_STRING, "shape": TYPE_STRING, "sound": TYPE_STRING, "attacks": TYPE_DICTIONARY}},
	"upgrade_tree.TREES": {"kind": "trees", "minimum": 4, "schema": TREE_SCHEMA},
	"upgrade_tree.WORLD_ONE_NODES": {"kind": "world_one_trees", "minimum": 4, "schema": TREE_SCHEMA},
	"combat.codex_entries.ENTRIES": {"kind": "codex", "minimum": 1, "schema": {"id": TYPE_STRING, "name": TYPE_STRING, "hint": TYPE_STRING, "clue": TYPE_STRING, "text": TYPE_STRING}},
	"boss.codex_entries.ENTRIES": {"kind": "codex", "minimum": 4, "schema": {"id": TYPE_STRING, "name": TYPE_STRING, "hint": TYPE_STRING, "clue": TYPE_STRING, "text": TYPE_STRING}},
	"boss.codex_entries.WAKING": {"kind": "codex", "minimum": 4, "schema": {"id": TYPE_STRING, "name": TYPE_STRING, "hint": TYPE_STRING, "clue": TYPE_STRING, "text": TYPE_STRING}},
	"boss.codex_entries.MIND": {"kind": "codex", "minimum": 4, "schema": {"id": TYPE_STRING, "name": TYPE_STRING, "hint": TYPE_STRING, "clue": TYPE_STRING, "text": TYPE_STRING}},
	"parts.rows": {"kind": "parts", "minimum": 1, "schema": {"name": TYPE_STRING, "text": TYPE_STRING, "verb": TYPE_STRING, "rarity": TYPE_STRING, "tier": TYPE_INT, "family": TYPE_STRING, "tags": TYPE_ARRAY}},
	"item_gen.RARITY": {"kind": "rarity", "minimum": 4, "schema": {"color": TYPE_COLOR, "weight": NUMBER, "stamp": TYPE_STRING, "rung": TYPE_INT, "tier": TYPE_INT, "affix": NUMBER}},
}

# 2026-10-04, T5, base b927aec. Sorted dictionary keys; array order and Variant types count.
# 2026-10-04, alpha wave 8 roster-world-rows: event_kinds.ATTACK_ROWS and windup_rows.ROWS re-pinned for the reserved E19-E24 rows.
# 2026-10-11, sg5-burden-sweep: parts.rows adds the capped Load Dividend payout.
const GOLDEN_HASHES := {
	"achievements.ROWS": "2fe66bab0c3ad97443d08468976d42efe9a837880a997861530bee798893485e",  # 2026-11-12 (feature-fit.md row 30): the eleven record-only rows each pay a tint-only paint; was 406f4a5d. 2026-11-11 (systems audit pass D, row 31): the four ach_meta_* grants pay paint_any_shift, _mortar, _cache and _spark instead of head starts no screen shows; was d594e8df. 2026-11-11 w36 unslop-codex (ruling cx): First Ultimate and Strike are named without the old Set Piece and the exclamation, two lines say machines and hooking; words only, no id, count, reward or number moved; was bc7a4784, 2026-10-24 merge of #406 (six brindle_mark_* rows) onto the Spillway roster rows; was 3601cc6b (roster) and f60d7f24 (#406). 2026-10-23 w19 Spillway roster: five record-only rows (mat slip, flap ride, hook out, soaked, boom strike); was 0330f5ea, 2026-10-22 w19 earned save: clean_win reads save_used (text and need only); was 79601502, 2026-10-19 w20 ACHIEVEMENTS-REFRESH: six reward-free content-family rows (RECORD_ONLY); was 2955fb5f, 2026-10-17 stage/alpha-w16 combined re-pin (crown pass, first-win secrets, maker sets); was 149d3873, 2026-10-16 pilot paint (Andrew cut the Rigger Harness): Homecoming pays paint_kest_rigger; was 56113e7f, 2026-10-12 PC-RIVET merge (Rivet's kit rows); was a29cefb2, 2026-10-12, PC-TALLY merge 80634ba: Tally's achievements, cosmetics, tree, world-one cards and codex rows; event_kinds.WORLD_ROWS moved at the KE1 merge 61eaef0 (12 event kinds added), re-pinned here; was 570a2db4, 2026-10-12 W13 coordinator: Tarn's Hold Still grant drops its story beat (beats are pilot-unlock rows only; the quip stays in its codex hint); was 965c2d1a, 2026-10-12 W13 coordinator: PC-SABLE round 7 (0ad68fa) merged onto Kest and the Cannon; was a75de886, 2026-10-12 W13 coordinator: PC-KEST round 4 (ef725b8) merged onto the Cannon kit; was 78c3807d, 2026-10-12 PC-CANNON merge (5e18183): Cannon kit rows; was d584902d, 2026-10-11 (w13 PC-TARN round 3): Tarn's kit, tree depths, codex, starter cosmetics and grant rows; was 9f88aba2, 2026-10-11 (w13 SG12 sg12-meta-options): four ach_meta_* grant rows paying {"option": <node>}; was 028b78af, 2026-10-10 (w13 B5, CUSTOMIZE.md section 8): the skill bar's three shared grant rows on named discoveries; was d50e7ffc, 2026-10-08 (wave 10 ST5): one story beat per pilot unlock
	"cosmetics.ROWS": "2230dc95ee1c1fc6033e8ff830be418a43a7618288b62bbafddc9ad2d7769359",  # 2026-11-12 (feature-fit.md row 30): eleven tint-only any-pilot paints for the record-only achievements; was 3e4a7049. 2026-11-11 (systems audit pass D, row 31): four tint-only any-pilot paints for the ach_meta_* grants; was f56ad3fa. 2026-10-17 stage/alpha-w16 combined re-pin (crown pass, first-win secrets, maker sets); was b55fa30d, 2026-10-16 pilot paint (Andrew cut the Rigger Harness): outfit_kest_rigger out, paint_kest_rigger "Rigger Blue" in; was 710377a7, 2026-10-12 PC-RIVET merge (Rivet's kit rows); was 7af1d998, 2026-10-12, PC-TALLY merge 80634ba: Tally's achievements, cosmetics, tree, world-one cards and codex rows; event_kinds.WORLD_ROWS moved at the KE1 merge 61eaef0 (12 event kinds added), re-pinned here; was 2e0409f8, 2026-10-12 W13 coordinator: PC-SABLE round 7 (0ad68fa) merged onto Kest and the Cannon; was f3f9a84a, 2026-10-12 W13 coordinator: PC-KEST round 4 (ef725b8) merged onto the Cannon kit; was 0f1a4488, 2026-10-12 PC-CANNON merge (5e18183): Cannon kit rows; was 1148576f, 2026-10-11 (w13 PC-TARN round 3): Tarn's kit, tree depths, codex, starter cosmetics and grant rows; was 26e34e89, 2026-10-10 (w13 B5, CUSTOMIZE.md section 8): Downbeat trail, Curtain Call decal tile 9, Till Bell companion skin, all pending art; was c0f10ab8, P-R7: delivered decal mask ids, trails and SPIL-9 paints
	"event_kinds.ROWS": "e03f849f11e5fbaaf3d8f8fa569149bf011bd22dff0cd0c1d8030f0716c7699a",  # 2026-11-13 (collisions): the bumped and enemy_walled rows hearing land_thud; existing rows unchanged; was 2df85e5a. 2026-11-11 (systems audit pass C): the carved row hearing carve_release; existing rows unchanged; was fd8fea65. 2026-11-10 (wave 36 unslop-hudwords, ruling cx): hud wording only: core_gained reads "Gates may offer rares" (hud.gd CORE_WORDS says the rest by cores held), synergy_discovered "Synergy {name}", launched shows no hud word (card-owned, never drawn); was b0851920. 2026-11-10 (wave 36 unslop-moments, ruling cx): hud wording only: three toast rows blanked (beacon_unsealed, reward_offered, boss_defeated), core_gained reads "Gates offer better parts"; was eadb20af. 2026-11-09 (call-ins): the quiet trade_taken row; existing rows unchanged; was c75f8505. 2026-10-24 (intro cards clear before a fight): the silent warden_sighted row; existing rows unchanged; was aa56a519. 2026-10-24 merge of #391 (boss phases: attack_cued, fight_phase_changed) onto IL-01 grey panels; was bf16cf5f (panels) and 4846dd75 (#391). 2026-10-23 IL-01 grey panels: the panel_gained row (sound panel_ratchet); was b73430a9. 2026-10-19 w20 ACHIEVEMENTS-REFRESH: five quiet achievement-fact rows; was b503b02c. 2026-10-18 enemy_ringed_out row (Highdraft ring-outs, sound_next ring_out_fall) on stage/alpha-w17; was 28cc0b87. 2026-10-17 stage/alpha-w16 combined re-pin (active_heat row for the Cutting Torch's heat tick); was 4ad8bbdd, 2026-10-17 stage/alpha-w16 combined re-pin (actives' active_fired row); was 469030a8, 2026-10-12 (w13 WEIGHT-1 c4e428c): authored core_slam on slammed, ultimate_land on ultimate_landed, vault and harpoon cue rows, re-pinned by the coordinator at merge; was c374e259, 2026-10-11 (w13 skill-bar step 1, 7b7e2aa): ultimate_* rows, re-pinned by the coordinator at the systems wave A merge; was 1326ff10, 2026-10-09 (wave 12 VX-SURF 5a9e1ef): ANCIENT moved from 3d8bff to 9dff3c (Andrew's pick), which changes the colour value only; restoring the old colour restores the old hash; was 3e903494, 2026-10-08 (wave 10 MOT1): drop_landed, missed_drop, evolution_fired rows; was 2026-10-05 (wave 11 gate 2): world_entered row hears stinger_world and reads "World {world}"
	"event_kinds.LINE_ROWS": "f4a74391a5a9053d404b6ed61a11599d0eace6ae64fd4156611bdbd5daf8d15f",
	"event_kinds.STATE_ROWS": "0b6b061bd12a30016b4d875b1b3e20b65117d7bda826307c27cbff8923c66403",  # 2026-10-17 damage families (PR #65): dented, zzapped and plated rows; was 46bbae44
	"event_kinds.CAUSE_ROWS": "9d20bee7f3e2a23dd09db3c08ab99e3fa0aab0f99d4373ef3398fff8601e0812",
	"event_kinds.ACTIVITY_ROWS": "dfdeb0c80b6c19754fafca7f979a60bee5cf039679370dcb5178d6ec0fc004de",  # 2026-10-17 stage/alpha-w16 combined re-pin (all admitted PRs together); was 3b128af8
	"event_kinds.LOOT_ROWS": "d4c8f52197ece082a337887a4d5358e6b611be8856bd10b61d534e43b53c76b3",  # 2026-10-27 (cobalt rung 1b): reveal stamps FIELD KIT and FLEET GRADE; was 41c5a573, 2026-10-27 (cobalt rung, item ladder): reward_rare wears cobalt; was 1d99aa49
	"event_kinds.UI_ROWS": "d273671a39e2e068f93fcb16ab58e05828ce2d41da20b331e7575443d394e793",  # 2026-11-10 (wave 36 unslop-hudwords, ruling cx): callout_notes reads "Hold {key_tab} for notes", no colon; was dc5151ef. 2026-11-09 (#639, the Scuttle hint): the hint_wall_bait row; existing rows unchanged; was 80f4cdd7. 2026-10-12 (w13 WEIGHT-1 c4e428c): posture_break sub-fact row; was 75718127, 2026-10-11 (w13 SQ6 cooldown refunds): cooldown_refunded row; was f8c0f271, 2026-10-08 (alpha wave 11 GP4 escape corridor): escape_acted row; was c6a2047c (wave 13 companion cues)
	"event_kinds.WORLD_ROWS": "8ae7c88a020249a461e8ea1bcf34b4f73275a6cca538eca95246213fc46f10b2",  # 2026-11-12 (sound gaps): shot_called hears call_ink and call_missed hears call_drop; was f7238d80. 2026-11-11 loops follow-up: call_window and shot_called move off hazard colour and the threat sound (LEGIBILITY section 1); was 21074ae4. 2026-11-11 PR 763 loops prototypes (docs/design/loops.md): Reservoir rows overtime_offered, overtime_rung, overtime_paid, sluice_warning, sluice_open and Called Shot rows call_window, shot_called, call_met, call_missed, all on existing sounds; was cb08395d. 2026-10-24 merge of #432 (flume pass two: sluice_siren, sluice_landed) onto the stage's Warden gate rows; was 21e52862 (stage) and 9fda93d2 (#432). 2026-10-24 Spillway Warden gate and arena locks (stage_locks.gd): arena_locked, arena_wave, arena_unlocked, warden_gate_pip, warden_gate_refused, warden_gate_opened; was d90545ca, 2026-10-17 stage/alpha-w16 combined re-pin (wave 17: dam, pit, sinkhole and crown layers; #105 picks wiring); was b3ad3296, 2026-10-18 sinkhole authored pass: cinder_glow, cinder_burn, cinder_cooled (floor is lava, Andrew 2026-10-17 23:24Z) and glaze_skim (the glazed walls' tell); was e40206db, 2026-10-17 stage/alpha-w16 combined re-pin (crown pass, first-win secrets, maker sets); was b1348f81, 2026-10-17 prop-crew-events (claude/prop-crew-events-fzz0ti): the Dig's lift cage (cage_rising, cage_landed) and the Highdraft's zipline drop (zipline_inbound, zipline_landed) forms; was a751eb28, 2026-10-13 KE-FORMS merge: five pending stage forms (crust_crack, drain_gurgle, trestle_groan, lightning_mark, reactor_overload) and their landed rows; was e29675bf, 2026-10-12 KE2 merge: ground_slump and ground_slump_landed rows (amend-ground-slump.md); was 33ad97e5, 2026-10-12, PC-TALLY merge 80634ba: Tally's achievements, cosmetics, tree, world-one cards and codex rows; event_kinds.WORLD_ROWS moved at the KE1 merge 61eaef0 (12 event kinds added), re-pinned here; was 4422c95c, 2026-10-11 (w13 KF2 and KF3, re-pinned by the coordinator at the Warden mechanism merges): ride_sheet, hoist_ride, pool_swell rows; was f3da5b1a, 2026-10-10 (w13 KC0 park placement): ride_bowl, ride_drop, ride_ledge, ride_hop rows; was 7284c545, 2026-10-09 (wave 12 VX-SURF 5a9e1ef): ANCIENT moved from 3d8bff to 9dff3c (Andrew's pick), which changes the colour value only; restoring the old colour restores the old hash; was 686afd81, 2026-10-05 (alpha wave 14 tally-ledger-row): ledger_returned row
	"event_kinds.THREAT_ROWS": "416e903fae944310bd492312f6fb7630c62b3f16f9f05f2789d7206019d431ad",
	"event_kinds.ATTACK_ROWS": "7f6b2d705f4406089d12c5e015aa105846e8e59015b58dcf04c18a8b5aa53c54",  # 2026-11-11 (wave 36 drop-hammer): labels only: E03 and E04 read "Drop hammer leap slam" and "Drop hammer charge" (NAMES.md: name the machine, never "the miniboss"; roster row name "Drop Hammer"). Before that, 2026-11-10 (wave 36 unslop-moments): W01 label "Reactor Warden pulse" is "Warden pulse" (both reactor variants use W01; the label is reached only for a hit whose source is "reactor", since row_id needs the row's owner to equal the source, and a Warden's own death reads "the Warden" through WORDS); was 4fcf80ed. 2026-10-24 merge of #385 (rogue E34-E39) onto the Spillway roster (E40); was d51b8ff2 (roster) and 8ead5150 (#385). 2026-10-23 w19 Spillway roster: the E40 boom tender sweep row (all fields filled); existing rows unchanged; was 0dac05c4, 2026-10-17 stage/alpha-w16 final combined re-pin (E19-E33 with the Highdraft roster (#72)); was 5e2f8472, 2026-10-17 stage/alpha-w16 combined re-pin (all admitted PRs together); was e55948dd
	"event_kinds.IMPACT": "5f39c4fc927ce05d2cf1062d00aefbcfbd32bb1af840123562582a42bb673245",  # 2026-10-18 (actives follow-up): the Glass Lance's lance row, so its Chain Arc jumps stagger like its pierce; was fb100593, 2026-10-17 stage/alpha-w16 combined re-pin (flail row plus the actives' rocket row); was 8d4d95e0, 2026-10-17 (poles and flails PF3): flail row
	"event_kinds.REACTIONS": "d69f61edda9075f25e0724226f87be0d35cb9688f1d840b76da4003371b92189",
	"event_kinds.CODEX_CATEGORIES": "4a61092895a1a12b1981249a32217abfacddc1bdec293c03948ca9f245700016",
	"objectives.ROWS": "26ebd270968a8e6f336b69df3798b3ad49e31e4c214f6afe55c8d6c86e193072",  # 2026-11-10 (wave 36 unslop-tips: no label colons, one imperative a row: "Break the yard crew", "Break the clamp crews", "Hook, shoot, smash core", "Get heavy, then return"; was 5c986af5; before that, second first-timer film, PF-11): one row a fight phase ("Latch on, shoot, smash core", "Shoot magnets, then cockpit", "Slam caps, then cockpit", "Bait into walls, then cockpit"); hit_cockpit, latch_warden and fire_from_line are gone; other rows unchanged; was 0ca8fadb
	"lore_rows.ROWS": "5d8ad2b4450a20aadfa841794e5370ed26f93ec06cb06b8228da11cd6df61882",  # 2026-11-10 player's-eye pass: the Spillway crews say where the Warden is ("Warden on the dam.", "Warden in the head house.") and the plate alone names it; was e783e242, 2026-10-23 world 1 unit 21: Brindle names the Cannon's shape (Andrew's silhouette ruling); was 54163c4a, 2026-10-18 All hands: six Mind crew-log notes (Andrew's pick); was 3c06c629, 2026-10-17 stage/alpha-w16 final combined re-pin (lore port plus the specials' rows); was 58031908, 2026-10-17 (wave 20 lore port, LORE-REPLACE): park rows lead each zone, 14+ notes each; was e19ddad3, 2026-10-08 (wave 10 ST6): Dig and Highdraft lore take the approved sample lines; was 2026-10-04 (wave 11): world 2 and 3 lore final
	"music_rows.ROWS": "6ae91061fe62a58b8935f508c4b253ffc8c8bb1cbe2d9167eddbb7c3c3126329",  # 2026-10-23 default and phase anthem rows (#411); was cd1c5296, 2026-10-23 rogue and boss anthem rows (#389); was 6b11ddc4, 2026-10-17 stage/alpha-w16 combined re-pin (wave 17: dam, pit, sinkhole and crown layers; #105 picks wiring); was 605ef0ab, 2026-10-17 stage/alpha-w16 combined re-pin (all admitted PRs together); was f9e1cca7
	"windup_rows.ROWS": "39e7378aeb4b997e7efac2e48e06d54d78d6ea117448bfb1cd1d92742ddbdb7e",  # 2026-11-10 catch trap's death scatters six pieces over 0.6 s (was a 4-piece 0.4 s pop, too weak on the PC reel); was 7a9baed4. 2026-10-26 miniboss phase two: E03/E04 read the live slam_crouch and charge_brace (phase-two leads); was 11509654. 2026-10-24 merge of #385 (rogue rows on E34-E39) onto the Spillway roster; was 6691834d (roster) and 34e4ef32 (#385). 2026-10-23 w19 Spillway roster: hooker warn_tether, ramp flipper warn_flap, jolt layer jolt_layer_tell, and the boom tender row (warn_reel); was 1850f9d8, 2026-10-17 stage/alpha-w16 final combined re-pin (specials plus ballast_heavy and gap_net); was bcedc4f9, 2026-10-17 stage/alpha-w16 combined re-pin (all admitted PRs together); was 10034808, 2026-10-17 (wave 18 Dispatcher): dispatcher row on E26 (attack-ids registry); was a38f788e, 2026-10-08 (wave 10 GP6 and AU2): idle, death and wind-up cue fields per kind
	"upgrade_tree.TREES": "0a528fab33712ae6f3cc6df0ec3f2bebdd6e58ea4e06644e952cc14d54818358",  # 2026-11-11 (wave 36 unslop-picks, ruling cx): effect words only, a digest of every non-text field is unchanged: the "Q:" and "Set piece:" labels read "Ultimate becomes <name>", no typed Q anywhere, one name per thing (bank, refill, bounce, discharge, machines), and "into pins" says what the code does (the knock is twice as hard); was e6b7f8d5, 2026-10-12 2026-10-12 PC-RIVET merge (Rivet's kit rows); was 9d9d5f89, 2026-10-12, PC-TALLY merge 80634ba: Tally's achievements, cosmetics, tree, world-one cards and codex rows; event_kinds.WORLD_ROWS moved at the KE1 merge 61eaef0 (12 event kinds added), re-pinned here; was 034688e2, 2026-10-12 W13 coordinator: PC-SABLE round 7 (0ad68fa) merged onto Kest and the Cannon; was 41980464, 2026-10-12 W13 coordinator: PC-KEST round 4 (ef725b8) merged onto the Cannon kit; was ac75dc7b, 2026-10-12 PC-CANNON merge (5e18183): Cannon kit rows; was 10a325b3, 2026-10-11 (w13 PC-TARN round 3): Tarn's kit, tree depths, codex, starter cosmetics and grant rows; was 55786d60, 2026-10-05 (alpha wave 16 cannon-look): cannon tree icons on ab_cannon_*
	"upgrade_tree.WORLD_ONE_NODES": "ad5ea36e90a39d3b6bfdd01522b6d93a9b3e74a5f931b5282907c8a1a2286079",  # 2026-11-11 (wave 36 unslop-picks, ruling cx): effect words only, a digest of every non-text field is unchanged: the "Q:" and "Set piece:" labels read "Ultimate becomes <name>", no typed Q anywhere, one name per thing (bank, refill, bounce, discharge, machines), and "into pins" says what the code does (the knock is twice as hard); was ea265fc4, 2026-10-12, 2026-10-12, PC-TALLY merge 80634ba: Tally's achievements, cosmetics, tree, world-one cards and codex rows; event_kinds.WORLD_ROWS moved at the KE1 merge 61eaef0 (12 event kinds added), re-pinned here; was d649afcb, 2026-10-05 (alpha wave 16 cannon-look): cannon tree icons on ab_cannon_*
	"combat.codex_entries.ENTRIES": "66f48cffd1d583a7a335a47b0f4991c6d1270b55949b6a7160a0aa6409cde5ab",  # 2026-11-11 w36 unslop-codex (ruling cx): codex lines say machines, hook, bounce and ultimate, name no key letter and carry no label-colon or exclamation; Set Piece is First Ultimate, Strike! is Strike, the winch drone card is Snap the Cable; words only, no id, detector or number moved; was 31911765, 2026-11-10 (card trim, #705): paddle_ride, rivet_line_drive and tally_skim shortened to fit the discovery card whole; meaning unchanged; was f32af018
	"boss.codex_entries.ENTRIES": "af05664d7996e33b627540ccdcfb68e2639bced90ef24adb219023a105843b88",
	# 2026-10-05 (alpha wave 14 w13-followups): Waking and Mind codex rows pinned
	"boss.codex_entries.WAKING": "cf77e5e481614790c0c581cf2ffc7cc7ad206802fb7f7adf41ca682c345e808f",
	"boss.codex_entries.MIND": "6acfd19449f8802b806ba76093fe15bd0c938c0a2f110230d9d38a5cbd004d87",
	"parts.rows": "9e4fe3c5a17365f4ac0962879daecdb03b6a245ab338078876cd6de1fa4769be",  # 2026-11-12 (Synergy Lens card line and text fit the shop cuts: words only); was 90283662, 2026-11-12 (Synergy Lens row fits nine words: words only); was a93a88c4, 2026-11-11 (synergy lens repointed: words only, no number moved); was ad5f0964, 2026-11-11 (systems audit fold: every world 1 part names a maker); was d35ccfe4, 2026-11-11 round 2 (review fixes: overcharge coil, evolved origin sentences, synergy lens, surge limits, capital after the name, Cracked Hull): words only, non-text digest unchanged; was c086da50, 2026-11-11 w36 unslop-parts (ruling cx): every part and item card line states its effect in at most six words, texts carry their numbers in plain sentences, one name per thing (bank, refill, bounce, harpoon, heft, machines), Rivet Plating is named Rivet Hull, Rebound Skin Bounce Skin, Grapple Coil Harpoon Coil; words only, a digest of every non-text field is unchanged (77665d06); was 1a82089a, 2026-11-10 w35 wording (ruling cw): Rivet Plating, Pylon Capacitor and Impact Driver say what they do, four cards say bounce, Scrap Armor is named Scrap Bulk; words only, no number moved; was b361ae58, 2026-10-27 w20 cobalt rung: impact_driver rare at tier 2 (was uncommon), touches verbs on horizon_optic, rime_rounds, galvanic_rounds and ram_plow; was b2392ada, 2026-10-22 w19 earned save: spare_frame adds one row (99 to 100 loot ids); was 88b884e0, 2026-10-17 stage/alpha-w16 combined re-pin (crown pass, first-win secrets, maker sets); was eb1dbba2, 2026-10-16 SG15: three levels (capped stack of 3, "levels") on hot_rivets, rivet_plating and magnet_spool; was c201e5c31cb1e43d32750622e1f3fd8a031d36254c469caf0dbb7206d1eb6d98, 2026-10-15 SQ19b (wave 14): winch_pawl row (Tally class, reel_speed 1.25) and a touches verb on long_barrel, magnet_spool, slag_rounds, chain_arc and the 21 alpha-listed item rows (set on each row in items.gd); was d8b46d3bb2dfe2daf6a91e45e161830fc9769dec898be4aea83912d4491cfa37, 2026-10-15 PC-POOL merge (grip_tread, vent_baffle, spring_shims class-only; live_line harpoon_lock_deg; drop_weight pin bonus): was d2d270a97094f0606b04359321e7405ca0b3c2337231ab8117e1863625386400, 2026-10-15 SG14-CONTRACT merge (cross_split weapon_damage 0.6, ruling C7): was 5277c3754d15c3ad31b9763a2d0234bc1fb587f3c8bc303cf809febe993efd6a, 2026-10-12 SR9 merge (relay_convergence row); was 488ede3f, SG5 round 3, 2026-10-11 (load_dividend touches fire): was ef735e5336f2a7e6fea4b12c9a4cd3936368accdb48fca9e3de8f117fca5b486 (SG5 round 1), before that 374d860be797b340774f2529139aeb4f5f115420cab91c33298533ddc16cfb7b (wave 11 GP-parts)
	"item_gen.RARITY": "2d1781de2528d605c781d9dbb96366c3fec9b75ec0944e75e35997bd31f6ebab",  # 2026-10-27 (cobalt rung 1b): stamps FIELD KIT and FLEET GRADE; was 99c548e2, 2026-10-27 (cobalt rung, item ladder): common field mint, rare cobalt, relic amber, colour values only; was abc72c1e.  2026-10-09 (wave 12 VX-SURF 5a9e1ef): ANCIENT moved from 3d8bff to 9dff3c (Andrew's pick), which changes the colour value only; restoring the old colour restores the old hash; was 8a6773cc
}


static func snapshot() -> Dictionary:
	var world_one := {}
	for pilot in Trees.WORLD_ONE_TABLES:
		world_one[pilot] = Trees.nodes(pilot, true).slice(0, Trees.WORLD_ONE_SIZE)
	return {
		"achievements.ROWS": Achievements.ROWS, "cosmetics.ROWS": Cosmetics.ROWS,
		"event_kinds.ROWS": Events.ROWS, "event_kinds.LINE_ROWS": Events.LINE_ROWS,
		"event_kinds.STATE_ROWS": Events.STATE_ROWS, "event_kinds.CAUSE_ROWS": Events.CAUSE_ROWS,
		"event_kinds.ACTIVITY_ROWS": Events.ACTIVITY_ROWS, "event_kinds.LOOT_ROWS": Events.LOOT_ROWS,
		"event_kinds.UI_ROWS": Events.UI_ROWS, "event_kinds.WORLD_ROWS": Events.WORLD_ROWS,
		"event_kinds.THREAT_ROWS": Events.THREAT_ROWS, "event_kinds.ATTACK_ROWS": Events.ATTACK_ROWS,
		"event_kinds.IMPACT": Events.IMPACT, "event_kinds.REACTIONS": Events.REACTIONS,
		"event_kinds.CODEX_CATEGORIES": Events.CODEX_CATEGORIES, "objectives.ROWS": Objectives.ROWS,
		"lore_rows.ROWS": Lore.ROWS, "music_rows.ROWS": Music.ROWS,
		"windup_rows.ROWS": Windup.ROWS, "upgrade_tree.TREES": Trees.TREES,
		"upgrade_tree.WORLD_ONE_NODES": world_one, "combat.codex_entries.ENTRIES": CombatCodex.ENTRIES,
		"boss.codex_entries.ENTRIES": BossCodex.ENTRIES, "boss.codex_entries.WAKING": BossCodex.WAKING,
		"boss.codex_entries.MIND": BossCodex.MIND, "parts.rows": Parts.rows(),
		"item_gen.RARITY": ItemGen.RARITY,
	}.duplicate(true)


# Code-owned lookups (pilot ids, bus signals, reachable objective ids) do not depend on the
# tables under validation, so one validate pass derives each once instead of once per row.
static var _pass_depth := 0
static var _pass := {}


static func _begin_pass() -> void:
	_pass_depth += 1


static func _end_pass() -> void:
	_pass_depth -= 1
	if _pass_depth == 0:
		_pass.clear()


static func _cached(key: String, make: Callable):
	if not _pass.has(key):
		_pass[key] = make.call()
	return _pass[key]


static func _pilot_ids() -> Array:
	return _cached("pilots", func(): return ClassDef.all().map(func(p): return p.id))


static func _bus() -> Dictionary:
	return _cached("bus", func(): return Achievements.bus_signals())


static func validate(tables: Dictionary, check_hashes := true) -> Array:
	_begin_pass()
	var issues := []
	for name in TABLES:
		issues.append_array(validate_table(name, tables.get(name), tables, check_hashes))
	for name in tables:
		if not TABLES.has(name):
			_issue(issues, str(name), "well_formed", "table", "unregistered table")
	_end_pass()
	return issues


static func validate_table(name: String, rows, tables: Dictionary, check_hash := true) -> Array:
	_begin_pass()
	var issues := _validate_table(name, rows, tables, check_hash)
	_end_pass()
	return issues


static func _validate_table(name: String, rows, tables: Dictionary, check_hash: bool) -> Array:
	var issues := []
	if not TABLES.has(name):
		_issue(issues, name, "well_formed", "table", "unregistered table")
		return issues
	var spec: Dictionary = TABLES[name]
	if not (rows is Dictionary or rows is Array):
		_issue(issues, name, "well_formed", "table", "expected a row dictionary or array")
		_issue(issues, name, "minimum_rows", "table", "registered table is absent")
		return issues
	var array_table: bool = spec.kind in ["lore", "codex"]
	if (rows is Array) != array_table:
		_issue(issues, name, "well_formed", "table", "wrong table container")
		return issues
	if rows.size() < spec.minimum:
		_issue(issues, name, "minimum_rows", "table", "has %d rows, needs %d" % [rows.size(), spec.minimum])
	if spec.kind in ["trees", "world_one_trees"]:
		_validate_trees(name, rows, spec, issues)
	else:
		var seen := {}
		for key in rows.size() if rows is Array else rows.keys():
			var row = rows[key]
			var id = row.get("id", "") if array_table and row is Dictionary else key
			if not (id is String) or id.strip_edges() == "" or seen.has(id):
				_issue(issues, name, "well_formed", str(key), "missing, non-string or repeated id")
			seen[id] = true
			if not _shape(name, str(id), row, spec.schema, issues):
				continue
			_validate_row(name, str(id), row, spec.kind, tables, issues)
		if spec.kind == "music" and not rows.has("default"):
			_issue(issues, name, "reachable", "default", "resolver requires a fallback row")
	if check_hash and digest(rows) != GOLDEN_HASHES.get(name, ""):
		_issue(issues, name, "golden_hash", "table", "observed %s" % digest(rows))
	return issues


static func _shape(name: String, id: String, row, schema: Dictionary, issues: Array) -> bool:
	if not row is Dictionary:
		_issue(issues, name, "well_formed", id, "row must be a dictionary")
		return false
	var ok := true
	for field in schema:
		if not row.has(field) or not _type_matches(row[field], schema[field]):
			_issue(issues, name, "well_formed", id, "%s missing or wrong type" % field)
			ok = false
	return ok


static func _type_matches(value, type: int) -> bool:
	if type == NUMBER:
		return (value is int or value is float) and is_finite(float(value))
	if type == TYPE_COLOR and value is Color:
		return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
	return typeof(value) == type


static func _validate_row(name: String, id: String, row: Dictionary, kind: String, tables: Dictionary, issues: Array) -> void:
	var pilots := _pilot_ids()
	var bus := _bus()
	match kind:
		"achievements":
			_ref(issues, name, id, "on", row.on, bus)
			for arg in row.get("where", {}) if row.get("where", {}) is Dictionary else {}:
				_ref(issues, name, id, "where", arg, bus.get(row.on, []))
			if row.has("sum"):
				_ref(issues, name, id, "sum", row.sum, bus.get(row.on, []))
			for reward in row.reward:
				var targets = (pilots + Achievements.PENDING_PILOTS) if reward == "pilot" else _ids(tables.get("cosmetics.ROWS", {}))
				if reward == "world":
					targets = Worlds.ROWS.map(func(w): return str(w.id))
				elif reward == "option":
					targets = MetaOptions.ids()
				elif reward == "item":
					targets = Parts.rows().keys()
				_ref(issues, name, id, "reward kind", reward, Achievements.REWARD_KINDS)
				_ref(issues, name, id, "reward", row.reward[reward], targets)
			for problem in Achievements.validate({id: row}, bus, pilots, _ids(tables.get("cosmetics.ROWS", {}))):
				if not str(problem).begins_with("table:"):
					_issue(issues, name, "well_formed", id, problem)
			if row.has("min") and row.has("max") and _type_matches(row.min, NUMBER) and _type_matches(row.max, NUMBER) and row.min > row.max:
				_issue(issues, name, "reachable", id, "minimum exceeds maximum")
		"cosmetics":
			_ref(issues, name, id, "slot", row.slot, Cosmetics.SLOTS)
			if row.pilot != "":
				_ref(issues, name, id, "pilot", row.pilot, pilots)
			for problem in Cosmetics.validate({id: row}, pilots):
				if not str(problem).begins_with("table:"):
					_issue(issues, name, "well_formed", id, problem)
			var earned: bool = row.starter
			var achievement_rows = tables.get("achievements.ROWS", {})
			if achievement_rows is Dictionary:
				for achievement in achievement_rows.values():
					if achievement is Dictionary and achievement.get("reward") is Dictionary:
						earned = earned or achievement.reward.get("cosmetic", "") == id
			if not earned:
				_issue(issues, name, "reachable", id, "neither starter nor achievement reward")
		"signals", "events":
			_ref(issues, name, id, "group", row.group, Events.GROUPS)
			_ref(issues, name, id, "shape", row.shape, Events.SHAPES)
			if kind == "signals":
				_ref(issues, name, id, "signal", id, bus)
			if row.priority < 0:
				_issue(issues, name, "well_formed", id, "negative priority")
		"states", "activities", "causes":
			_ref(issues, name, id, "color", row.color, Events.COLOR_ROLES)
			_ref(issues, name, id, "shape", row.shape, Events.SHAPES)
			if kind != "causes":
				_ref(issues, name, id, "motion", row.motion, Events.MOTIONS)
				_words(issues, name, id, row.word, 0, Events.MAX_WORDS)
			else:
				_ref(issues, name, id, "synergy", id, Synergies.ROWS)
				if row.motif.size() != 3 or not row.motif.all(func(note): return note is String and note != ""):
					_issue(issues, name, "well_formed", id, "motif needs three note names")
			if kind == "states" and row.verb != Events.NONE:
				_ref(issues, name, id, "verb", row.verb, Bindings.VERBS)
		"impact":
			_ref(issues, name, id, "stop", row.stop, Events.IMPACT_STOPS)
			_ref(issues, name, id, "react", row.react, _ids(tables.get("event_kinds.REACTIONS", {})))
			_nonnegative(issues, name, id, row, ["knock", "lift", "shake"])
		"reactions":
			_ref(issues, name, id, "reaction", id, Events.IMPACT_REACTS)
			_nonnegative(issues, name, id, row, TABLES[name].schema.keys())
		"categories":
			_ref(issues, name, id, "shape", row.shape, Events.SHAPES)
			_words(issues, name, id, row.label, 1, 3)
		"attacks":
			_ref(issues, name, id, "group", row.group, Events.ATTACK_GROUPS)
			_ref(issues, name, id, "allegiance", row.allegiance, ["hostile", "player", "neutral"])
			_ref(issues, name, id, "glyph", row.glyph, Events.SHAPES)
			if row.floor != Events.PLACEHOLDER:
				_ref(issues, name, id, "floor", row.floor, Events.FLOOR_MODES)
			if row.threat != "":
				_ref(issues, name, id, "threat", row.threat, _ids(tables.get("event_kinds.THREAT_ROWS", {})))
			var owners := {"roster": Roster.ROWS.keys(), "faction": Roster.FACTIONS.keys(), "class": pilots,
				"boss": Worlds.BOSSES.keys(), "pilot_any": ["any"], "rogue": Rogue.ROWS.keys()}
			_ref(issues, name, id, "owner_kind", row.owner_kind, owners)
			_ref(issues, name, id, "owner", row.owner, owners.get(row.owner_kind, []))
		"objectives":
			_ref(issues, name, id, "glyph", row.glyph, Icons.IDS)
			_words(issues, name, id, row.words, 1, Objectives.MAX_WORDS)
			if not _cached("objectives", func(): return _objective_ids()).has(id):
				_issue(issues, name, "reachable", id, "chooser cannot select this id")
		"lore":
			_ref(issues, name, id, "kind", row.kind, ["exchange", "field_note", "intro"])
			_ref(issues, name, id, "zone", row.zone, ["1-1", "1-2", "2-1", "2-2", "3-1", "3-2"])
			var cap: int = Lore.FIELD_NOTE_WORD_CAP
			if row.kind == "exchange":
				cap = Lore.EXCHANGE_LINE_WORD_CAP
				_shape(name, id, row, {"exchange": TYPE_STRING, "speaker": TYPE_STRING, "skippable": TYPE_BOOL}, issues)
			elif row.kind == "intro":
				cap = Lore.INTRO_LINE_WORD_CAP
				_ref(issues, name, id, "subject", row.get("subject", ""), ["warden"] + Worlds.BOSSES.keys())
				_intro_zone(issues, name, id, row)
			_words(issues, name, id, row.text, 1, cap)
		"music":
			_ref(issues, name, id, "theme", row.synth_theme, range(Music.THEME_COUNT))
			# Boss phase tracks and picked boss themes (phase_music.gd), the sound bible's screen picks
			# (camp, title-a/b/c; audio.gd) and the place-and-moment tunes (tune_moments.gd) are
			# music ids too: their rows name the packs those modules pick.
			_ref(issues, name, id, "music id", id, ["default", "title", "title-a", "title-b", "title-c", "camp", "summary", "1-1", "1-2", "2-1", "2-2", "3-1", "3-2"] + Worlds.BOSSES.keys()
				+ PhaseMusic.TRACKS + PhaseMusic.PICKED.values() + TuneMoments.TUNES.keys())
			# Missing optional ACE packs intentionally fall back to synth. Validate the path, not installation.
			if row.ace_manifest != "" and not (row.ace_manifest.begins_with("res://assets/music_ace/") and row.ace_manifest.ends_with("/manifest.json") and not ".." in row.ace_manifest):
				_issue(issues, name, "references", id, "manifest outside optional ACE pack root")
		"windup":
			_ref(issues, name, id, "roster", id, Roster.ROWS.keys() + Rogue.ROWS.keys())
			_ref(issues, name, id, "color_role", row.color_role, Events.COLOR_ROLES)
			_ref(issues, name, id, "shape", row.shape, Events.SHAPES)
			for attack in row.attacks:
				if attack != Events.NONE:
					_ref(issues, name, id, "attack", attack, _ids(tables.get("event_kinds.ATTACK_ROWS", {})))
				if not row.attacks[attack] is Array or not row.attacks[attack].all(func(field): return field is String and field != ""):
					_issue(issues, name, "well_formed", id, "attack timing fields must be an array of names")
		"codex":
			for field in ["name", "hint", "clue", "text"]:
				if row[field].strip_edges() == "":
					_issue(issues, name, "well_formed", id, "%s is empty" % field)
			_ref(issues, name, id, "category", CombatCodex.CATEGORY if name.begins_with("combat.") else BossCodex.CATEGORY, _ids(tables.get("event_kinds.CODEX_CATEGORIES", {})))
		"parts":
			_ref(issues, name, id, "rarity", row.rarity, _ids(tables.get("item_gen.RARITY", {})))
			if row.get("class_id", "") != "":
				_ref(issues, name, id, "class_id", row.class_id, pilots)
			for tag in row.tags:
				_ref(issues, name, id, "tag", tag, PartDef.TAGS)
			if row.tags.is_empty() or row.tier < 1:
				_issue(issues, name, "well_formed", id, "needs tags and a positive tier")
		"rarity":
			_ref(issues, name, id, "rarity", id, ItemGen.RARITIES)
			_nonnegative(issues, name, id, row, ["weight", "rung", "tier", "affix"])


static func _validate_trees(name: String, rows: Dictionary, spec: Dictionary, issues: Array) -> void:
	var pilots := _pilot_ids()
	var size: int = Trees.WORLD_ONE_SIZE if spec.kind == "world_one_trees" else Trees.SIZE
	for pilot in rows:
		_ref(issues, name, str(pilot), "pilot", pilot, pilots)
		if not rows[pilot] is Array:
			_issue(issues, name, "well_formed", str(pilot), "tree must be an ordered node array")
			continue
		var nodes: Array = rows[pilot]
		if nodes.size() < size:
			_issue(issues, name, "minimum_rows", str(pilot), "has %d nodes, needs %d" % [nodes.size(), size])
		# A node is reachable when it is selectable, inside the cap and its whole parent chain is.
		var reach: Array[bool] = []
		for index in nodes.size():
			reach.append(index < size and _selectable_node(nodes[index]) and (index < 2 or reach[(index - 2) / 2]))
		var seen := {}
		for index in nodes.size():
			var id := "%s/%d" % [pilot, index]
			var node = nodes[index]
			if not _shape(name, id, node, spec.schema, issues):
				continue
			if node.id == "" or seen.has(node.id):
				_issue(issues, name, "well_formed", id, "missing or repeated node id")
			seen[node.id] = true
			_words(issues, name, id, node.name, 1, Trees.NAME_WORDS)
			_words(issues, name, id, node.effect, 1, Trees.EFFECT_WORDS)
			_ref(issues, name, id, "key", node.key, Trees.KEYS)
			_ref(issues, name, id, "icon", node.icon, Icons.IDS.keys() + Icons.EXTRA.keys())
			for tag in node.tags:
				_ref(issues, name, id, "tag", tag, Trees.TAGS)
			if node.tags.is_empty() or not Trees.OPS.any(func(op): return node.has(op)):
				_issue(issues, name, "well_formed", id, "needs a tag and an op")
			for op in Trees.OPS:
				if node.has(op) and not _type_matches(node[op], TYPE_ARRAY if op == "proc" else TYPE_DICTIONARY):
					_issue(issues, name, "well_formed", id, "%s has wrong container" % op)
					continue
				match op:
					"knob":
						for knob in node.get(op, {}):
							_ref(issues, name, id, "knob", knob, Trees.KNOBS)
					"swap", "charges", "cooldown":
						for slot in node.get(op, {}):
							# A swap may replace Q's ultimate; charges and cooldowns stay on the five bar slots.
							_ref(issues, name, id, "slot", slot, AbilityState.SWAPPABLE if op == "swap" else AbilityState.SLOTS)
							if op == "swap":
								_ref(issues, name, id, "ability", node[op][slot], AbilityState.ABILITIES)
							elif not _type_matches(node[op][slot], NUMBER) or node[op][slot] <= 0:
								_issue(issues, name, "well_formed", id, "%s must be positive numbers" % op)
					"pattern":
						for weapon in node.get(op, {}):
							_ref(issues, name, id, "weapon", weapon, Weapons.ALL)
					"proc":
						for proc in node.get(op, []):
							if _shape(name, id, proc, {"on": TYPE_STRING, "do": TYPE_STRING}, issues):
								_ref(issues, name, id, "proc on", proc.on, _bus())
								_ref(issues, name, id, "proc do", proc.do, Trees.ACTIONS)
			# Both roots are selectable. Every later node needs its heap parent and stays inside the cap.
			var parent: int = (index - 2) / 2
			if index >= size or (index >= 2 and not reach[parent]):
				_issue(issues, name, "reachable", id, "outside selectable heap or missing parent")


static func _selectable_node(node) -> bool:
	return node is Dictionary and node.get("id") is String and node.id.strip_edges() != ""


# An intro row's zone must be a stage of the table. The Warden line plays at engagement in any
# zone; the second line is the boss's, voiced at the arena of the world's last zone, and is
# reserved (valid, unplayed) in the world's earlier zones. It is only valid for the boss that
# the zone's world owns. A row with a pilot is that boss's threat line for one pilot.
static func _intro_zone(issues: Array, name: String, id: String, row: Dictionary) -> void:
	var parts := String(row.zone).split("-")
	var world := int(parts[0]) if parts.size() == 2 and parts[0].is_valid_int() else 0
	var local := int(parts[1]) if parts.size() == 2 and parts[1].is_valid_int() else 0
	var found := false
	for stage in StageDefs.COUNT:
		if StageDefs.world_of(stage + 1) == world and StageDefs.local(stage + 1) == local:
			found = true
	if not found:
		_issue(issues, name, "references", id, "intro zone '%s' has no stage" % row.zone)
		return
	var subject: String = row.get("subject", "")
	if subject != "warden" and subject != String(Worlds.row(world).get("boss", "")):
		_issue(issues, name, "reachable", id, "second intro line needs a boss row for world %d; '%s' is not it" % [world, subject])
	if not row.has("pilot"):
		return
	# A pilot's threat line is the boss's, voiced only where the arena opens: the world's last zone.
	_ref(issues, name, id, "pilot", row.pilot, _pilot_ids())
	var last := 0
	for stage in StageDefs.COUNT:
		if StageDefs.world_of(stage + 1) == world:
			last = maxi(last, StageDefs.local(stage + 1))
	if subject == "warden" or local != last:
		_issue(issues, name, "reachable", id, "pilot line '%s' needs the boss at world %d's arena zone" % [row.pilot, world])


static func _objective_ids() -> Array:
	var ids := []
	for state in ["stage", "beacon", "gates", "launch", "boss"]:
		for fight in ["plating", "posture"]:
			for mask in 256:
				for lesson in ["plate", "caps", "magnet", "unknown"]:
					# The mounted reactor's rows and Brindle's phase rows ride two more keys each;
					# a row needs one reading that reaches it, so each pair walks as one axis.
					for extra in [{}, {"mount": "dam_face"}, {"mount": "flume"},
							{"phase": 1}, {"phase": 2}, {"phase": 3}, {"phase": 3, "open": true}, {"phase": 4}]:
						var reading := {"state": state, "fight": fight, "sealed": bool(mask & 1),
							"engaged": bool(mask & 2), "staggered": bool(mask & 4), "struggling": bool(mask & 8),
							"distance": 5.0 if mask & 16 else 90.0, "card": bool(mask & 32), "lesson": lesson, "site_at_hand": bool(mask & 32),
							"yard_locked": bool(mask & 64), "clamp_shut": bool(mask & 128)}
						reading.merge(extra, true)
						var id := Objectives.choose(reading)
						if id != "" and not ids.has(id):
							ids.append(id)
	return ids


static func _ids(rows) -> Array:
	if rows is Dictionary:
		return rows.keys()
	if rows is Array:
		return rows.filter(func(r): return r is Dictionary).map(func(r): return r.get("id", ""))
	return []


static func _ref(issues: Array, name: String, id: String, field: String, value, targets) -> void:
	if not targets.has(value):
		_issue(issues, name, "references", id, "%s '%s' does not resolve" % [field, value])


static func _words(issues: Array, name: String, id: String, value: String, minimum: int, maximum: int) -> void:
	var count := value.split(" ", false).size()
	if count < minimum or count > maximum:
		_issue(issues, name, "well_formed", id, "text has %d words, needs %d..%d" % [count, minimum, maximum])


static func _nonnegative(issues: Array, name: String, id: String, row: Dictionary, fields: Array) -> void:
	for field in fields:
		if row[field] < 0:
			_issue(issues, name, "well_formed", id, "%s must be nonnegative" % field)


static func _issue(issues: Array, name: String, rule: String, id: String, detail: String) -> void:
	issues.append({"table": name, "rule": rule, "row": id, "detail": detail})


# Typed leaves avoid JSON's loss of Color and int/float identity. Dictionary insertion
# order is irrelevant; arrays (lore dialogue and heap nodes) keep their authored order.
static func canonical(value) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return a < b if a is String and b is String else canonical(a) < canonical(b))
		var pairs := []
		for key in keys:
			pairs.append([canonical(key), canonical(value[key])])
		return JSON.stringify(["dictionary", pairs])
	if value is Array:
		return JSON.stringify(["array", value.map(func(item): return canonical(item))])
	return var_to_bytes(value).hex_encode()


static func digest(rows) -> String:
	return canonical(rows).sha256_text()
