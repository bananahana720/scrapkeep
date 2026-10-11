extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const T := preload("res://tests/support/t.gd")

# KF2, the reactor relic's mountings (design-v3/wardens/reactor.md sections 3 and 4), in a
# stepped headless fight on the alpha table's stage 1, counted in physics frames. A park-style
# reactor Warden (spec "harpoon_anchor": true) loads src/combat/warden_reactor.gd as its driver.
# dam_face: every pulse opens the gates and a water sheet lives SHEET_SECONDS, dying with the
# next charge at the latest; a ball entering it at cruise toward the relic reaches the core's
# height with its planar speed within 5 percent of its entry and publishes ride_sheet; a ball
# that misses it loses no speed against the same run with the sheet dry. flume (meltdown):
# every lane starts at the pour channel, slag_hop still fires over a burning lane, and the
# core window is MELTDOWN_WINDOW times the posture rule's stagger. The relic never moves on
# either mounting: mount_offset is zero and anchor_velocity stays zero on every tick.

const DRIVER_PATH := "res://src/combat/warden_reactor.gd"
const AWAY := Vector3(70.0, 0.0, 70.0)
const BALL_OUT := Vector3(10.0, 1.2, 0.0)
# The sheet's three numbers in the kind sheet (section 3.1): 3 s, 24 m wide.
const SHEET_SECONDS := 3.0
const SHEET_WIDTH := 24.0
const KEPT := 0.05
const MISS_SAME := 0.01
# The meltdown numbers this unit must not change (warden.gd, the W01 slag lane).
const SLAG := {"SLAG_LENGTH": 14.0, "SLAG_WIDTH": 4.0, "SLAG_SECONDS": 6.0, "SLAG_WARN": 1.0, "SLAG_DAMAGE": 4.0, "MELTDOWN_WINDOW": 1.5}

var _t := T.new("warden_reactor_test")
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _facts: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


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
	_combat.heft_override = 1.0
	_game.events.world_fact.connect(func(kind: String, at: Vector3): _facts.append([kind, at, Engine.get_physics_frames()]))
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _game.flow.warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	await _frames(2)
	await _dam_face()
	await _flume()
	_t.check("the reactor test ran its checks", _t.checks >= 16, "%d checks" % _t.checks)
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
	return warden


func _ground(at: Vector3, up := 1.2) -> Vector3:
	return _game.ctx.terrain.drop_point(at.x, at.z, up)


func _driver(warden: Node3D):
	var driver = warden.mount_driver
	if driver == null or driver.get_script() == null or driver.get_script().resource_path != DRIVER_PATH:
		return null
	return driver


