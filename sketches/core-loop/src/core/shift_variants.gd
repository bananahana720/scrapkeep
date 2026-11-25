extends RefCounted


const ShiftBoard := preload("res://src/core/shift_board.gd")
const Panels := preload("res://src/build/panels.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

const OVERTIME := "overtime"
const DAM_NIGHT_SHIFT := "dam_night_shift"
const CREW_SHORT := "crew_short"
const MALPAIS_MONSOON := "malpais_monsoon"
const HIGHDRAFT_ECLIPSE := "highdraft_eclipse"

const BUILT := [OVERTIME, DAM_NIGHT_SHIFT, CREW_SHORT, MALPAIS_MONSOON, HIGHDRAFT_ECLIPSE]

const WORLD_VARIANT_GATES := {
	MALPAIS_MONSOON: "waking_stilled",
	HIGHDRAFT_ECLIPSE: "highdraft_reached",
}

const RUN_KEY := "shift_variants"
const OVERTIME_PAID_KEY := "overtime_panel_stage"

const DEBUT_STAT_PREFIX := "shift.variant_seen."

const DRAW_CHANCE := 0.35

const NIGHT_LOOK_ID := "dam_night"
const NIGHT_PACK_SCALE := 1.25
const NIGHT_INTERVAL_SCALE := 0.85
const NIGHT_SHIFT_CAGE_QUEST := "night_shift_salvage"
const NIGHT_SHIFT_CAGE_SCRAP := 180
const NIGHT_SHIFT_CAGE := {
	"id": "night_shift_cage",
	"site": "shelf_rise",
	"at": Vector2(-260.0, -430.0),
	"face": Vector2(1.0, 0.0),
	"quest": NIGHT_SHIFT_CAGE_QUEST,
	"pilot": "",
	"prompt": "crack the night cage",
}

const OVERTIME_WAKE_SCALE := 2.0

const CREW_SHORT_CACHE := {
	"id": "cracked_cache",
	"row": "crew_short_cache",
	"site": "toe_apron",
	"at": Vector2(36.0, 460.0),
	"face": Vector2(-1.0, -1.0),
	"pay": {"rarities": ["rare"]},
}

const MONSOON_LOOK_ID := "malpais_monsoon"
const MONSOON_PACK_SCALE := 1.2
const MONSOON_INTERVAL_SCALE := 0.88
const MONSOON_CACHES := {
	"park_pit": {
		"id": "cracked_cache",
		"row": "monsoon_pit_cache",
		"site": "leach_pads",
		"at": Vector2(240.0, -760.0),
		"face": Vector2(-1.0, 0.0),
		"pay": {"rarities": ["rare"]},
	},
	"park_sinkhole": {
		"id": "cracked_cache",
		"row": "monsoon_sinkhole_cache",
		"site": "west_trench",
		"at": Vector2(-568.0, 104.0),
		"face": Vector2(1.0, 0.0),
		"pay": {"rarities": ["rare"]},
	},
}

const ECLIPSE_LOOK_ID := "highdraft_eclipse"
const ECLIPSE_PACK_SCALE := 1.22
const ECLIPSE_INTERVAL_SCALE := 0.85
const ECLIPSE_ELITE_SCALE := 1.15
const ECLIPSE_CACHES := {
	"park_islands": {
		"id": "cracked_cache",
		"row": "eclipse_islands_cache",
		"site": "isle_apron",
		"at": Vector2(520.0, 728.0),
		"face": Vector2(-1.0, 0.0),
		"pay": {"rarities": ["rare"]},
	},
	"park_crown": {
		"id": "cracked_cache",
		"row": "eclipse_crown_cache",
		"site": "bajada_head",
		"at": Vector2(-576.0, -752.0),
		"face": Vector2(1.0, 0.0),
		"pay": {"rarities": ["rare"]},
	},
}

const CARD_ROWS := {
	DAM_NIGHT_SHIFT: {"id": DAM_NIGHT_SHIFT, "word": "Night Shift", "line": "Floodlights on, fuller crew, one more cage."},
	OVERTIME: {"id": OVERTIME, "word": "Overtime", "line": "Wardens wake early and pay a panel."},
	CREW_SHORT: {"id": CREW_SHORT, "word": "Short Crew", "line": "No dam shop. Cache on the apron."},
	MALPAIS_MONSOON: {"id": MALPAIS_MONSOON, "word": "Malpais Monsoon", "line": "Storm benches, brisk crew, extra cache."},
	HIGHDRAFT_ECLIPSE: {"id": HIGHDRAFT_ECLIPSE, "word": "Highdraft Eclipse", "line": "Dim thermals, sharp patrols, rim cache."},
}

static var _forced: Variant = null


static func force(ids: Array) -> void:
	_forced = _sanitize(ids)


static func clear_force() -> void:
	_forced = null


static func forced() -> Variant:
	if _forced != null:
		return (_forced as Array).duplicate()
	var from_cli = _cli_forced()
	return from_cli if from_cli != null else null


static func _cli_forced() -> Variant:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("--shift-variant="):
			var raw := text.substr("--shift-variant=".length()).strip_edges()
			if raw == "" or raw == "none":
				return []
			var parts := []
			for part in raw.split(",", false):
				parts.append(part.strip_edges())
			return _sanitize(parts)
	return null


static func _sanitize(ids: Array) -> Array:
	var out: Array = []
	for id in BUILT:
		if id in ids:
			out.append(id)
	return out


static func open_for(profile) -> Array:
	if profile == null:
		return []
	var open_all := ShiftBoard.open_seeds(profile)
	var out: Array = []
	for id in BUILT:
		if id in open_all:
			out.append(id)
		elif WORLD_VARIANT_GATES.has(id) and profile.earned(String(WORLD_VARIANT_GATES[id])):
			out.append(id)
	return out


static func debut_stat(id: String) -> String:
	return DEBUT_STAT_PREFIX + id


static func debut_needed(id: String, profile) -> bool:
	if profile == null or not (id in BUILT):
		return false
	return id in open_for(profile) and int(profile.stat(debut_stat(id))) < 1


static func consume_debuts(profile, bot_driven := false) -> Array:
	if bot_driven or profile == null or forced() != null:
		return []
	var out: Array = []
	for id in open_for(profile):
		if int(profile.stat(debut_stat(id))) < 1:
			profile.set_stat(debut_stat(id), 1.0)
			out.append(id)
	return out


static func resolve_run(profile, run_seed: int, debuts := [], bot_driven := false) -> Array:
	var override = forced()
	if override != null:
		return (override as Array).duplicate()
	if bot_driven or profile == null:
		return []
	var out: Array = []
	for id in open_for(profile):
		if id in debuts or debut_needed(id, profile):
			out.append(id)
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([run_seed, id, "shift_variant"])
		if rng.randf() < DRAW_CHANCE:
			out.append(id)
	return out


static func active_for(profile, run_seed: int, bot_driven := false) -> Array:
	return resolve_run(profile, run_seed, [], bot_driven)


static func attach_run(run, profile, debuts := [], bot_driven := false) -> Array:
	var active_ids := resolve_run(profile, int(run.run_seed) if run != null else 0, debuts, bot_driven)
	if run != null:
		run.extra.erase(OVERTIME_PAID_KEY)
		if active_ids.is_empty():
			run.extra.erase(RUN_KEY)
		else:
			run.extra[RUN_KEY] = active_ids.duplicate()
	return active_ids


static func active(run) -> Array:
	var override = forced()
	if override != null:
		return (override as Array).duplicate()
	if run == null or not ("extra" in run) or not run.extra.has(RUN_KEY):
		return []
	var raw = run.extra[RUN_KEY]
	return _sanitize(raw) if raw is Array else []


static func has(run, id: String) -> bool:
	return id in active(run)


static func look_id(run, stage: int) -> String:
	if stage == 1 and has(run, DAM_NIGHT_SHIFT):
		return NIGHT_LOOK_ID
	var world := ParkDefs.world_of(stage)
	if world == 2 and has(run, MALPAIS_MONSOON):
		return MONSOON_LOOK_ID
	if world == 3 and has(run, HIGHDRAFT_ECLIPSE):
		return ECLIPSE_LOOK_ID
	return ""


static func stage_def(def: Dictionary, run, stage: int) -> Dictionary:
	if def.is_empty():
		return def
	var world := ParkDefs.world_of(stage)
	var pack_mult := 1.0
	var interval_mult := 1.0
	var elite_mult := 1.0
	if stage == 1 and has(run, DAM_NIGHT_SHIFT):
		pack_mult *= NIGHT_PACK_SCALE
		interval_mult *= NIGHT_INTERVAL_SCALE
	if world == 2 and has(run, MALPAIS_MONSOON):
		pack_mult *= MONSOON_PACK_SCALE
		interval_mult *= MONSOON_INTERVAL_SCALE
	if world == 3 and has(run, HIGHDRAFT_ECLIPSE):
		pack_mult *= ECLIPSE_PACK_SCALE
		interval_mult *= ECLIPSE_INTERVAL_SCALE
		elite_mult *= ECLIPSE_ELITE_SCALE
	if pack_mult == 1.0 and interval_mult == 1.0 and elite_mult == 1.0:
		return def
	var out := def.duplicate(true)
	var pressure: Dictionary = out.get("pressure", {}).duplicate(true)
	pressure["pack_scale"] = float(pressure.get("pack_scale", 1.0)) * pack_mult
	pressure["interval_scale"] = float(pressure.get("interval_scale", 1.0)) * interval_mult
	if elite_mult != 1.0:
		pressure["elite_rate"] = float(pressure.get("elite_rate", 1.0)) * elite_mult
	out["pressure"] = pressure
	return out


static func wakes_warden(run, beacon_radius: float, flat_distance: float, yard_ahead := false) -> bool:
	return not yard_ahead and has(run, OVERTIME) and flat_distance <= beacon_radius * OVERTIME_WAKE_SCALE


static func on_stage_retry(run) -> void:
	if run == null or not ("extra" in run):
		return
	var paid_stage := int(run.extra.get(OVERTIME_PAID_KEY, 0))
	if paid_stage > 0 and paid_stage >= int(run.stage):
		run.extra.erase(OVERTIME_PAID_KEY)


static func claim_overtime_panel(run) -> String:
	if run == null or not has(run, OVERTIME):
		return ""
	if int(run.extra.get(OVERTIME_PAID_KEY, 0)) > 0:
		return ""
	var stage_now := int(run.stage)
	run.extra[OVERTIME_PAID_KEY] = stage_now
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(run.run_seed), stage_now, "overtime_panel"])
	return Panels.draw(rng, String(run.class_id()))


