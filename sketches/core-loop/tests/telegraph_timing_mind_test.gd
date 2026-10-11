extends SceneTree

const Game := preload("res://src/game.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const T := preload("res://tests/support/t.gd")

# Telegraph timing for the Mind's own attacks (design-v3/LEGIBILITY.md section 2, "Telegraph
# timing"; wardens/mind.md sections 3 and 8): the pulse and the island tilt under the island,
# and the knock-down on the spires. Over 20 runs per attack, stepped and counted in physics
# ticks: the cue (the driver's attack_cue) starts within one tick of the charge (the Warden's
# charge for the pulse and the tilt, the stagger for the knock-down); the charge, cue to landing,
# is within one tick of its row (warden_mind.gd ROWS); and no damage lands outside the live
# window (a pulse tick). Then 30 hits in 3 s on a Warden with the boss camera row live keep the
# shake at or under that row's cap. The report prints each attack's recovery and cooldown beside
# its charge; those are reported, not gated.

const DRIVER_PATH := "res://src/combat/warden_mind.gd"
const RUNS := 20
const ATTACKS := ["pulse", "tilt", "knock_down"]

var t := T.new("telegraph_timing_mind_test")
var _game
var _combat
var _fleet
var _player
var _dt := 1.0 / 90.0
var _tick := 0
var _cues := {}
var _landings := {}
var _damage_ticks: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func _run() -> void:
	_dt = 1.0 / float(Engine.physics_ticks_per_second)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_combat = _game.ctx.spawner
	_fleet = _combat.fleet
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(10)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	for enemy in get_nodes_in_group("enemy"):
		if enemy.get("kind") != "vault":
			enemy.queue_free()
	for attack in ATTACKS:
		_cues[attack] = []
		_landings[attack] = []
	# Frozen, the ball's teleport lands at once, so the hand-stepped Warden sees it.
	_player.body().freeze = true
	var island := _spawn(5, "", Vector3.ZERO)
	var spires := _spawn(6, "choir", Vector3(0.0, 0.0, 300.0))
	if _driver(island) == null or _driver(spires) == null:
		t.check("the mind driver is attached to both mountings", false, "island %s, spires %s" % [island.mount_driver,
			spires.mount_driver])
	else:
		_pulse_runs(island)
		await _knock_runs(spires)
		_report_rows(_driver(island))
	island.queue_free()
	spires.queue_free()
	_player.body().freeze = false
	await _shake()
	await _frames(2)
	_game.free()
	quit(t.verdict())


func _spawn(stage: int, variant: String, offset: Vector3) -> Node3D:
	var spawn: Vector3 = _game.ctx.terrain.spawn_point(1)
	var warden = WardenScript.new()
	_game.ctx.root.add_child(warden)
	warden.global_position = Vector3(spawn.x + 60.0, 0.0, spawn.z + 60.0) + offset
	warden.setup(_player, _game.ctx.terrain, _game.ctx.root, func(): return true, 1.0,
		{"kind": "warden", "family": "mind", "stage": stage, "variant": variant, "harpoon_anchor": true, "fleet": _fleet,
			"plating": 170.0 if stage == 5 else 190.0, "hp": 1250.0 if stage == 5 else 1400.0})
	warden.set_physics_process(false)
	warden.hit_player.connect(func(_amount: float, _push: Vector3): _damage_ticks.append(_tick))
	var driver = _driver(warden)
	if driver != null:
		driver.attack_cue.connect(func(attack: String, _seconds: float):
			if _cues.has(attack):
				_cues[attack].append(_tick))
		driver.attack_landed.connect(func(attack: String):
			if _landings.has(attack):
				_landings[attack].append(_tick))
	return warden


func _driver(warden: Node3D):
	var driver = warden.mount_driver
	if driver == null or driver.get_script() == null or driver.get_script().resource_path != DRIVER_PATH:
		return null
	return driver


func _step(warden: Node3D, ball: Vector3) -> void:
	_player.reset_to(ball)
	_tick += 1
	warden._physics_process(_dt)


# The pulse and the tilt share the Warden's charge. The ball stands inside the core ring, so
# every pulse also damages it: the damage must land on pulse ticks and nowhere else.
func _pulse_runs(warden: Node3D) -> void:
	var ball: Vector3 = warden.home + Vector3(3.0, 0.0, 0.0)
	var charges: Array = []
	var pulse_ticks: Array = []
	var was := false
	var pulses: int = warden.pulses
	var guard := 0
	while pulse_ticks.size() < RUNS and guard < _ticks(6.0 * (RUNS + 2)):
		_step(warden, ball)
		guard += 1
		if warden._charging and not was:
			charges.append(_tick)
		was = warden._charging
		if warden.pulses > pulses:
			pulses = warden.pulses
			pulse_ticks.append(_tick)
	var row: Dictionary = _driver(warden).ROWS
	for attack in ["pulse", "tilt"]:
		_judge(attack, charges, row[attack])
	var outside := 0
	for at in _damage_ticks:
		if not pulse_ticks.has(at):
			outside += 1
	t.check("pulse: damage lands only on pulse ticks", pulse_ticks.size() == RUNS and _damage_ticks.size() == RUNS and outside == 0,
		"%d pulses, %d damage ticks, %d outside a pulse tick" % [pulse_ticks.size(), _damage_ticks.size(), outside])


# The knock-down: the perch clock is wound to the takeoff, the hand is staggered 1 s into the
# flight, the ball waits on the bowl floor under it; the stagger is the charge, the floor the
# landing. No damage at all may land.
func _knock_runs(warden: Node3D) -> void:
	var driver = _driver(warden)
	var damage_before := _damage_ticks.size()
	var staggers: Array = []
	var force := 1.0
	while _combat.punch_of("ram", force) < float(warden.plating):
		force += 0.05
	for run in RUNS:
		var guard := 0
		var ball: Vector3 = warden.home + Vector3(0.0, 0.0, 200.0)
		while driver.phase != "perched" or warden.staggered():
			_step(warden, ball)
			guard += 1
			if guard > _ticks(12.0):
				break
		driver.perch_clock = WardenScript.ADAPT_CYCLE
		guard = 0
		while driver.phase != "flight" and guard < _ticks(3.0):
			_step(warden, ball)
			guard += 1
		for i in _ticks(1.0):
			_step(warden, ball)
		ball = warden.global_position + Vector3(0.0, float(driver.floor_offset) - (warden.global_position.y - warden.home.y), 0.0)
		# One contact gain counts per engine frame and the Warden is stepped by hand, so each
		# stagger waits for a fresh engine frame, the bar is filled to just under full and one
		# matched ram staggers it. The hand-stepped Warden does not run on that frame.
		await physics_frame
		warden._posture.posture = warden._posture.FULL - 1.0
		_combat.strike(warden, "ram", force)
		staggers.append(_tick)
		guard = 0
		while warden.staggered() and guard < _ticks(8.0):
			_step(warden, ball)
			guard += 1
	_judge("knock_down", staggers, driver.ROWS["knock_down"])
	t.check("knock_down: no damage lands", _damage_ticks.size() == damage_before and staggers.size() == RUNS,
		"%d staggers, %d damage ticks" % [staggers.size(), _damage_ticks.size() - damage_before])


# Cue within one tick of each charge, charge length within one tick of the row's.
func _judge(attack: String, charges: Array, row: Dictionary) -> void:
	var cues: Array = _cues[attack]
	var landings: Array = _landings[attack]
	var n := mini(RUNS, mini(charges.size(), mini(cues.size(), landings.size())))
	var worst_cue := 0
	var worst_len := 0
	var want := _ticks(float(row["charge"]))
	for i in n:
		worst_cue = maxi(worst_cue, absi(int(cues[i]) - int(charges[i])))
		worst_len = maxi(worst_len, absi((int(landings[i]) - int(cues[i])) - want))
	t.check("%s: over %d runs the cue starts within one tick of the charge" % [attack, RUNS], n == RUNS and worst_cue <= 1,
		"%d runs (charges %d, cues %d, landings %d), worst gap %d ticks" % [n, charges.size(), cues.size(), landings.size(), worst_cue])
	t.check("%s: the charge is within one tick of its row" % attack, n == RUNS and worst_len <= 1,
		"row %.2f s (%d ticks), worst miss %d ticks" % [float(row["charge"]), want, worst_len])


func _report_rows(driver) -> void:
	for attack in ATTACKS:
		var row: Dictionary = driver.ROWS[attack]
		print("  %s: charge %.2f s, recovery %.2f s, cooldown %.2f s (recovery and cooldown reported, not gated)" % [attack,
			float(row["charge"]), float(row["recovery"]), float(row["cooldown"])])


# 30 hits in 3 s on a swinging Warden, the boss row live: the shake never passes its cap. The
# positive control is a shake asked above the cap, which the rig must clamp.
func _shake() -> void:
	var warden := _spawn(5, "", Vector3(0.0, 0.0, -300.0))
	warden.set_physics_process(true)
	var cam = _game.camera
	var cap: float = ChaseCamera.PROFILES["boss"]["shake_cap"]
	cam.set_boss_reach(true)
	_player.reset_to(warden.home + Vector3(8.0, 0.0, 0.0))
	await _frames(2)
	cam.shake(cap * 3.0, 0.5)
	await process_frame
	await process_frame
	var control: float = cam.shake_amplitude()
	t.check("shake: a shake asked above the boss row's cap is clamped", control > 0.0 and control <= cap + 0.0001,
		"asked %.2f, rig %.3f, cap %.2f" % [cap * 3.0, control, cap])
	warden._pulse_clock = warden.PULSE_CYCLE - warden.PULSE_TELEGRAPH
	var hits := 0
	var peak := 0.0
	var frames := _ticks(3.0)
	for i in frames:
		if i % (frames / 30) == 0 and hits < 30:
			_combat.strike(warden, "ram", 4.0)
			hits += 1
		await physics_frame
		peak = maxf(peak, cam.shake_amplitude())
	t.check("shake: 30 hits in 3 s keep the shake at or under the boss row's cap", hits == 30 and peak <= cap + 0.0001,
		"%d hits, peak shake %.3f, cap %.2f" % [hits, peak, cap])
	cam.set_boss_reach(false)
	warden.queue_free()
