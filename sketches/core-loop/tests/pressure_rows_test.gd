extends SceneTree

const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Director := preload("res://src/world/director.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# GP3: the run's pressure curve. One PRESSURE row per alpha stage, pack density and elite rate
# climbing every stage, every key a multiplier in [0.5, 2.0]; each stage row carries its own
# pressure row and reads its Warden posture curve from it. The director multiplies its own
# constants by the row and by the Breath option's row: hard is steeper, raw and gentle are
# normal (every multiplier 1.0).

var _t := T.new("pressure_rows_test")


func _initialize() -> void:
	_rows()
	_director()
	_breath()
	_elites()
	quit(_t.verdict())


func _rows() -> void:
	var rows: Array = AlphaDefs.PRESSURE
	_t.eq("one pressure row per stage", rows.size(), AlphaDefs.COUNT)
	_t.eq("six pressure rows", rows.size(), 6)
	for i in rows.size():
		var row: Dictionary = rows[i]
		for key in Director.PRESSURE_KEYS:
			var v := float(row.get(key, -1.0))
			_t.check("stage %d %s in [0.5, 2.0]" % [i + 1, key], v >= 0.5 and v <= 2.0, "%s" % v)
		var def: Dictionary = AlphaDefs.of(i + 1)
		_t.check("stage %d row carries its pressure row" % (i + 1), def.get("pressure", {}) == row)
		_t.near("stage %d Warden curve reads posture_curve" % (i + 1), float(def["posture"]["curve"]),
			AlphaDefs.POSTURE_CURVE * float(row["posture_curve"]))
	for key in ["pack_scale", "elite_rate"]:
		var climbs := true
		for i in range(1, rows.size()):
			climbs = climbs and float(rows[i][key]) > float(rows[i - 1][key])
		_t.check("%s climbs every stage" % key, climbs, "%s" % [rows.map(func(r): return r[key])])
	# The crown's row is the top: the most of every key, and the shortest interval.
	for key in Director.PRESSURE_KEYS:
		var top := true
		var sign := -1.0 if key == "interval_scale" else 1.0
		for row in rows:
			top = top and sign * float(rows[-1][key]) >= sign * float(row[key])
		_t.check("the crown's %s is the top" % key, top)


func _at(stage: int, breath: String) -> Director:
	var d := Director.new(7)
	d.threat = 1.0
	d.use_row(AlphaDefs.of(stage), breath)
	return d


func _director() -> void:
	var first := _at(1, "raw")
	var last := _at(6, "raw")
	_t.check("stage 6 spawns sooner than stage 1", last.interval() < first.interval(),
		"%.3f vs %.3f s" % [last.interval(), first.interval()])
	_t.check("stage 6 crowds more than stage 1", last.cap() > first.cap(), "%d vs %d" % [last.cap(), first.cap()])
	var bare := Director.new(7)
	bare.threat = 1.0
	_t.near("stage 1 multiplies the base interval", first.interval(),
		bare.interval() * float(AlphaDefs.PRESSURE[0]["interval_scale"]))
	last.stage_time = Director.TIER_SECONDS * 2
	last.spike = true
	_t.check("PACK_MAX stays the pack-share ceiling", last.reinforcement_weight() <= Director.PACK_MAX,
		"%.3f" % last.reinforcement_weight())
	var cleared := _at(6, "hard")
	cleared.use_row({})
	_t.near("an empty row clears the pressure", cleared.interval(), bare.interval())


func _breath() -> void:
	_t.check("Breath options keep their names", Director.BREATH.keys().all(func(k): return k in ["raw", "hard", "gentle"])
		and Tuning.new().options_of(Tuning.BREATH_KEY).all(func(k): return Director.BREATH.has(k)))
	for normal in ["raw", "gentle"]:
		var d := Director.new(7)
		d.use_row({}, normal)
		for key in Director.PRESSURE_KEYS:
			_t.near("Breath %s: %s is 1.0" % [normal, key], d.scale(key), 1.0)
	for stage in [1, 6]:
		var hard := _at(stage, "hard")
		var normal := _at(stage, "raw")
		_t.check("stage %d: Breath hard spawns sooner than normal" % stage, hard.interval() < normal.interval(),
			"%.3f vs %.3f s" % [hard.interval(), normal.interval()])
		_t.check("stage %d: Breath hard crowds at least as much" % stage, hard.cap() >= normal.cap(),
			"%d vs %d" % [hard.cap(), normal.cap()])
	_t.near("Breath hard: pack_scale 1.25", Director.BREATH["hard"]["pack_scale"], 1.25)
	_t.near("Breath hard: elite_rate 1.25", Director.BREATH["hard"]["elite_rate"], 1.25)
	_t.near("Breath hard: interval_scale 0.85", Director.BREATH["hard"]["interval_scale"], 0.85)


# Past the scheduled elite, a later arrival is the elite again at the stage's elite rate, never
# twice in a row: the crown sees more elites than the Spillway.
func _count_elites(stage: int) -> Dictionary:
	var d := _at(stage, "raw")
	var def := AlphaDefs.of(stage)
	d.authored = def["packs"]
	d.elite = def["elite"]
	d.elite_arrival = AlphaDefs.ELITE_ARRIVAL
	var elites := 0
	var twice := false
	for i in 2000:
		var p: Dictionary = d._draw_authored()
		var is_elite: bool = p == d.elite
		twice = twice or (is_elite and d._last_was_elite)
		if is_elite:
			elites += 1
		d._last_was_elite = is_elite
		if not is_elite:
			d._last_pack_id = p["id"]
		d._arrivals_made += 1
	return {"elites": elites, "twice": twice}


func _elites() -> void:
	var first := _count_elites(1)
	var last := _count_elites(6)
	_t.check("the crown draws more elites than the Spillway", int(last["elites"]) > int(first["elites"]),
		"%d vs %d of 2000" % [last["elites"], first["elites"]])
	_t.check("never two elites in a row", not first["twice"] and not last["twice"])
	_t.check("the scheduled elite still comes", int(first["elites"]) >= 1)
