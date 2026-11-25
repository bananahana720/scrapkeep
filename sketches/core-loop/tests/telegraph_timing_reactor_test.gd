# smoke: solo timeout=360s fixed-fps=90 (two Wardens through 40 charges and 30 strikes in one stepped game, about 3 minutes)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const T := preload("res://tests/support/t.gd")

# Telegraph timing for the reactor relic's own attacks (design-v3/LEGIBILITY.md section 2,
# "Telegraph timing"; K-UNITS wave K-F, KF2), stepped through real physics on the alpha table
# and counted in physics frames, 20 runs per attack:
#   W01 pulse      the cue (the reach ring and vent_charging) starts on the charge's tick, the
#                  pulse lands PULSE_TELEGRAPH later to one tick, and damage lands only on the
#                  pulse's tick;
#   gates_open     the dam_face sheet (warden_reactor.gd) shares the pulse's charge: the gates
#                  open PULSE_TELEGRAPH after the cue to one tick, and the sheet deals nothing;
#   W01 slag lane  (flume, meltdown) the lane's windup starts on the pulse's tick, it strikes
#                  SLAG_WARN later to one tick, and its burn lands only while a lane strikes.
# Then 30 hits in 3 s keep the camera's shake under the active row's shake_cap. The report
# prints each attack's recovery and cooldown seconds beside its charge length, and every pack
# kind's warn seconds as its script sets them (both reported, not gated).

const RUNS := 20
const AWAY := Vector3(70.0, 0.0, 70.0)
# The ball sits inside the 6 m core ring but clear of the body (2.8 m plus the ball's 1 m), so a
# pulse's lift never drops it onto the Warden; a contact would stagger it and stop the clock.
const CORE_OUT := 5.3
const LANE_OUT := 12.0
const HITS := 30
const HIT_SECONDS := 3.0

var _t := T.new("telegraph_timing_reactor_test")
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _damage: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func _frame() -> int:
	return Engine.get_physics_frames()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(_seconds(0.4))
	_game.run.set_max_hp(99999.0)
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _game.flow.warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	await _frames(2)
	await _pulse_and_sheet()
	await _slag()
	await _shake()
	_pack_warns()
	_t.check("the timing test ran its checks", _t.checks >= 9, "%d checks" % _t.checks)
	_game.free()
	quit(_t.verdict())


func _spawn(extra: Dictionary, offset: Vector3) -> Node3D:
	var base: Vector3 = _game.flow.warden.global_position if is_instance_valid(_game.flow.warden) else Vector3.ZERO
	var warden = WardenScript.new()
	_game.ctx.root.add_child(warden)
	warden.global_position = base + offset
	var spec := {"family": "reactor", "stage": 1, "plating": 90.0, "hp": 650.0, "reach": 30.0, "harpoon_anchor": true}
	spec = _combat.fleet.dress("warden", spec)
	spec.merge(extra, true)
	warden.setup(_player, _game.ctx.terrain, _game.ctx.root, Callable(_game.flow, "in_play"), 1.0, spec)
	warden.hit_player.connect(_combat._on_player_hit.bind("warden"))
	warden.hit_player.connect(func(amount: float, _push: Vector3): _damage.append([_frame(), amount]))
	return warden


# The ball's seat `out` metres from the Warden, on the heading of eight whose ground is nearest
# the Warden's own, so the rings' vertical reach holds it on the stage's slopes.
func _spot(warden: Node3D, out: float) -> Vector3:
	var floor_y: float = warden.global_position.y - warden.HALF_HEIGHT
	var best := Vector3.ZERO
	var best_gap := INF
	for i in 8:
		var at: Vector3 = warden.global_position + Vector3.RIGHT.rotated(Vector3.UP, TAU * i / 8.0) * out
		var seat: Vector3 = _game.ctx.terrain.drop_point(at.x, at.z, 1.2)
		if absf(seat.y - 1.2 - floor_y) < best_gap:
			best_gap = absf(seat.y - 1.2 - floor_y)
			best = seat
	return best