static func dam_shop_open(run, stage := -1) -> bool:
	if run == null:
		return true
	var stage_now := stage if stage > 0 else int(run.stage)
	return not (stage_now == 1 and has(run, CREW_SHORT))


static func _is_dam_stage(map_id: String, run) -> bool:
	return run != null and int(run.stage) == 1 and map_id == String(ParkDefs.of(1).get("map", ""))


static func extra_sites(map_id: String, run) -> Array:
	var out: Array = []
	if _is_dam_stage(map_id, run) and has(run, CREW_SHORT):
		out.append(CREW_SHORT_CACHE.duplicate(true))
	if run != null and ParkDefs.world_of(int(run.stage)) == 2 and has(run, MALPAIS_MONSOON) and MONSOON_CACHES.has(map_id):
		out.append(MONSOON_CACHES[map_id].duplicate(true))
	if run != null and ParkDefs.world_of(int(run.stage)) == 3 and has(run, HIGHDRAFT_ECLIPSE) and ECLIPSE_CACHES.has(map_id):
		out.append(ECLIPSE_CACHES[map_id].duplicate(true))
	return out


static func extra_cages(map_id: String, run) -> Array:
	if not _is_dam_stage(map_id, run) or not has(run, DAM_NIGHT_SHIFT):
		return []
	return [NIGHT_SHIFT_CAGE.duplicate(true)]


