# smoke: timeout=360s fixed-fps=90 (about 250 game seconds of stepped fights)
# 2026-10-13 RED-COMBAT: WT-BANDS 907bfef changes posture gain, not BRAKE_DROP
# (merge message; design-v3/wardens/swarm.md section 3). A stronger hit now
# opens during hit-stop. Measure the row in physics delta seconds, as the
# hoist does, rather than assuming every observed frame is a full-speed tick.
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# KF3 telegraph timing for the swarm's own attacks (wardens/swarm.md sections 3 and 5): the
# pulse on the headframe hive, the hoist's brake-drop and the sinkhole's pool swell. Over 20
# runs per attack the cue starts within one physics tick of the charge, the charge lasts its
# row within one tick, and no damage lands outside the live window. Thirty ram hits in 3 s on
# the moving hive keep the camera shake under the active camera row's cap. Each attack's
# recovery and cooldown seconds print beside its charge length; they are reported, not gated.
#
# Rows: the pulse charges PULSE_TELEGRAPH and lands on its last tick (warden.gd); the drop
# takes the driver's BRAKE_DROP; the swell telegraphs SWELL_SECONDS before the floor moves.

const DRIVER_PATH := "res://src/combat/warden_swarm.gd"
const RUNS := 20
const SHAKE_HITS := 30
const SHAKE_SECONDS := 3.0
# The impact shake's own clamp (chase_camera.gd), the cap when no camera row is active.
const IMPACT_CAP := 1.2

var _game
var _combat
var _player
var _warden
var _source := Intent.Scripted.new()
var _failures := 0
var _damage_frames: Array = []
var _facts: Array = []
var _out := Vector3.LEFT
var _sim_seconds := 0.0


func _physics_process(delta: float) -> bool:
	_sim_seconds += delta
	return false


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func _tick() -> float:
	return 1.0 / Engine.physics_ticks_per_second


func _start(stage: int) -> bool:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.flow.enter_stage(stage, Vector3.ZERO, false)
	await _frames(_ticks(0.4))
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden) or not ResourceLoader.exists(DRIVER_PATH):
		return false
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	_damage_frames.clear()
	_facts.clear()
	_warden.hit_player.connect(func(amount: float, _push: Vector3):
		if amount > 0.0:
			_damage_frames.append(Engine.get_physics_frames()))
	_game.events.world_fact.connect(func(kind: String, _at: Vector3): _facts.append({"kind": kind, "frame": Engine.get_physics_frames()}))
	_warden.set_harpoon_anchor(true)
	_warden.set_mount_driver(load(DRIVER_PATH).new())
	_warden._pulse_clock = 0.0
	await _frames(2)
	return true


func _end() -> void:
	_source.hold = {}
	if _game != null:
		_game.free()
	_game = null
	await _frames(2)


func _ground(at: Vector3) -> Vector3:
	return _game.ctx.terrain.drop_point(at.x, at.z, 1.5)


func _offset() -> float:
	return _warden.global_position.y - _warden.home.y


func _matched_force() -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < float(_warden.plating):
		force += 0.05
	return force