func _planar(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _velocity() -> Vector3:
	return _player.body().linear_velocity


# Hold the pulse clock at zero while no charge runs, so a long run sees no new charge.
func _quiet(warden: Node3D) -> void:
	if not warden._charging:
		warden._pulse_clock = 0.0


# Start a charge on the next tick and wait for its pulse; true when it came.
func _pulse_now(warden: Node3D) -> bool:
	var before: int = warden.pulses
	warden._pulse_clock = warden.PULSE_CYCLE - warden.PULSE_TELEGRAPH
	for i in _seconds(warden.PULSE_TELEGRAPH + 0.5):
		_player.reset_to(_ground(warden.global_position + BALL_OUT))
		await physics_frame
		if warden.pulses > before:
			return true
	return false


# --- dam_face ----------------------------------------------------------------------------

func _dam_face() -> void:
	var warden := _spawn({}, AWAY)
	var driver = _driver(warden)
	_t.check("dam_face: a park reactor Warden loads warden_reactor.gd", driver != null and warden.mounting == "dam_face"
			and warden.variant == "", "driver %s, mounting '%s', variant '%s'" % [warden.mount_driver, warden.mounting, warden.variant])
	if driver == null:
		warden.queue_free()
		await _frames(2)
		return
	await _cycles(warden, driver)
	await _sheet_dies_with_charge(warden, driver)
	await _ride(warden, driver)
	await _miss(warden, driver)
	warden.queue_free()
	await _frames(2)


# Three natural cycles: the gates open on the pulse's own tick, the sheet lives SHEET_SECONDS
# (to one tick) and is never live when a charge starts; the relic stands at home throughout.
func _cycles(warden: Node3D, driver) -> void:
	var spot := _ground(warden.global_position + BALL_OUT)
	_player.reset_to(spot)
	var home: Vector3 = warden.home
	var pulses_seen := 0
	var gate_on_pulse := 0
	var lives: Array = []
	var live_ticks := -1
	var live_at_charge := 0
	var was_charging := false
	var moved := 0.0
	var carried := 0.0
	var gates_before: int = driver.gates_opened
	var pulses_before: int = warden.pulses
	for i in _seconds(3.0 * warden.PULSE_CYCLE + 0.5):
		if _player.ball_position().distance_to(spot) > 3.0 and not warden._charging:
			_player.reset_to(spot)
		var pulses: int = warden.pulses
		var gates: int = driver.gates_opened
		await physics_frame
		moved = maxf(moved, warden.global_position.distance_to(home))
		carried = maxf(carried, warden.anchor_velocity().length())
		if warden.pulses > pulses:
			pulses_seen += 1
			if driver.gates_opened == gates + 1:
				gate_on_pulse += 1
			if live_ticks > 0:
				lives.append(live_ticks)
			live_ticks = 0
		if live_ticks >= 0 and driver.sheet_live():
			live_ticks += 1
		elif live_ticks > 0:
			lives.append(live_ticks)
			live_ticks = -1
		if warden._charging and not was_charging and driver.sheet_live():
			live_at_charge += 1
		was_charging = warden._charging
	var want := _seconds(SHEET_SECONDS)
	_t.check("dam_face: the gates open on every pulse's tick", pulses_seen >= 3 and gate_on_pulse == pulses_seen
			and driver.gates_opened - gates_before == warden.pulses - pulses_before,
		"pulses %d, gates opened on the pulse tick %d, gates %d" % [pulses_seen, gate_on_pulse, driver.gates_opened - gates_before])
	_t.check("dam_face: each sheet lives %.1f s to one tick" % SHEET_SECONDS, lives.size() >= 3
			and lives.all(func(n): return absi(int(n) - want) <= 1),
		"sheet lives %s ticks, want %d" % [lives, want])
	_t.eq("dam_face: no charge starts while a sheet runs", live_at_charge, 0)
	_t.check("dam_face: the relic never moves", moved == 0.0 and carried == 0.0
			and driver.mount_offset(warden, 0.0) == Vector3.ZERO and driver.mount_offset(warden, 17.3) == Vector3.ZERO,
		"moved %.4f m from home, anchor speed %.4f m/s" % [moved, carried])


# A charge that comes while the sheet still runs ends it on the charge's tick.
func _sheet_dies_with_charge(warden: Node3D, driver) -> void:
	var pulsed := await _pulse_now(warden)
	var live_after: bool = driver.sheet_live()
	warden._pulse_clock = warden.PULSE_CYCLE - warden.PULSE_TELEGRAPH
	var dead_on_charge := false
	for i in 4:
		await physics_frame
		if warden._charging:
			dead_on_charge = not driver.sheet_live()
			break
	_t.check("dam_face: the next charge ends a running sheet", pulsed and live_after and dead_on_charge,
		"pulsed %s, live after the pulse %s, dead on the charge's tick %s" % [pulsed, live_after, dead_on_charge])
	for i in _seconds(warden.PULSE_TELEGRAPH + 0.2):
		await physics_frame


# Enter the sheet's foot at cruise toward the relic: the ball rides to the core's height and
# keeps its planar speed; the ride publishes ride_sheet.
func _ride(warden: Node3D, driver) -> void:
	var cruise: float = _player.tuning.f("cruise")
	if not await _pulse_now(warden):
		_t.check("dam_face: a sheet for the ride", false, "no pulse")
		return
	var dir: Vector3 = driver.sheet_dir
	var foot := _ground(warden.global_position + dir * (driver.SHEET_RUN - 3.0), 1.05)
	var core_y: float = warden.family_point_at().y
	_facts.clear()
	_player.reset_to(foot, -dir * cruise)
	var entry := -1.0
	var at_core := -1.0
	var top := -INF
	for i in _seconds(SHEET_SECONDS - 0.2):
		_quiet(warden)
		await physics_frame
		var ball: Vector3 = _player.ball_position()
		top = maxf(top, ball.y)
		if entry < 0.0 and driver.in_sheet(warden, ball):
			entry = _planar(_velocity())
		if entry > 0.0 and ball.y >= core_y:
			at_core = _planar(_velocity())
			break
	var kept := entry > 0.0 and at_core > 0.0 and absf(at_core - entry) <= KEPT * entry
	_t.check("dam_face: the sheet carries a cruising ball to the core's height", entry >= 0.9 * cruise and at_core > 0.0,
		"cruise %.1f m/s, entry %.2f m/s, highest %.2f m, core at %.2f m" % [cruise, entry, top, core_y])
	_t.check("dam_face: planar speed kept within 5 percent", kept,
		"entry %.2f m/s, at the core's height %.2f m/s" % [entry, at_core])
	var rides := _facts.filter(func(f): return f[0] == "ride_sheet")
	_t.check("dam_face: the ride publishes ride_sheet", rides.size() >= 1, "facts %s" % [_facts.map(func(f): return f[0])])
	for i in _seconds(SHEET_SECONDS):
		_quiet(warden)
		await physics_frame


# The same roll past the sheet's edge, once with the sheet live and once dry: same speed, no
# ride, never inside the sheet.
func _miss(warden: Node3D, driver) -> void:
	var cruise: float = _player.tuning.f("cruise")
	var live := await _roll_past(warden, driver, true, cruise)
	var dry := await _roll_past(warden, driver, false, cruise)
	var same: bool = live["speed"] > 0.0 and dry["speed"] > 0.0 and absf(live["speed"] - dry["speed"]) <= MISS_SAME * dry["speed"]
	_t.check("dam_face: a ball that misses the sheet loses no speed", live["sheet"] and not dry["sheet"] and same
			and not live["inside"] and live["rides"] == 0,
		"live sheet %s: %.3f m/s, dry: %.3f m/s, ever inside %s, rides %d" % [live["sheet"], live["speed"], dry["speed"],
			live["inside"], live["rides"]])


func _roll_past(warden: Node3D, driver, sheet: bool, cruise: float) -> Dictionary:
	if sheet:
		await _pulse_now(warden)
	else:
		for i in _seconds(SHEET_SECONDS + 0.5):
			_quiet(warden)
			await physics_frame
	var dir: Vector3 = driver.sheet_dir
	var lateral := dir.cross(Vector3.UP).normalized()
	var start := _ground(warden.global_position + dir * (driver.SHEET_RUN - 3.0) + lateral * (SHEET_WIDTH * 0.5 + 6.0), 1.05)
	_facts.clear()
	_player.reset_to(start, -dir * cruise)
	var inside := false
	var on: bool = driver.sheet_live()
	for i in _seconds(1.5):
		_quiet(warden)
		await physics_frame
		inside = inside or driver.in_sheet(warden, _player.ball_position())
	return {"speed": _planar(_velocity()), "inside": inside, "sheet": on,
		"rides": _facts.filter(func(f): return f[0] == "ride_sheet").size()}


# --- flume (meltdown) --------------------------------------------------------------------

func _flume() -> void:
	var warden := _spawn({"variant": "meltdown"}, AWAY + Vector3(0.0, 0.0, 60.0))
	var driver = _driver(warden)
	_t.check("flume: the meltdown Warden fights from the flume with the reactor driver", driver != null
			and warden.mounting == "flume" and warden.variant == "meltdown",
		"driver %s, mounting '%s', variant '%s'" % [warden.mount_driver, warden.mounting, warden.variant])
	var numbers := {}
	for key in SLAG:
		numbers[key] = (WardenScript as Script).get_script_constant_map().get(key)
	_t.eq("flume: the meltdown slag numbers are unchanged", numbers, SLAG)
	if driver == null:
		warden.queue_free()
		await _frames(2)
		return
	var home: Vector3 = warden.home
	var moved := 0.0
	var carried := 0.0
	var starts: Array = []
	var phases: Array = []
	warden.attack_phase.connect(func(facts: Dictionary): phases.append([String(facts["row"]), String(facts["phase"])]))
	for n in 3:
		var lanes: int = warden.slag_lanes.size()
		warden._pulse_clock = warden.PULSE_CYCLE - warden.PULSE_TELEGRAPH
		for i in _seconds(warden.PULSE_TELEGRAPH + 0.3):
			if not warden._charging:
				_player.reset_to(_ground(warden.global_position + BALL_OUT))
			await physics_frame
			moved = maxf(moved, warden.global_position.distance_to(home))
			carried = maxf(carried, warden.anchor_velocity().length())
		if warden.slag_lanes.size() > lanes:
			var lane: Dictionary = warden.slag_lanes[warden.slag_lanes.size() - 1]
			var pour: Vector3 = driver.pour_point(warden)
			var from: Vector3 = lane["from"]
			starts.append(Vector2(from.x - pour.x, from.z - pour.z).length())
	var pour_off: float = Vector2(driver.pour_point(warden).x - home.x, driver.pour_point(warden).z - home.z).length()
	_t.check("flume: every slag lane starts at the pour channel", starts.size() == 3 and starts.all(func(d): return d <= 0.1)
			and pour_off > warden.RADIUS,
		"lane starts %s m from the pour channel, which is %.1f m from the relic" % [starts, pour_off])
	_t.check("flume: the lanes stay the W01 attack", not phases.is_empty() and phases.all(func(p): return p[0] == "W01"),
		"phases %s" % [phases.slice(0, 6)])
	# slag_hop: a ball in the air over a burning lane earns the codex fact.
	_combat.discovered.erase("slag_hop")
	var hop := false
	for i in _seconds(1.5):
		var burning: Array = warden.slag_lanes.filter(func(l): return l["phase"] == "strike")
		if not burning.is_empty():
			var lane: Dictionary = burning[burning.size() - 1]
			var over: Vector3 = lane["from"] + lane["dir"] * 6.0
			_player.reset_to(_ground(over, 3.0))
		await physics_frame
		moved = maxf(moved, warden.global_position.distance_to(home))
		if _combat.discovered.has("slag_hop"):
			hop = true
			break
	_t.check("flume: slag_hop still fires over a burning lane", hop, "discovered %s" % [_combat.discovery_log.slice(-4)])
	# The core window: MELTDOWN_WINDOW times the rule's stagger, counted in ticks.
	var ticks := 0
	var guard := 0
	while not warden.staggered() and guard < 30:
		var force := 1.0
		while _combat.punch_of("ram", force) < float(warden.plating):
			force += 0.05
		_combat.strike(warden, "ram", force)
		await physics_frame
		guard += 1
	while warden.staggered() and ticks < _seconds(20.0):
		await physics_frame
		ticks += 1
		moved = maxf(moved, warden.global_position.distance_to(home))
		carried = maxf(carried, warden.anchor_velocity().length())
	var want := _seconds(BossPosture.STAGGER_SECONDS * WardenScript.MELTDOWN_WINDOW)
	_t.check("flume: the core window lasts 1.5 times the stagger", absi(ticks - want) <= 1,
		"open %d ticks, want %d (%.1f s x %.1f)" % [ticks, want, BossPosture.STAGGER_SECONDS, WardenScript.MELTDOWN_WINDOW])
	_t.check("flume: the relic never moves", moved == 0.0 and carried == 0.0
			and driver.mount_offset(warden, 3.0) == Vector3.ZERO,
		"moved %.4f m from home, anchor speed %.4f m/s" % [moved, carried])
	warden.queue_free()
	await _frames(2)
