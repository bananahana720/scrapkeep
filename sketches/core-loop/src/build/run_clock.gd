extends RefCounted

# The run clock and the difficulty clock, as data the HUD draws (DESIGN-V2 section 7,
# PROGRESSION section 1). W1 draws; build publishes record(). The difficulty clock is
# the Risk of Rain pressure: it fills per stage on the director's schedule, pauses in
# Moss's bay (the calm is real) and never gates anything. The par timer keeps running
# in the bay, so a speedrunner can skip the calm at a cost.
#
# The par ghost is the player's best Warden break for this stage, read from the run
# log's own records (runs.ndjson), so it needs no new save file.

# The director's schedule (world/director.gd TIER_SECONDS and MAX_TIME_TIERS). Build
# may not load world's files; build_clock_test fails if these two drift from it.
const DIFFICULTY_TICK := 45.0
const DIFFICULTY_TIERS := 2
const SCRAPLESS := "scrapless"
const PAR := "par"
const MODIFIERS := [SCRAPLESS, PAR]
# Not chosen at the start: a run turns cursed when it takes a curse pocket's deal. Build keeps
# the flag in step with RunState.cursed(), and tags() lists it so the music can follow it.
const CURSE := "curse"

var run_seconds := 0.0
var stage_seconds := 0.0
var difficulty_seconds := 0.0
var paused := false
var stage := 1
var modifiers := {}
var cursed := false
# Stage number (as a String, the JSON key) to the best Warden-break seconds on record.
var best := {}
var broke_at := -1.0


func begin_run(chosen: Dictionary) -> void:
	modifiers = {}
	cursed = false
	for key in MODIFIERS:
		if chosen.get(key, false):
			modifiers[key] = true
	run_seconds = 0.0
	enter_stage(1)


func enter_stage(index: int) -> void:
	stage = index
	stage_seconds = 0.0
	difficulty_seconds = 0.0
	broke_at = -1.0
	paused = false


func advance(delta: float, run_time: float, in_stage: bool) -> void:
	run_seconds = run_time
	if not in_stage:
		return
	stage_seconds += delta
	if not paused:
		difficulty_seconds += delta


func warden_broken() -> void:
	if broke_at < 0.0:
		broke_at = stage_seconds


func tags() -> Array:
	var out: Array = []
	for key in MODIFIERS:
		if modifiers.has(key):
			out.append(key)
	if cursed:
		out.append(CURSE)
	return out


func on(modifier: String) -> bool:
	return modifiers.has(modifier)


# The filling bar: 0 at a stage's start, 1 at the last tier.
func difficulty_fraction() -> float:
	return clampf(difficulty_seconds / (DIFFICULTY_TICK * DIFFICULTY_TIERS), 0.0, 1.0)


func difficulty_tier() -> int:
	return mini(int(difficulty_seconds / DIFFICULTY_TICK), DIFFICULTY_TIERS)


# W1's clock record. par.split is negative while ahead of the ghost; it freezes at the
# Warden break. par.on is true with the par modifier or the Par Chip.
func record(par_chip := false) -> Dictionary:
	var ghost = best.get(str(stage))
	var showing := on(PAR) or par_chip
	var at := broke_at if broke_at >= 0.0 else stage_seconds
	return {
		"run_seconds": run_seconds,
		"stage_seconds": stage_seconds,
		"difficulty": {"fraction": difficulty_fraction(), "tier": difficulty_tier(), "tiers": DIFFICULTY_TIERS,
			"paused": paused, "icon": "res_difficulty"},
		"timer_icon": "res_timer",
		"par": {"on": showing, "best": ghost, "split": at - float(ghost) if showing and ghost != null else null,
			"broken": broke_at >= 0.0},
		"tags": tags(),
	}


# Best Warden-break seconds per stage from the run log's lines. Unreadable lines are
# skipped; a missing file means no ghost yet.
func load_best(path: String, ticks_per_second: float) -> void:
	best = {}
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	while not file.eof_reached():
		var text := file.get_line().strip_edges()
		if text == "" or json.parse(text) != OK or not json.data is Dictionary:
			continue
		var parsed: Dictionary = json.data
		for row in parsed.get("stages", []):
			if not row is Dictionary or row.get("ticks_to_warden_break") == null:
				continue
			var key := str(int(row.get("stage", 0)))
			var seconds := float(row["ticks_to_warden_break"]) / ticks_per_second
			if not best.has(key) or seconds < best[key]:
				best[key] = seconds
	file.close()