func _hold(spot: Vector3) -> void:
	var ball: Vector3 = _player.ball_position()
	if Vector2(ball.x - spot.x, ball.z - spot.z).length() > 1.5:
		_player.reset_to(spot)


func _driver(warden: Node3D):
	var driver = warden.mount_driver
	if driver == null or not driver.has_method("sheet_live"):
		return null
	return driver


# The pulse and the dam_face sheet, one charge per run: the ball sits in the core ring, so the
# pulse's damage is the one hit each run may take.
func _pulse_and_sheet() -> void:
	var warden := _spawn({}, AWAY)
	var driver = _driver(warden)
	var spot := _spot(warden, CORE_OUT)
	var vents: Array = []
	var erupted: Array = []
	_game.events.vent_charging.connect(func(_at: Vector3, _s: float): vents.append(_frame()))
	_game.events.vent_erupted.connect(func(_at: Vector3): erupted.append(_frame()))
	var runs: Array = []
	_damage.clear()
	var sheet_ticks: Array = []
	for run in RUNS:
		# Let any sheet run out, then start the next charge.
		for i in _seconds(0.2):
			_hold(spot)
			if not warden._charging:
				warden._pulse_clock = 0.0
			await physics_frame
		while driver != null and driver.sheet_live():
			_hold(spot)
			warden._pulse_clock = 0.0
			await physics_frame
		var pulses: int = warden.pulses
		var gates: int = driver.gates_opened if driver != null else 0
		warden._pulse_clock = warden.PULSE_CYCLE - warden.PULSE_TELEGRAPH
		var row := {"charge": -1, "ring": -1, "vent": -1, "pulse": -1, "gates": -1}
		vents.clear()
		erupted.clear()
		for i in _seconds(warden.PULSE_TELEGRAPH + 0.5):
			_hold(spot)
			await physics_frame
			if row["charge"] < 0 and warden._charging:
				row["charge"] = _frame()
			if row["ring"] < 0 and warden.telegraph() != null:
				row["ring"] = _frame()
			if row["pulse"] < 0 and warden.pulses > pulses:
				row["pulse"] = _frame()
				row["erupted"] = erupted[0] if not erupted.is_empty() else -1
			if row["gates"] < 0 and driver != null and driver.gates_opened > gates:
				row["gates"] = _frame()
			if row["pulse"] >= 0 and (driver == null or row["gates"] >= 0):
				break
		row["vent"] = vents[0] if not vents.is_empty() else -1
		# The sheet's life, counted while nothing else charges.
		var live := 0
		while driver != null and driver.sheet_live() and live < _seconds(10.0):
			warden._pulse_clock = 0.0
			_hold(spot)
			await physics_frame
			live += 1
		sheet_ticks.append(live)
		runs.append(row)
	var telegraph := _seconds(warden.PULSE_TELEGRAPH)
	var cue_ok := runs.all(func(r): return r["charge"] >= 0 and absi(r["ring"] - r["charge"]) <= 1 and absi(r["vent"] - r["charge"]) <= 1)
	var len_ok := runs.all(func(r): return r["pulse"] >= 0 and absi(r["pulse"] - r["charge"] - telegraph) <= 1)
	# A pulse's damage lands inside its tick, so it is matched to vent_erupted's frame, read in
	# the signal handler like the hit's; the polled frames above are one later, all alike.
	var pulse_frames := runs.map(func(r): return r.get("erupted", -1))
	var stray := _damage.filter(func(d): return not pulse_frames.has(d[0]))
	_t.check("W01 pulse: the cue starts on the charge's tick (%d runs)" % RUNS, runs.size() == RUNS and cue_ok,
		"first runs %s" % [runs.slice(0, 3)])
	_t.check("W01 pulse: the charge lasts its row, %d ticks, to one tick" % telegraph, len_ok,
		"charge lengths %s" % [runs.map(func(r): return r["pulse"] - r["charge"])])
	_t.check("W01 pulse: damage lands only on the pulse's tick", stray.is_empty() and _damage.size() == RUNS,
		"%d hits, %d outside a pulse tick" % [_damage.size(), stray.size()])
	var gates_ok := driver != null and runs.all(func(r): return r["gates"] >= 0 and absi(r["gates"] - r["charge"] - telegraph) <= 1)
	_t.check("gates_open: the sheet opens PULSE_TELEGRAPH after the cue, to one tick", gates_ok,
		"driver %s, gates after the cue %s" % [driver != null, runs.map(func(r): return r["gates"] - r["charge"] if r["gates"] >= 0 else -1)])
	_t.check("gates_open: the sheet deals no damage", driver != null and stray.is_empty(),
		"%d hits outside a pulse tick" % stray.size())
	print("[report] W01 pulse: charge %.2f s, recovery %.2f s (pulse to the next charge), cooldown %.2f s (cycle)" % [
		warden.PULSE_TELEGRAPH, warden.PULSE_CYCLE - warden.PULSE_TELEGRAPH, warden.PULSE_CYCLE])
	var lives := sheet_ticks.map(func(n): return float(n) / Engine.physics_ticks_per_second)
	print("[report] gates_open sheet: charge %.2f s (the pulse's), live %s s, cooldown %.2f s (cycle)" % [
		warden.PULSE_TELEGRAPH, lives.slice(0, 3), warden.PULSE_CYCLE])
	warden.queue_free()
	await _frames(2)


