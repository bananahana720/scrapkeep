extends RefCounted


const DIFFICULTY_TICK := 45.0
const DIFFICULTY_TIERS := 2
const SCRAPLESS := "scrapless"
const PAR := "par"
const MODIFIERS := [SCRAPLESS, PAR]
const CURSE := "curse"
const QUICK_BREAK_SECONDS := [30.0, 20.0, 28.0, 24.0, 26.0, 22.0]

var run_seconds := 0.0
var stage_seconds := 0.0
var difficulty_seconds := 0.0
var paused := false
var stage := 1
var modifiers := {}
var cursed := false
var best := {}
var broke_at := -1.0
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


func warden_engaged() -> void:
	if broke_at < 0.0:
		engaged_at = stage_seconds


func fight_seconds() -> float:
	return broke_at - engaged_at if broke_at >= 0.0 and engaged_at >= 0.0 else -1.0


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


func tiers() -> int:
	return maxi(0, roundi(ChallengeDials.by_stage_or("mobs.clock_tiers_by_stage", stage, DIFFICULTY_TIERS)))


func difficulty_fraction() -> float:
	var last := tiers()
	return clampf(difficulty_seconds / (DIFFICULTY_TICK * last), 0.0, 1.0) if last > 0 else 1.0


func difficulty_tier() -> int:
	return mini(int(difficulty_seconds / DIFFICULTY_TICK), tiers())


func record(par_chip := false) -> Dictionary:
	var ghost = best.get(str(stage))
	var showing := on(PAR) or par_chip
	var at := broke_at if broke_at >= 0.0 else stage_seconds
	return {
		"run_seconds": run_seconds,
		"stage_seconds": stage_seconds,
		"difficulty": {"fraction": difficulty_fraction(), "tier": difficulty_tier(), "tiers": tiers(),
			"paused": paused, "icon": "res_difficulty"},
		"timer_icon": "res_timer",
		"par": {"on": showing, "best": ghost, "split": at - float(ghost) if showing and ghost != null else null,
			"broken": broke_at >= 0.0},
		"tags": tags(),
	}


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