static func cage_salvage_scrap(quest: String) -> int:
	return NIGHT_SHIFT_CAGE_SCRAP if quest == NIGHT_SHIFT_CAGE_QUEST else 0


static func card_rows(run, stage: int) -> Array:
	var out: Array = []
	var world := ParkDefs.world_of(stage)
	for id in active(run):
		var applies: bool = id == OVERTIME \
			or (stage == 1 and (id == DAM_NIGHT_SHIFT or id == CREW_SHORT)) \
			or (world == 2 and id == MALPAIS_MONSOON) \
			or (world == 3 and id == HIGHDRAFT_ECLIPSE)
		if applies and CARD_ROWS.has(id):
			out.append(CARD_ROWS[id])
	return out


static func board_entries(profile, sitting := false) -> Array:
	var out: Array = []
	for id in BUILT:
		var seed_row: Dictionary = ShiftBoard.SEEDS.get(id, {})
		var gate := String(seed_row.get("gate", ""))
		if gate == "" or not ShiftBoard.shown(gate, profile, sitting):
			continue
		var rung := ShiftBoard.rung(gate)
		out.append({
			"id": id,
			"kind": String(seed_row.get("kind", "")),
			"gate": gate,
			"rung_name": String(rung.get("name", gate)),
			"text": String(seed_row.get("text", "")),
			"open": ShiftBoard.stamped(gate, profile),
		})
	return out