# The flume's slag lanes: windup on the pulse's tick, strike SLAG_WARN later, burn only while
# a lane strikes. The ball sits in the lane's path, outside the core ring.
func _slag() -> void:
	var warden := _spawn({"variant": "meltdown"}, AWAY + Vector3(0.0, 0.0, 60.0))
	# The lanes pour from the flume's channel (warden_reactor.gd pour_point), so the ball sits
	# LANE_OUT out from the relic on the channel's side, inside every lane's 14 m.
	var spot := _spot(warden, LANE_OUT)
	if warden.mount_driver != null and warden.mount_driver.has_method("pour_point"):
		var pour: Vector3 = warden.mount_driver.pour_point(warden) - warden.global_position
		var at: Vector3 = warden.global_position + Vector3(pour.x, 0.0, pour.z).normalized() * LANE_OUT
		spot = _game.ctx.terrain.drop_point(at.x, at.z, 1.2)
	var phases := {}
	var pulse_frames: Array = []
	_game.events.vent_erupted.connect(func(_at: Vector3): pulse_frames.append(_frame()))
	warden.attack_phase.connect(func(facts: Dictionary):
		var id := int(facts["instance"])
		if not phases.has(id):
			phases[id] = {"row": String(facts["row"])}
		phases[id][String(facts["phase"])] = _frame())
	_damage.clear()
	for run in RUNS:
		var pulses: int = warden.pulses
		warden._pulse_clock = warden.PULSE_CYCLE - warden.PULSE_TELEGRAPH
		for i in _seconds(warden.PULSE_TELEGRAPH + warden.SLAG_WARN + 0.6):
			_hold(spot)
			await physics_frame
	for i in _seconds(warden.SLAG_SECONDS + 0.5):
		_hold(spot)
		warden._pulse_clock = 0.0
		await physics_frame
	var lanes: Array = phases.values()
	var warn := _seconds(warden.SLAG_WARN)
	var cue_ok := lanes.size() == RUNS and range(RUNS).all(func(i):
		return lanes[i].has("windup") and i < pulse_frames.size() and absi(int(lanes[i]["windup"]) - int(pulse_frames[i])) <= 1)
	var len_ok := lanes.all(func(l): return l.has("strike") and absi(int(l["strike"]) - int(l["windup"]) - warn) <= 1)
	var live := func(frame: int) -> bool:
		return lanes.any(func(l): return l.has("strike") and frame >= int(l["strike"]) and frame <= int(l.get("recover", 1 << 30)))
	var stray := _damage.filter(func(d): return not live.call(int(d[0])))
	_t.check("W01 slag lane: the windup starts on the pulse's tick (%d runs)" % RUNS, cue_ok,
		"%d lanes, rows %s, windup minus pulse %s" % [lanes.size(), lanes.map(func(l): return l["row"]).slice(0, 2),
			range(mini(lanes.size(), pulse_frames.size())).map(func(i): return int(lanes[i].get("windup", -1)) - int(pulse_frames[i]))])
	_t.check("W01 slag lane: the fill lasts SLAG_WARN, %d ticks, to one tick" % warn, len_ok,
		"fills %s" % [lanes.map(func(l): return int(l.get("strike", -1)) - int(l.get("windup", 0)))])
	_t.check("W01 slag lane: burn damage lands only while a lane strikes", _damage.size() > 0 and stray.is_empty(),
		"%d hits, %d outside a strike window" % [_damage.size(), stray.size()])
	print("[report] W01 slag lane: charge %.2f s (fill), recovery %.2f s (burn after the fill), cooldown %.2f s (one lane a cycle)" % [
		warden.SLAG_WARN, warden.SLAG_SECONDS - warden.SLAG_WARN, warden.PULSE_CYCLE])
	warden.queue_free()
	await _frames(2)