func _run() -> void:
	if await _start(3):
		await _shake()
		await _pulse()
		await _hoist_drop()
	else:
		_report("stage 3 hive with the swarm driver", false, "no Warden or no %s" % DRIVER_PATH)
	await _end()
	if await _start(4):
		await _pool_swell()
	else:
		_report("stage 4 nest with the swarm driver", false, "no Warden or no %s" % DRIVER_PATH)
	await _end()
	print("telegraph_timing_swarm_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# Thirty rams in 3 s on the hive keep the shake under the cap of the camera rows then active.
func _shake() -> void:
	var cam = _game.camera
	var stand := _ground(_warden.home + _out * 14.0)
	var worst := 0.0
	var worst_cap := INF
	var over := 0
	var hits := 0
	var force := _matched_force()
	for i in _ticks(SHAKE_SECONDS):
		_player.reset_to(stand)
		if hits < SHAKE_HITS and i % maxi(1, _ticks(SHAKE_SECONDS) / SHAKE_HITS) == 0:
			_combat.strike(_warden, "ram", force)
			hits += 1
		await physics_frame
		var cap := IMPACT_CAP
		for row in cam.active_profiles():
			cap = minf(cap, float(cam.PROFILES[row]["shake_cap"]))
		var shake: float = cam.shake_amplitude()
		worst = maxf(worst, shake)
		worst_cap = minf(worst_cap, cap)
		if shake > cap + 0.0001:
			over += 1
	_report("30 hits in 3 s keep the shake under the camera row's cap", hits == SHAKE_HITS and over == 0,
		"%d hits, worst shake %.3f, lowest cap %.2f, %d ticks over" % [hits, worst, worst_cap, over])
	while _warden.staggered():
		_player.reset_to(stand)
		await physics_frame


# The pulse: the ball stands inside the core ring while the hoist runs; the ring (the cue)
# appears on the charge's tick, the charge lasts PULSE_TELEGRAPH, and the core ring's damage
# lands only on a pulse tick. One pulse per 6 s, as the hoist's two dwells allow.
func _pulse() -> void:
	var stand := _ground(_warden.home + _out * 4.5)
	var charges: Array = []
	var cues: Array = []
	var pulses: Array = []
	var charging := false
	var cued := false
	var count: int = _warden.pulses
	_damage_frames.clear()
	var guard := 0
	while pulses.size() < RUNS and guard < _ticks(float(RUNS + 2) * 6.5):
		_player.reset_to(stand)
		_warden._posture.posture = 0.0
		await physics_frame
		guard += 1
		# physics_frame resumes this loop before the nodes' step on the new frame, so what it
		# reads happened on the frame before (the frame a hit_player inside the step records).
		var frame := Engine.get_physics_frames() - 1
		if _warden._charging and not charging:
			charges.append(frame)
		charging = _warden._charging
		var ring = _warden.telegraph()
		if ring != null and not cued:
			cues.append(frame)
		cued = ring != null
		if _warden.pulses > count:
			count = _warden.pulses
			pulses.append(frame)
	var n := mini(pulses.size(), mini(charges.size(), cues.size()))
	var worst_cue := 0
	var worst_len := 0.0
	for i in n:
		worst_cue = maxi(worst_cue, absi(cues[i] - charges[i]))
		worst_len = maxf(worst_len, absf(float(pulses[i] - charges[i]) * _tick() - _warden.PULSE_TELEGRAPH))
	var stray := _damage_frames.filter(func(f): return not f in pulses)
	_report("pulse: over %d runs the cue starts within one tick of the charge" % RUNS, n >= RUNS and worst_cue <= 1,
		"%d pulses, %d charges, %d cues, worst %d ticks apart" % [pulses.size(), charges.size(), cues.size(), worst_cue])
	_report("pulse: the charge lasts its row within one tick", n >= RUNS and worst_len <= _tick() + 0.0001,
		"worst %.4f s off %.2f s" % [worst_len, _warden.PULSE_TELEGRAPH])
	_report("pulse: no damage lands outside the live window", stray.is_empty() and not _damage_frames.is_empty(),
		"%d damage ticks, %d off a pulse tick" % [_damage_frames.size(), stray.size()])
	print("swarm attack pulse: charge %.2f s, recovery 0.00 s (the rings clear on the pulse), cooldown %.2f s (pulse cycle less the charge; on the hoist a charge waits for a dwell's last 2 s)"
		% [_warden.PULSE_TELEGRAPH, _warden.PULSE_CYCLE - _warden.PULSE_TELEGRAPH])


# The brake-drop: each run sets the driver's clock into the high dwell (the hive stands 30 m
# up on the next tick), then staggers it. The stagger opening is the cue, the drop starts on
# that tick or the next, lasts the driver's BRAKE_DROP, and deals no damage.
func _hoist_drop() -> void:
	var driver = _warden.mount_driver
	var stand := _ground(_warden.home + _out * 14.0)
	var row: float = driver.BRAKE_DROP
	var force := _matched_force()
	var cue_gaps: Array = []
	var lengths: Array = []
	var drop_damage := 0
	_damage_frames.clear()
	for run in RUNS:
		driver.clock = driver.DWELL + driver.MOVE + 0.5
		for i in 2:
			_player.reset_to(stand)
			_warden._posture.posture = 0.0
			await physics_frame
		var strikes := 0
		# One ram a frame, as contacts land (the posture rule counts one hit per frame).
		while strikes < 30:
			_combat.strike(_warden, "ram", force)
			strikes += 1
			if _warden.staggered():
				break
			await physics_frame
		var high: bool = _offset() > driver.RISE - 0.01
		var opened := Engine.get_physics_frames()
		var opened_seconds := _sim_seconds
		var dropping := -1
		var landed := -1
		for i in _ticks(row + 1.0):
			_player.reset_to(stand)
			await physics_frame
			if dropping < 0 and bool(driver.dropping):
				dropping = Engine.get_physics_frames()
			if landed < 0 and _offset() <= 0.01:
				landed = Engine.get_physics_frames()
				break
		drop_damage += _damage_frames.size()
		_damage_frames.clear()
		cue_gaps.append(dropping - opened if high and dropping >= 0 else 99)
		lengths.append(_sim_seconds - opened_seconds if high and landed >= 0 and dropping >= 0 else INF)
		while _warden.staggered():
			_player.reset_to(stand)
			await physics_frame
		# The driver restarts its cycle on the first tick after the stagger; set the clock after that.
		await physics_frame
	var worst_gap: int = cue_gaps.max()
	var worst_drop := 0.0
	for l in lengths:
		worst_drop = maxf(worst_drop, absf(float(l) - row))
	_report("hoist drop: over %d runs the drop starts within one tick of the stagger" % RUNS, worst_gap <= 1,
		"cue gaps %s ticks" % [cue_gaps])
	_report("hoist drop: the drop lasts its row within one tick", worst_drop <= _tick() + 0.0001,
		"worst %.4f s off %.2f s" % [worst_drop, row])
	_report("hoist drop: no damage lands in the drop", drop_damage == 0, "%d damage ticks" % drop_damage)
	print("swarm attack hoist_drop: charge %.2f s, recovery %.2f s (the stagger left at the collar), cooldown none (one per stagger)"
		% [row, _warden._posture.stagger_seconds - row])


# The pool swell: the pool_swell fact is the cue on the chunk-lost tick, the floor starts to
# move SWELL_SECONDS later, and the pool deals no damage. The ball stands out of reach, off the pool.
func _pool_swell() -> void:
	var driver = _warden.mount_driver
	var stand := _ground(_warden.home + _out * 60.0)
	var row: float = driver.SWELL_SECONDS
	var cue_gaps: Array = []
	var lengths: Array = []
	_damage_frames.clear()
	for run in RUNS:
		_facts.clear()
		_player.reset_to(stand)
		var start: float = driver.pool_floor
		driver.on_chunk_lost(_warden, 3)
		var lost := Engine.get_physics_frames()
		var rose := -1
		for i in _ticks(row + driver.RISE_SECONDS + 0.5):
			_player.reset_to(stand)
			await physics_frame
			if rose < 0 and float(driver.pool_floor) > start + 0.0001:
				rose = Engine.get_physics_frames()
				break
		var cue := _facts.filter(func(f): return f["kind"] == "pool_swell")
		cue_gaps.append(absi(int(cue[0]["frame"]) - lost) if cue.size() == 1 else 99)
		lengths.append(float(rose - lost) * _tick() if rose >= 0 else INF)
	var worst_cue: int = cue_gaps.max()
	var worst_len := 0.0
	for l in lengths:
		worst_len = maxf(worst_len, absf(float(l) - row))
	_report("pool swell: over %d runs the cue starts within one tick of the chunk lost" % RUNS, worst_cue <= 1,
		"cue gaps %s ticks" % [cue_gaps])
	_report("pool swell: the swell lasts its row within one tick", worst_len <= _tick() + 0.0001,
		"worst %.4f s off %.2f s, lengths %s" % [worst_len, row, lengths.slice(0, 3)])
	_report("pool swell: the pool deals no damage", _damage_frames.is_empty(), "%d damage ticks" % _damage_frames.size())
	print("swarm attack pool_swell: charge %.2f s, recovery %.2f s (the floor's rise), cooldown none (one per chunk lost)"
		% [row, driver.RISE_SECONDS])
