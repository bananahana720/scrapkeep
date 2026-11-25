extends RefCounted


const Cosmetics := preload("res://src/core/cosmetics.gd")

const FIELDS := ["name", "text", "on", "where", "at_least", "sum", "count", "need", "min", "max", "hidden", "beat", "pilot", "reward"]
const SUMMARY_KEYS := ["class", "stages", "scrap", "mass", "heft", "parts", "kills", "events_won", "time", "retries", "save_used"]
const EVALUATOR_KEYS := ["class", "won", "world"]
const MASTERY_EVALUATOR_KEYS := ["class", "won", "world", "run_tier"]
const REWARD_KINDS := ["pilot", "cosmetic", "world", "option", "item"]
const NAME_WORDS := 3
const TEXT_WORDS := 12
const BEAT_WORDS := 14
const MIN_ROWS := 8
const PENDING_PILOTS := []
const GRANDFATHERED := ["kills_100", "kills_1000", "ach_d7_ink_stitch", "ach_d7_plum_curl",
	"ach_d7_forge_chips", "ach_d7_snail_shell", "ach_d7_thimble", "ach_d7_paw", "ach_d7_seashell",
	"ach_d7_forge_blue", "ach_d7_ember_plum", "ach_d7_dusk_pink"]

const ROWS := {
	"warden_broken": {"name": "Warden Breaker", "text": "Break your first Warden.", "on": "beacon_unsealed",
		"count": 1, "reward": {"cosmetic": "paint_any_night"}},
	"brindle_routed": {"name": "Brindle Routed", "text": "Rout Admiral Brindle.", "on": "enemy_killed",
		"where": {"kind": "brindle"}, "count": 1, "beat": "Tarn signed on the day Brindle fell. Brought a claw nobody issued.", "reward": {"pilot": "tarn"}},
	"rivet_rescued": {"name": "Runner Rescued", "text": "Rescue the stranded runner in world one.", "on": "rescue_completed",
		"where": {"quest_id": "rivet"}, "count": 1, "beat": "Rivet's back on the roster. Asked who locked the cage from inside.", "reward": {"pilot": "runner_gunner"}},
	"dig_rescued": {"name": "Digger Rescued", "text": "Rescue the buried digger.", "on": "rescue_completed",
		"where": {"quest_id": "dig"}, "count": 1, "beat": "Kest dug out. Says the wall knocked back the whole time.", "reward": {"pilot": "demolitions_caster"}},
	"isles_rescued": {"name": "Inventory Returned", "text": "Free the bookkeeper the Fleet filed as cargo.", "on": "rescue_completed",
		"where": {"quest_id": "isles"}, "count": 1, "beat": "Tally signed her own release form. Stamped it PAID.", "reward": {}},
	"kills_100": {"name": "Hundred Down", "text": "Break 100 machines across all your runs.", "on": "enemy_killed",
		"count": 100, "reward": {"cosmetic": "paint_rivet_forge"}},
	"kills_1000": {"name": "Thousand Down", "text": "Break 1000 machines across all your runs.", "on": "enemy_killed",
		"count": 1000, "reward": {"cosmetic": "paint_sable_violet"}},
	"first_win": {"name": "Run Won", "text": "Win a run.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "reward": {"cosmetic": "paint_kest_dusk"}},
	"clean_win": {"name": "Clean Run", "text": "Win a run without using the earned save.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "need": "save_used", "max": 0, "hidden": true, "reward": {"cosmetic": "paint_any_ink"}},
	"first_event": {"name": "Event Won", "text": "Win a world event.", "on": "milestone_won",
		"count": 1, "reward": {"cosmetic": "paint_any_kelp"}},
	"ten_events": {"name": "Event Regular", "text": "Win 10 world events across all your runs.", "on": "milestone_won",
		"count": 10, "reward": {"cosmetic": "paint_any_cobalt"}},
	"brindle_mark_sable": {"name": "Sable's Mark", "text": "Rout Brindle flying Sable.", "on": "enemy_killed",
		"where": {"kind": "brindle"}, "pilot": "pylon_engineer", "count": 1, "reward": {"item": "strike_pocket"}},
	"brindle_mark_rivet": {"name": "Rivet's Mark", "text": "Rout Brindle flying Rivet.", "on": "enemy_killed",
		"where": {"kind": "brindle"}, "pilot": "runner_gunner", "count": 1, "reward": {"item": "clean_break"}},
	"brindle_mark_tarn": {"name": "Tarn's Mark", "text": "Rout Brindle flying Tarn.", "on": "enemy_killed",
		"where": {"kind": "brindle"}, "pilot": "tarn", "count": 1, "reward": {"item": "warhead_slug"}},
	"brindle_mark_kest": {"name": "Kest's Mark", "text": "Rout Brindle flying Kest.", "on": "enemy_killed",
		"where": {"kind": "brindle"}, "pilot": "demolitions_caster", "count": 1, "reward": {"item": "ring_wave"}},
	"brindle_mark_tally": {"name": "Tally's Mark", "text": "Rout Brindle flying Tally.", "on": "enemy_killed",
		"where": {"kind": "brindle"}, "pilot": "tally", "count": 1, "reward": {"item": "salvage_drone"}},
	"brindle_mark_cannon": {"name": "Cannon's Mark", "text": "Rout Brindle flying the Cannon.", "on": "enemy_killed",
		"where": {"kind": "brindle"}, "pilot": "remembered_cannon", "count": 1, "reward": {"item": "scrap_geyser"}},
	"mind_quieted": {"name": "Mind Quieted", "text": "Quiet the Mind. An old cannon in the Highdraft remembers.",
		"on": "boss_defeated", "count": 1, "need": "world", "min": 3, "max": 3, "beat": "The Mind's guns went quiet. One turned up at the gate, cleaned.", "reward": {"pilot": "remembered_cannon"}},
	"ledger_balanced": {"name": "Ledger Balanced", "text": "Return one ledger leaf per world to Moss.", "on": "world_fact",
		"where": {"kind": "ledger_returned"}, "count": 3, "beat": "Three ledger leaves balanced. Tally walked in holding the pen that wrote them.", "reward": {"pilot": "tally"}},
	"full_rack": {"name": "Full Rack", "text": "Finish a run holding 10 parts.", "on": "run_ended",
		"count": 1, "need": "parts", "min": 10, "reward": {"cosmetic": "paint_any_brine"}},
	"waking_stilled": {"name": "Waking Stilled", "text": "Still the Waking in the Dig.", "on": "boss_defeated",
		"count": 1, "need": "world", "min": 2, "max": 2, "reward": {"cosmetic": "paint_tarn_dig"}},
	"highdraft_reached": {"name": "Highdraft Reached", "text": "Reach the Highdraft.", "on": "world_entered",
		"where": {"world": 3}, "count": 1, "reward": {"cosmetic": "paint_any_sky"}},
	"codex_keeper": {"name": "Codex Keeper", "text": "Discover 10 synergies across all your runs.", "on": "synergy_discovered",
		"where": {"first_time": true}, "count": 10, "reward": {"cosmetic": "paint_any_moth"}},
	"ach_d7_salt_skip": {"name": "Salt Skip", "text": "Finish one run.", "on": "run_ended", "count": 1, "reward": {"cosmetic": "trail_salt_skip"}},
	"ach_d7_ink_stitch": {"name": "Ink Stitch", "text": "Land 25 harpoon smashes.", "on": "harpoon_smashed", "count": 25, "reward": {"cosmetic": "trail_ink_stitch"}},
	"ach_d7_plum_curl": {"name": "Plum Curl", "text": "Land 50 slams.", "on": "slammed", "count": 50, "reward": {"cosmetic": "trail_plum_curl"}},
	"ach_d7_forge_chips": {"name": "Forge Chips", "text": "Break 250 machines.", "on": "enemy_killed", "count": 250, "reward": {"cosmetic": "trail_forge_chips"}},
	"ach_d7_moth_tuft": {"name": "Moth Tuft", "text": "Discover five distinct synergies.", "on": "synergy_discovered", "count": 5, "where": {"first_time": true}, "reward": {"cosmetic": "trail_moth_tuft"}},
	"ach_d7_rose_wash": {"name": "Rose Wash", "text": "Win five world events.", "on": "milestone_won", "count": 5, "reward": {"cosmetic": "trail_rose_wash"}},
	"ach_d7_fern": {"name": "Fern", "text": "Rescue the stranded runner.", "on": "rescue_completed", "count": 1, "where": {"quest_id": "rivet"}, "reward": {"cosmetic": "decal_fern"}},
	"ach_d7_patch": {"name": "Patch", "text": "Finish five runs.", "on": "run_ended", "count": 5, "reward": {"cosmetic": "decal_patch"}},
	"ach_d7_snail_shell": {"name": "Snail Shell", "text": "Release 100 harpoon lines.", "on": "grapple_released", "count": 100, "reward": {"cosmetic": "decal_snail_shell"}},
	"ach_d7_thimble": {"name": "Thimble", "text": "Collect 1000 cogs across your runs.", "on": "cogs_collected", "count": 1000, "sum": "amount", "reward": {"cosmetic": "decal_thimble"}},
	"ach_d7_mushroom": {"name": "Mushroom", "text": "Reach the Dig.", "on": "world_entered", "count": 1, "where": {"world": 2}, "reward": {"cosmetic": "decal_mushroom"}},
	"ach_d7_paw": {"name": "Paw", "text": "Jump 100 times.", "on": "jumped", "count": 100, "reward": {"cosmetic": "decal_paw"}},
	"ach_d7_seashell": {"name": "Seashell", "text": "Collect 5000 fresh scrap across your runs.", "on": "scrap_collected", "count": 5000, "sum": "amount", "reward": {"cosmetic": "decal_seashell"}},
	"ach_d7_moth": {"name": "Moth", "text": "Reach the Highdraft.", "on": "world_entered", "count": 1, "where": {"world": 3}, "reward": {"cosmetic": "decal_moth"}},
	"ach_d7_night_slate": {"name": "Night Slate", "text": "Survive a hit that spends SPIL-9's escape charge.", "on": "escape_window", "count": 1, "reward": {"cosmetic": "companion_paint_night"}},
	"ach_d7_forge_blue": {"name": "Forge Blue", "text": "Break 500 machines.", "on": "enemy_killed", "count": 500, "reward": {"cosmetic": "companion_paint_forge"}},
	"ach_d7_ember_plum": {"name": "Ember Plum", "text": "Use 100 specials.", "on": "special_used", "count": 100, "reward": {"cosmetic": "companion_paint_plum"}},
	"ach_d7_salt_white": {"name": "Salt White", "text": "Break three Wardens.", "on": "beacon_unsealed", "count": 3, "reward": {"cosmetic": "companion_paint_salt"}},
	"ach_d7_dusk_pink": {"name": "Dusk Pink", "text": "Win 15 world events.", "on": "milestone_won", "count": 15, "reward": {"cosmetic": "companion_paint_dusk"}},
	"ach_d7_moth_grey": {"name": "Moth Grey", "text": "Discover ten distinct synergies.", "on": "synergy_discovered", "count": 10, "where": {"first_time": true}, "reward": {"cosmetic": "companion_paint_moth"}},
	"ach_any_set_piece": {"name": "First Ultimate", "text": "Land your first ultimate.", "on": "synergy_discovered",
		"where": {"synergy_id": "set_piece"}, "count": 1, "reward": {"cosmetic": "trail_any_downbeat"}},
	"ach_any_curtain_call": {"name": "Curtain Call", "text": "Shatter an open Warden core with an ultimate landing.", "on": "synergy_discovered",
		"where": {"synergy_id": "set_piece_core"}, "count": 1, "reward": {"cosmetic": "decal_curtain_call"}},
	"ach_any_cash_in": {"name": "Cash In", "text": "Pay a chain of three with an ultimate landing.", "on": "synergy_discovered",
		"where": {"synergy_id": "set_piece_cash_in"}, "count": 1, "reward": {"cosmetic": "companion_skin_till_bell"}},
	"ach_meta_spare_reroll": {"name": "Busy Hands", "text": "Finish three activities.", "on": "activity_done",
		"count": 3, "reward": {"cosmetic": "paint_any_shift"}},
	"ach_meta_shelf_preview": {"name": "Wall Crumbler", "text": "Crumble two cracked walls.", "on": "world_fact",
		"where": {"kind": "wall_crumbled"}, "count": 2, "reward": {"cosmetic": "paint_any_mortar"}},
	"ach_meta_pocket_key": {"name": "Pocket Finder", "text": "Open the cache behind a cracked wall.", "on": "world_fact",
		"where": {"kind": "cache_spent"}, "count": 1, "reward": {"cosmetic": "paint_any_cache"}},
	"ach_meta_pocket_tint": {"name": "Fresh Eyes", "text": "Discover three new synergies.", "on": "synergy_discovered",
		"where": {"first_time": true}, "count": 3, "reward": {"cosmetic": "paint_any_spark"}},
	"ach_w19_mat_slip": {"name": "Slip the Mat", "text": "Slip a jolt layer's pulse.", "on": "synergy_discovered",
		"where": {"synergy_id": "mat_slip"}, "count": 1, "reward": {"cosmetic": "paint_any_jolt"}},
	"ach_w19_flap_ride": {"name": "Ride the Flap", "text": "Ride a sluice flap instead of tumbling.", "on": "synergy_discovered",
		"where": {"synergy_id": "flap_ride"}, "count": 1, "reward": {"cosmetic": "paint_any_sluice"}},
	"ach_w19_hook_out": {"name": "Hook Out", "text": "Snap a hooker's tether by hooking another post.", "on": "synergy_discovered",
		"where": {"synergy_id": "hook_out"}, "count": 1, "reward": {"cosmetic": "paint_any_tether"}},
	"ach_w19_soaked": {"name": "Soaked", "text": "Hit a soaked Spillway crew with arc.", "on": "synergy_discovered",
		"where": {"synergy_id": "armour_wet"}, "count": 1, "reward": {"cosmetic": "paint_any_soaked"}},
	"ach_w19_boom_strike": {"name": "Strike", "text": "Burst all five of a boom tender's floats in one sweep.", "on": "synergy_discovered",
		"where": {"synergy_id": "boom_strike"}, "count": 1, "reward": {"cosmetic": "paint_any_float"}},
	"ach_w20_kill_first": {"name": "Kill First", "text": "Break three kill-first specials across your runs.", "on": "special_broken",
		"count": 3, "reward": {"cosmetic": "paint_any_foreman"}},
	"ach_w20_signal_cache": {"name": "Signal Found", "text": "Find a Signal cache in a park.", "on": "radio_take_found",
		"where": {"source": "cache"}, "count": 1, "reward": {"cosmetic": "paint_any_signal"}},
	"ach_w20_legend_take": {"name": "Legend Heard", "text": "Find a legend-tier radio take.", "on": "radio_take_found",
		"where": {"tier": "legend"}, "count": 1, "reward": {"cosmetic": "paint_any_tape"}},
	"ach_w20_relay_stake": {"name": "Stake Paid", "text": "Win a relay you staked.", "on": "relay_stake_paid",
		"at_least": {"stakes": 1}, "count": 1, "reward": {"cosmetic": "paint_any_stake"}},
	"ach_w20_maker_set": {"name": "Set Complete", "text": "Complete a maker set in one run.", "on": "maker_set_completed",
		"count": 1, "reward": {"cosmetic": "paint_any_maker"}},
	"ach_w20_overflow": {"name": "Overflow Paid", "text": "Fire an active carrying three overflow pieces.", "on": "overflow_cashed",
		"at_least": {"pieces": 3}, "count": 1, "reward": {"cosmetic": "paint_any_overflow"}},
	# --- pylon_engineer (Sable): P-C Sable adds its grant rows here ---
	"ach_sable_cable_runs": {"name": "Cable Runner", "text": "Land three Cable Runs in one run.", "on": "synergy_discovered", "where": {"synergy_id": "sable_cable_runs"}, "count": 1, "reward": {"cosmetic": "trail_sable_cable"}},
	"ach_sable_parting_shot": {"name": "Parting Shot", "text": "Kill a machine within a second of a pylon slingshot.", "on": "synergy_discovered", "where": {"synergy_id": "parting_shot"}, "count": 1, "reward": {"cosmetic": "decal_sable_spool"}},
	"ach_sable_switchback": {"name": "Switchback", "text": "Bank Shot off a stake your Cable Run left.", "on": "synergy_discovered", "where": {"synergy_id": "switchback"}, "count": 1, "hidden": true, "reward": {"cosmetic": "shell_sable_felt"}},
	# --- end pylon_engineer ---
	# --- runner_gunner (Rivet): P-C Rivet adds its grant rows here ---
	"ach_rivet_line_true": {"name": "Line True", "text": "Land ten Line Drive punches in one stage.", "on": "synergy_discovered",
		"where": {"synergy_id": "rivet_line_true"}, "count": 1, "reward": {"cosmetic": "trail_rivet_swarf"}},
	"ach_rivet_shrugged": {"name": "Shrugged Off", "text": "Shrug off thirty holds and knocks in one run.", "on": "synergy_discovered",
		"where": {"synergy_id": "rivet_shrugged"}, "count": 1, "reward": {"cosmetic": "outfit_rivet_hood"}},
	"ach_rivet_full_breach": {"name": "Full Breach", "text": "Land one Foundry Cutter on six machines.", "on": "ultimate_landed",
		"where": {"ultimate_id": "foundry_cutter"}, "at_least": {"hits": 6}, "count": 1, "reward": {"cosmetic": "shell_rivet_calibrated"}},
	# --- end runner_gunner ---
	# --- demolitions_caster (Kest): P-C Kest adds its grant rows here ---
	"ach_kest_blast_vault": {"name": "Blast Vault", "text": "Let your own Cable Charge throw you clear.", "hidden": true, "on": "synergy_discovered", "where": {"synergy_id": "kest_blast_vault"}, "count": 1, "reward": {"cosmetic": "trail_kest_fuse_smoke"}},
	"ach_kest_homecoming": {"name": "Homecoming", "text": "Fly Kest into the Highdraft.", "on": "synergy_discovered", "where": {"synergy_id": "kest_homecoming"}, "count": 1, "reward": {"cosmetic": "paint_kest_rigger"}},
	"ach_kest_tick_tick_boom": {"name": "Tick, Tick, Boom", "text": "Strike eight machines with one Windhover.", "on": "synergy_discovered", "where": {"synergy_id": "kest_tick_tick_boom"}, "count": 1, "reward": {"cosmetic": "shell_kest_roost"}},
	# --- end demolitions_caster ---
	# --- tarn (Tarn): P-C Tarn adds its grant rows here ---
	"ach_tarn_dragged": {"name": "Ten Dragged", "text": "Drag ten machines into your claws in one stage.", "on": "synergy_discovered",
		"where": {"synergy_id": "tarn_dragged"}, "count": 1, "reward": {"cosmetic": "trail_tarn_claw_marks"}},
	"ach_tarn_six_at_once": {"name": "Six at Once", "text": "Land Redjaw Rend on six machines at once.", "on": "ultimate_landed",
		"where": {"ultimate_id": "redjaw_rend"}, "at_least": {"hits": 6}, "count": 1, "reward": {"cosmetic": "shell_tarn_redjaw_teeth"}},
	"ach_tarn_hold_still": {"name": "Hold Still", "text": "Break a hold with Redjaw Rend three times.", "hidden": true, "on": "synergy_discovered",
		"where": {"synergy_id": "tarn_hold_still"}, "count": 1, "reward": {"cosmetic": "outfit_tarn_steady_cap"}},
	# --- end tarn ---
	# --- tally (Tally): P-C Tally adds its grant rows here ---
	"ach_tally_punch_tape": {"name": "Punch Tape", "text": "Fire the ledger clip ten times in one stage.", "on": "synergy_discovered",
		"where": {"synergy_id": "tally_punch_tape"}, "count": 1, "reward": {"cosmetic": "trail_tally_punch_tape"}},
	"ach_tally_eyeshade": {"name": "Eyeshade", "text": "Settle twenty clips with Plate Return in one run.", "on": "synergy_discovered",
		"where": {"synergy_id": "tally_eyeshade"}, "count": 1, "reward": {"cosmetic": "outfit_tally_eyeshade"}},
	"ach_tally_books_balanced": {"name": "Books Balanced", "text": "Settle six clips with one landing.", "hidden": true, "on": "synergy_discovered",
		"where": {"synergy_id": "tally_books_balanced"}, "count": 1, "reward": {"cosmetic": "shell_tally_abacus"}},
	# --- end tally ---
	# --- remembered_cannon (the Cannon): P-C Cannon adds its grant rows here ---
	"ach_cannon_recital": {"name": "Recital", "text": "Land the four families in the order the gun hums.", "on": "synergy_discovered", "where": {"synergy_id": "cannon_recital"}, "count": 1, "hidden": true, "reward": {"cosmetic": "trail_cannon_recital"}},
	"ach_cannon_time_on_target": {"name": "Time on Target", "text": "Land a Fire Mission on eight machines at once.", "on": "synergy_discovered", "where": {"synergy_id": "cannon_time_on_target"}, "count": 1, "reward": {"cosmetic": "paint_cannon_lens"}},
	"ach_cannon_old_tune": {"name": "Old Tune", "text": "Quiet the Mind with its own gun.", "on": "synergy_discovered", "where": {"synergy_id": "cannon_old_tune"}, "count": 1, "hidden": true, "reward": {"cosmetic": "shell_cannon_choir"}},
	# --- end remembered_cannon ---
	"secret_paint_sable": {"name": "Sable's Second Coat", "text": "Win a run.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "hidden": true, "reward": {"cosmetic": "paint_sable_overtime"}},
	"secret_paint_rivet": {"name": "Rivet's Second Coat", "text": "Win a run.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "hidden": true, "reward": {"cosmetic": "paint_rivet_inside_job"}},
	"secret_paint_kest": {"name": "Kest's Second Coat", "text": "Win a run.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "hidden": true, "reward": {"cosmetic": "paint_kest_knock_back"}},
	"secret_paint_tarn": {"name": "Tarn's Second Coat", "text": "Win a run.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "hidden": true, "reward": {"cosmetic": "paint_tarn_unissued"}},
	"secret_paint_tally": {"name": "Tally's Second Coat", "text": "Win a run.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "hidden": true, "reward": {"cosmetic": "paint_tally_carbon"}},
	"secret_paint_cannon": {"name": "Cannon's Second Coat", "text": "Win a run.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "hidden": true, "reward": {"cosmetic": "paint_cannon_velvet"}},
}

const MASTERY_ROWS := {
	"dig_warden_broken": {"name": "Swarm Breaker", "text": "Break a Swarm Warden in the Dig.", "on": "beacon_unsealed",
		"count": 1, "need": "world", "min": 2, "max": 2, "reward": {}},
	"highdraft_warden_broken": {"name": "Crown Breaker", "text": "Break a Mind Warden in the Highdraft.", "on": "beacon_unsealed",
		"count": 1, "need": "world", "min": 3, "max": 3, "reward": {}},
	"dig_mark_sable": {"name": "Sable's Dig Mark", "text": "Still the Waking flying Sable.", "on": "boss_defeated",
		"pilot": "pylon_engineer", "count": 1, "need": "world", "min": 2, "max": 2, "reward": {}},
	"dig_mark_rivet": {"name": "Rivet's Dig Mark", "text": "Still the Waking flying Rivet.", "on": "boss_defeated",
		"pilot": "runner_gunner", "count": 1, "need": "world", "min": 2, "max": 2, "reward": {}},
	"dig_mark_tarn": {"name": "Tarn's Dig Mark", "text": "Still the Waking flying Tarn.", "on": "boss_defeated",
		"pilot": "tarn", "count": 1, "need": "world", "min": 2, "max": 2, "reward": {}},
	"dig_mark_kest": {"name": "Kest's Dig Mark", "text": "Still the Waking flying Kest.", "on": "boss_defeated",
		"pilot": "demolitions_caster", "count": 1, "need": "world", "min": 2, "max": 2, "reward": {}},
	"dig_mark_tally": {"name": "Tally's Dig Mark", "text": "Still the Waking flying Tally.", "on": "boss_defeated",
		"pilot": "tally", "count": 1, "need": "world", "min": 2, "max": 2, "reward": {}},
	"dig_mark_cannon": {"name": "Cannon's Dig Mark", "text": "Still the Waking flying the Cannon.", "on": "boss_defeated",
		"pilot": "remembered_cannon", "count": 1, "need": "world", "min": 2, "max": 2, "reward": {}},
	"crown_mark_sable": {"name": "Sable's Crown Mark", "text": "Quiet the Mind flying Sable.", "on": "boss_defeated",
		"pilot": "pylon_engineer", "count": 1, "need": "world", "min": 3, "max": 3, "reward": {}},
	"crown_mark_rivet": {"name": "Rivet's Crown Mark", "text": "Quiet the Mind flying Rivet.", "on": "boss_defeated",
		"pilot": "runner_gunner", "count": 1, "need": "world", "min": 3, "max": 3, "reward": {}},
	"crown_mark_tarn": {"name": "Tarn's Crown Mark", "text": "Quiet the Mind flying Tarn.", "on": "boss_defeated",
		"pilot": "tarn", "count": 1, "need": "world", "min": 3, "max": 3, "reward": {}},
	"crown_mark_kest": {"name": "Kest's Crown Mark", "text": "Quiet the Mind flying Kest.", "on": "boss_defeated",
		"pilot": "demolitions_caster", "count": 1, "need": "world", "min": 3, "max": 3, "reward": {}},
	"crown_mark_tally": {"name": "Tally's Crown Mark", "text": "Quiet the Mind flying Tally.", "on": "boss_defeated",
		"pilot": "tally", "count": 1, "need": "world", "min": 3, "max": 3, "reward": {}},
	"crown_mark_cannon": {"name": "Cannon's Crown Mark", "text": "Quiet the Mind flying the Cannon.", "on": "boss_defeated",
		"pilot": "remembered_cannon", "count": 1, "need": "world", "min": 3, "max": 3, "reward": {}},
	"ach_rogues_all": {"name": "Off the Books", "text": "Down three rogue machines across the works.", "on": "world_fact",
		"where": {"kind": "rogue_downed"}, "count": 3, "reward": {}},
	"ach_patch_trail": {"name": "Signed in Chalk", "text": "Find all three wire rooms along the trail.", "on": "world_fact",
		"where": {"kind": "patch_wire_found"}, "count": 3, "hidden": true, "reward": {}},
	"hard_rung_1": {"name": "Hard Rung One", "text": "Win a run on hard rung one.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "need": "run_tier", "min": 1, "reward": {}},
	"hard_rung_2": {"name": "Hard Rung Two", "text": "Win a run on hard rung two.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "need": "run_tier", "min": 2, "reward": {}},
	"hard_rung_3": {"name": "Hard Rung Three", "text": "Win a run on hard rung three.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "need": "run_tier", "min": 3, "reward": {}},
	"hard_rung_4": {"name": "Hard Rung Four", "text": "Win a run on hard rung four.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "need": "run_tier", "min": 4, "reward": {}},
	"hard_rung_5": {"name": "Hard Rung Five", "text": "Win a run on hard rung five.", "on": "run_ended",
		"where": {"won": true}, "count": 1, "need": "run_tier", "min": 5, "reward": {}},
}


static func ids() -> Array:
	return ROWS.keys()


static func mastery_ids() -> Array:
	return MASTERY_ROWS.keys()


static func all_rows() -> Dictionary:
	var out := ROWS.duplicate(false)
	for id in MASTERY_ROWS:
		out[id] = MASTERY_ROWS[id]
	return out


static func row(id: String) -> Dictionary:
	if ROWS.has(id):
		return ROWS[id]
	return MASTERY_ROWS.get(id, {})


static func reward_of(id: String) -> Dictionary:
	return row(id).get("reward", {})


static func beat_of(id: String) -> String:
	return String(row(id).get("beat", ""))


static func toast_text(id: String) -> String:
	var title := String(row(id).get("name", id))
	var beat := beat_of(id)
	if beat != "":
		return "%s\n%s" % [title, beat]
	var item := String(reward_of(id).get("cosmetic", ""))
	if item != "" and not Cosmetics.is_pending(item) and not Cosmetics.row(item).is_empty():
		return "%s\nNew look: %s" % [title, Cosmetics.row(item)["name"]]
	return title


static func for_pilot(pilot_id: String) -> String:
	for id in ROWS:
		if ROWS[id].get("reward", {}).get("pilot", "") == pilot_id and pilot_id != "":
			return id
	return ""


static func for_cosmetic(cosmetic_id: String) -> String:
	for id in ROWS:
		if ROWS[id].get("reward", {}).get("cosmetic", "") == cosmetic_id and cosmetic_id != "":
			return id
	return ""


static func bus_signals() -> Dictionary:
	var out := {}
	var script: Script = load("res://src/core/game_events.gd")
	for info in script.get_script_signal_list():
		var args: Array = []
		for arg in info["args"]:
			args.append(arg["name"])
		out[info["name"]] = args
	return out


static func _words(s: String) -> int:
	return s.split(" ", false).size()


static func validate(rows: Dictionary, signals: Dictionary, pilots: Array, cosmetics: Array) -> Array:
	var problems: Array = []
	var pilot_rewards := {}
	if rows.size() < MIN_ROWS:
		problems.append("table: needs at least %d rows, has %d" % [MIN_ROWS, rows.size()])
	for id in rows:
		var r: Dictionary = rows[id]
		for key in r:
			if not FIELDS.has(key):
				problems.append("%s: unknown field %s" % [id, key])
		var title: String = str(r.get("name", ""))
		if title == "" or _words(title) > NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, NAME_WORDS])
		var text: String = str(r.get("text", ""))
		if text == "" or _words(text) > TEXT_WORDS:
			problems.append("%s: text must be 1 to %d words" % [id, TEXT_WORDS])
		var beat: String = str(r.get("beat", ""))
		if _words(beat) > BEAT_WORDS:
			problems.append("%s: beat must be %d words or fewer" % [id, BEAT_WORDS])
		if r.get("reward") is Dictionary and r["reward"].has("pilot") and beat == "":
			problems.append("%s: a pilot reward row needs a beat line" % id)
		var on: String = str(r.get("on", ""))
		var args: Array = signals.get(on, [])
		if not signals.has(on):
			problems.append("%s: on %s is not a declared signal" % [id, on])
		var where = r.get("where", {})
		if not (where is Dictionary):
			problems.append("%s: where must be a dictionary of argument to value" % id)
		else:
			for key in where:
				if signals.has(on) and not args.has(key):
					problems.append("%s: where key %s is not an argument of %s" % [id, key, on])
			if where.has("synergy_id") and where.has("first_time"):
				problems.append("%s: a grant on one named discovery cannot filter first_time" % id)
		var at_least = r.get("at_least", {})
		if not (at_least is Dictionary):
			problems.append("%s: at_least must be a dictionary of argument to number" % id)
		else:
			for key in at_least:
				if signals.has(on) and not args.has(key):
					problems.append("%s: at_least key %s is not an argument of %s" % [id, key, on])
				if not (at_least[key] is int or at_least[key] is float):
					problems.append("%s: at_least %s must be a number" % [id, key])
		if r.has("sum") and signals.has(on) and not args.has(r["sum"]):
			problems.append("%s: sum %s is not an argument of %s" % [id, r["sum"], on])
		if not (r.get("count", 0) is int) or int(r.get("count", 0)) < 1:
			problems.append("%s: count must be an integer of at least 1" % id)
		if int(r.get("count", 0)) > 10 and not id in GRANDFATHERED:
			problems.append("%s: new grants must have count at most 10" % id)
		if r.has("need") and not (SUMMARY_KEYS.has(r["need"]) or EVALUATOR_KEYS.has(r["need"])):
			problems.append("%s: need %s is not a summary key, class, won or world" % [id, r.get("need")])
		for bound in ["min", "max"]:
			if r.has(bound):
				if not (r[bound] is int or r[bound] is float):
					problems.append("%s: %s must be a number" % [id, bound])
				elif not r.has("need"):
					problems.append("%s: %s needs a need key to compare" % [id, bound])
		if r.has("pilot") and not pilots.has(str(r["pilot"])):
			problems.append("%s: pilot %s is not a ClassDef id" % [id, r["pilot"]])
		if r.has("hidden") and not (r["hidden"] is bool):
			problems.append("%s: hidden must be a bool" % id)
		var reward = r.get("reward")
		if not (reward is Dictionary):
			problems.append("%s: reward must be a dictionary" % id)
			continue
		if reward.size() > 1:
			problems.append("%s: reward must carry at most one kind" % id)
		for kind in reward:
			var target := str(reward[kind])
			if not REWARD_KINDS.has(kind):
				problems.append("%s: reward kind %s is unknown" % [id, kind])
			elif kind == "pilot":
				if not pilots.has(target) and not PENDING_PILOTS.has(target):
					problems.append("%s: reward pilot %s does not resolve" % [id, target])
				elif pilots.has(target) and PENDING_PILOTS.has(target):
					problems.append("%s: reward pilot %s has a ClassDef row; remove it from PENDING_PILOTS" % [id, target])
				elif pilot_rewards.has(target):
					problems.append("%s: reward pilot %s is already the reward of %s" % [id, target, pilot_rewards[target]])
				else:
					pilot_rewards[target] = id
			elif kind == "cosmetic" and not cosmetics.has(target):
				problems.append("%s: reward cosmetic %s does not resolve" % [id, target])
			elif kind == "world" and target == "":
				problems.append("%s: reward world must name a world" % id)
			elif kind == "option" and target == "":
				problems.append("%s: reward option must name a meta_options node" % id)
			elif kind == "item" and target == "":
				problems.append("%s: reward item must name an items.gd row (shift_board.gd validate checks it)" % id)
	return problems


static func recorded_sources(id: String) -> Array:
	var target := row(id)
	var out: Array = []
	if target.is_empty() or not id.begins_with("ach_d7_"):
		return out
	for source_id in ROWS:
		var source: Dictionary = ROWS[source_id]
		if source["on"] != target["on"] or source.get("sum", "") != target.get("sum", ""):
			continue
		var compatible := true
		for key in target.get("where", {}):
			if source.get("where", {}).get(key) != target["where"][key]:
				compatible = false
		if compatible:
			out.append(source_id)
	return out


static func validate_mastery(signals: Dictionary, pilots: Array, cosmetics: Array = [], rows_to_check: Dictionary = MASTERY_ROWS) -> Array:
	var problems: Array = []
	for id in rows_to_check:
		if ROWS.has(id):
			problems.append("%s: collides with ROWS" % id)
		var r = rows_to_check[id]
		if not (r is Dictionary):
			problems.append("%s: row must be a dictionary" % id)
			continue
		for key in r:
			if not FIELDS.has(key):
				problems.append("%s: unknown field %s" % [id, key])
		var title := str(r.get("name", ""))
		if title == "" or _words(title) > NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, NAME_WORDS])
		var text := str(r.get("text", ""))
		if text == "" or _words(text) > TEXT_WORDS:
			problems.append("%s: text must be 1 to %d words" % [id, TEXT_WORDS])
		var on := str(r.get("on", ""))
		var args: Array = signals.get(on, [])
		if not signals.has(on):
			problems.append("%s: on %s is not a declared signal" % [id, on])
		var where = r.get("where", {})
		if not (where is Dictionary):
			problems.append("%s: where must be a dictionary" % id)
		else:
			for key in where:
				if signals.has(on) and not args.has(key):
					problems.append("%s: where key %s is not an argument of %s" % [id, key, on])
		var at_least = r.get("at_least", {})
		if not (at_least is Dictionary):
			problems.append("%s: at_least must be a dictionary" % id)
		else:
			for key in at_least:
				if signals.has(on) and not args.has(key):
					problems.append("%s: at_least key %s is not an argument of %s" % [id, key, on])
				if not (at_least[key] is int or at_least[key] is float):
					problems.append("%s: at_least %s must be a number" % [id, key])
		if not (r.get("count", 0) is int) or int(r.get("count", 0)) < 1 or int(r.get("count", 0)) > 10:
			problems.append("%s: count must be an integer from 1 to 10" % id)
		if r.has("need") and not (SUMMARY_KEYS.has(r["need"]) or MASTERY_EVALUATOR_KEYS.has(r["need"])):
			problems.append("%s: need %s is not valid" % [id, r.get("need")])
		for bound in ["min", "max"]:
			if r.has(bound):
				if not (r[bound] is int or r[bound] is float):
					problems.append("%s: %s must be a number" % [id, bound])
				elif not r.has("need"):
					problems.append("%s: %s needs a need key to compare" % [id, bound])
		if r.has("pilot") and not pilots.has(str(r["pilot"])):
			problems.append("%s: pilot %s is not a ClassDef id" % [id, r["pilot"]])
		if r.has("hidden") and not (r["hidden"] is bool):
			problems.append("%s: hidden must be a bool" % id)
		var reward = r.get("reward")
		if not (reward is Dictionary):
			problems.append("%s: reward must be a dictionary" % id)
			continue
		if reward.size() > 1:
			problems.append("%s: reward must carry at most one kind" % id)
		for kind in reward:
			var target := str(reward[kind])
			if not REWARD_KINDS.has(kind):
				problems.append("%s: reward kind %s is unknown" % [id, kind])
			elif kind == "cosmetic" and not cosmetics.is_empty() and not cosmetics.has(target):
				problems.append("%s: reward cosmetic %s does not resolve" % [id, target])
			elif kind == "pilot" and not pilots.has(target):
				problems.append("%s: reward pilot %s does not resolve" % [id, target])
	return problems