# Thirty hits on the Warden in three seconds through the game's own strike path (combat.strike,
# enemy_struck, juice): the camera's shake never passes the active row's cap, and it does shake
# (so the check can fail).
func _shake() -> void:
	var warden := _spawn({"posture": {"ram_shatters": false}}, AWAY)
	_game.ctx.calm = false
	_combat.heft_override = 1.0
	var force := 1.0
	while _combat.punch_of("ram", force) < float(warden.plating):
		force += 0.05
	var cam = _game.camera
	var gap := _seconds(HIT_SECONDS) / HITS
	var peak := 0.0
	var worst := -INF
	var rows: Array = []
	for i in _seconds(HIT_SECONDS) + gap:
		if not is_instance_valid(warden):
			break
		warden._pulse_clock = 0.0
		if i % gap == 0 and i / gap < HITS:
			_combat.strike(warden, "ram", force)
		await physics_frame
		var cap := 1.2
		for row in cam.active_profiles():
			cap = minf(cap, float(ChaseCamera.PROFILES[row]["shake_cap"]))
			if not rows.has(row):
				rows.append(row)
		peak = maxf(peak, cam.shake_amplitude())
		worst = maxf(worst, cam.shake_amplitude() - cap)
	_game.ctx.calm = true
	var alive := is_instance_valid(warden)
	_t.check("30 hits in 3 s keep shake under the camera row's cap", alive and peak > 0.0 and worst <= 0.0001,
		"Warden standing %s, peak %.3f, worst over the cap %+.3f, rows seen %s" % [alive, peak, worst, rows])
	if alive:
		warden.queue_free()
	await _frames(2)


# Every pack kind's warn seconds as its script sets them (reported, not gated): a counter's
# warn_seconds assignment, else the script's WINDUP or WARN constant.
func _pack_warns() -> void:
	var assign := RegEx.create_from_string("\\n\\s*warn_seconds\\s*=\\s*([A-Za-z0-9_.]+)")
	var rows: Array = []
	for file in DirAccess.get_files_at("res://src/combat"):
		if not file.ends_with(".gd"):
			continue
		var path := "res://src/combat/" + file
		var script = load(path)
		if not script is GDScript:
			continue
		var consts: Dictionary = (script as GDScript).get_script_constant_map()
		var found := assign.search(FileAccess.get_file_as_string(path))
		var value = null
		if found != null:
			var expr := found.get_string(1)
			value = float(expr) if expr.is_valid_float() else consts.get(expr)
		elif consts.has("WINDUP") and (consts["WINDUP"] is float or consts["WINDUP"] is int):
			value = consts["WINDUP"]
		elif consts.has("WARN") and (consts["WARN"] is float or consts["WARN"] is int):
			value = consts["WARN"]
		if value != null:
			rows.append("%s %.2f" % [file.get_basename(), float(value)])
	print("[report] pack warn seconds as set (%d kinds): %s" % [rows.size(), ", ".join(rows)])
