extends RefCounted

# Shift variants (W46-08, design-v3/WORLD1-DEMO-CATALYST.md): run modifiers and stage variants
# opened by stamping rungs on the shift board (shift_board.gd SEEDS). This module is the one
# owner of which built variants are open, which ones play on a run, and what each active variant
# changes. Callers ask here and never reach into ShiftBoard.SEEDS or run.extra themselves.
#
# Only built variants are listed in BUILT. An unbuilt seed (flume_backwash) stays off the board
# and never plays (Andrew, 12 Nov 2026, card on W1-72).
#
# No variant grants a lasting stat buff or scales enemy health (ruling al). Every effect ends
# with the run and presses a slow or careless ball rather than stopping a rolling one (ruling cu).

const ShiftBoard := preload("res://src/core/shift_board.gd")
const Panels := preload("res://src/build/panels.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

const OVERTIME := "overtime"
const DAM_NIGHT_SHIFT := "dam_night_shift"
const CREW_SHORT := "crew_short"

# Built variants in board rung order (first_warden, brindle_routed, mark_sable).
const BUILT := [OVERTIME, DAM_NIGHT_SHIFT, CREW_SHORT]

# Keys inside RunState.extra (omitted when unused so unstamped runs keep byte-identical docs).
const RUN_KEY := "shift_variants"
const OVERTIME_PAID_KEY := "overtime_panel_stage"

# Profile stat prefix recording that an opened variant has played its guaranteed debut run.
const DEBUT_STAT_PREFIX := "shift.variant_seen."

# Per-variant seeded draw chance on runs after the variant's debut.
const DRAW_CHANCE := 0.35

# Dam Night Shift: look id for W46-13's lighting/props pass, fuller dam crew via pressure
# scaling only (pack_scale up, interval_scale down; never threat or enemy health, ruling al),
# and one extra salvage cage on the open west domes shelf (outside the yard-lock rings, off
# every ride line and clear of all PocketDraw anchors). Freeing it pays a scrap burst the same
# size as an ordinary standing salvage activity (no pilot unlock, no lasting stat, no panel).
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

# Overtime: Wardens wake one beat early (at OVERTIME_WAKE_SCALE x beacon radius, ahead of the
# ring) and breaking a Warden bolts on one extra grey panel per run, banked once.
const OVERTIME_WAKE_SCALE := 2.0

# Short Crew: no dam shop on stage 1, and one extra cracked cache on the dam's east toe apron
# clear of the kicker, training wall, gate slots, beacon and every surplus PocketDraw anchor.
const CREW_SHORT_CACHE := {
	"id": "cracked_cache",
	"row": "crew_short_cache",
	"site": "toe_apron",
	"at": Vector2(36.0, 460.0),
	"face": Vector2(-1.0, -1.0),
	"pay": {"rarities": ["rare"]},
}

# Stage-card lines shown beside the Foreman's memo when a variant applies to the stage.
const CARD_ROWS := {
	DAM_NIGHT_SHIFT: {"id": DAM_NIGHT_SHIFT, "word": "Night Shift", "line": "Floodlights on, fuller crew, one more cage."},
	OVERTIME: {"id": OVERTIME, "word": "Overtime", "line": "Wardens wake early and pay a panel."},
	CREW_SHORT: {"id": CREW_SHORT, "word": "Short Crew", "line": "No dam shop. Cache on the apron."},
}

# Test and still-capture force seam: null means normal profile/run resolution; an Array forces
# that exact built-variant set without touching tuning.gd.
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


# Built variant ids opened on `profile` by stamping their ShiftBoard rung.
static func open_for(profile) -> Array:
	if profile == null:
		return []
	var open_all := ShiftBoard.open_seeds(profile)
	var out: Array = []
	for id in BUILT:
		if id in open_all:
			out.append(id)
	return out


static func debut_stat(id: String) -> String:
	return DEBUT_STAT_PREFIX + id


static func debut_needed(id: String, profile) -> bool:
	if profile == null or not (id in BUILT):
		return false
	return id in open_for(profile) and int(profile.stat(debut_stat(id))) < 1


# Marks every newly-opened built variant as seen on `profile` and returns those ids so the run
# that calls this plays them on its first shift. Mutates nothing for bots, null profiles, or
# forced runs. Call before flow's existing profile save at run start so no extra save is added.
static func consume_debuts(profile, bot_driven := false) -> Array:
	if bot_driven or profile == null or forced() != null:
		return []
	var out: Array = []
	for id in open_for(profile):
		if int(profile.stat(debut_stat(id))) < 1:
			profile.set_stat(debut_stat(id), 1.0)
			out.append(id)
	return out


# Pure read of which built variants play for `profile` and `run_seed`. Any id in `debuts` (or
# still waiting for its debut on `profile`) is guaranteed; other open ids roll independently on
# their own stream so shared RNG is never touched.
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


# Resolves and records the run's active variants in `run.extra` only when non-empty, leaving
# fresh profiles and unstamped runs with byte-identical entrance documents.
static func attach_run(run, profile, debuts := [], bot_driven := false) -> Array:
	var active_ids := resolve_run(profile, int(run.run_seed) if run != null else 0, debuts, bot_driven)
	if run != null:
		run.extra.erase(OVERTIME_PAID_KEY)
		if active_ids.is_empty():
			run.extra.erase(RUN_KEY)
		else:
			run.extra[RUN_KEY] = active_ids.duplicate()
	return active_ids


# The variants active on a live or resumed `run` (force override wins for tests and stills).
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


# Stage look id for W46-13's visual pass; "" when the stage uses its default look.
static func look_id(run, stage: int) -> String:
	if stage == 1 and has(run, DAM_NIGHT_SHIFT):
		return NIGHT_LOOK_ID
	return ""


# Returns `def` unchanged unless Night Shift is active on stage 1, in which case only the stage's
# pressure cadence scales (more enemies per pack, shorter interval; never threat or health).
static func stage_def(def: Dictionary, run, stage: int) -> Dictionary:
	if stage != 1 or not has(run, DAM_NIGHT_SHIFT) or def.is_empty():
		return def
	var out := def.duplicate(true)
	var pressure: Dictionary = out.get("pressure", {}).duplicate(true)
	pressure["pack_scale"] = float(pressure.get("pack_scale", 1.0)) * NIGHT_PACK_SCALE
	pressure["interval_scale"] = float(pressure.get("interval_scale", 1.0)) * NIGHT_INTERVAL_SCALE
	out["pressure"] = pressure
	return out


# True when Overtime wakes the stage's sealed Warden ahead of the beacon ring.
# Waits while a stage yard lock is armed or shut so approaching the yard never opens it early
# or forfeits the yard's panel and bell.
static func wakes_warden(run, beacon_radius: float, flat_distance: float, yard_ahead := false) -> bool:
	return not yard_ahead and has(run, OVERTIME) and flat_distance <= beacon_radius * OVERTIME_WAKE_SCALE


# Rewinds an Overtime panel claim made on or after the stage being retried, because run.restore()
# rewinds run.panels back to stage entry. Claims banked on earlier stages stay intact.
static func on_stage_retry(run) -> void:
	if run == null or not ("extra" in run):
		return
	var paid_stage := int(run.extra.get(OVERTIME_PAID_KEY, 0))
	if paid_stage > 0 and paid_stage >= int(run.stage):
		run.extra.erase(OVERTIME_PAID_KEY)


# Claims Overtime's extra grey panel on a Warden break: at most one panel per run, banked once
# across stages and Continue (retry_stage calls on_stage_retry after run.restore() so a retried
# stage can still pay on this stage or a later one without ever paying twice in one run). Drawn
# on its own stream so shared and panel-drop RNG never drift.
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


# False on stage 1 when Short Crew closes the dam shop; true everywhere else.
static func dam_shop_open(run, stage := -1) -> bool:
	if run == null:
		return true
	var stage_now := stage if stage > 0 else int(run.stage)
	return not (stage_now == 1 and has(run, CREW_SHORT))


static func _is_dam_stage(map_id: String, run) -> bool:
	return run != null and int(run.stage) == 1 and map_id == String(ParkDefs.of(1).get("map", ""))


# Extra standing activity sites added by active variants on `map_id` for `run`.
static func extra_sites(map_id: String, run) -> Array:
	if not _is_dam_stage(map_id, run) or not has(run, CREW_SHORT):
		return []
	return [CREW_SHORT_CACHE.duplicate(true)]


# Extra rescue cages built by active variants on `map_id` for `run`.
static func extra_cages(map_id: String, run) -> Array:
	if not _is_dam_stage(map_id, run) or not has(run, DAM_NIGHT_SHIFT):
		return []
	return [NIGHT_SHIFT_CAGE.duplicate(true)]


# Scrap burst paid when freeing a variant salvage cage; 0 for ordinary pilot cages.
static func cage_salvage_scrap(quest: String) -> int:
	return NIGHT_SHIFT_CAGE_SCRAP if quest == NIGHT_SHIFT_CAGE_QUEST else 0


# Stage-card caption rows for active variants that apply to `stage`.
static func card_rows(run, stage: int) -> Array:
	var out: Array = []
	for id in active(run):
		if id == OVERTIME or stage == 1:
			if CARD_ROWS.has(id):
				out.append(CARD_ROWS[id])
	return out


# Built variant rows for the Shift Board UI, each paired with the rung that opens it.
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
