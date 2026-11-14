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
# A quick break (W1-62, overpowered pays): a Warden broken within this many seconds of its
# engagement adds one part roll to its gate, so a grown ball's fast break is worth a choice, not
# only time. One entry per run stage; 0 means the stage has no quick break. World 1's dam takes
# four rams at a 6 s pulse from an ordinary ball and three from a grown one; on the flume a
# five-seed read of the harder stack (PR 845) had grown balls at a 19 s median and small ones at
# 30 s. Worlds 2 and 3 are parked, so their stages pay nothing until they are fitted.
const QUICK_BREAK_SECONDS := [30.0, 20.0, 0.0, 0.0, 0.0, 0.0]

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
# Stage seconds when this attempt's Warden fight began, or -1.
var engaged_at := -1.0


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
	engaged_at = -1.0
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


# Each attempt's engagement restarts the fight's count; the break keeps the first.
func warden_engaged() -> void:
	if broke_at < 0.0:
		engaged_at = stage_seconds


# Seconds from the Warden's engagement to its break, or -1 before both.
func fight_seconds() -> float:
	return broke_at - engaged_at if broke_at >= 0.0 and engaged_at >= 0.0 else -1.0


# True when this stage's Warden fell within its quick-break limit.
func quick_break() -> bool:
	var limit: float = QUICK_BREAK_SECONDS[stage - 1] if stage >= 1 and stage <= QUICK_BREAK_SECONDS.size() else 0.0
	var fight := fight_seconds()
	return limit > 0.0 and fight >= 0.0 and fight <= limit


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
