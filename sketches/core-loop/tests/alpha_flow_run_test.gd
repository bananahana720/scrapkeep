# smoke: solo (walks every stage, gate, launch and boss of the default table at wall pace; about 10 s on two stages, 20 s on six)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const RunStore := preload("res://src/core/run_store.gd")
const T := preload("res://tests/support/t.gd")

# The default table walked the way a human launches it, unsplit: the title, Space to class
# select, key 1 to the first stage, then for every world in the table and every stage in it
# the stage's Warden broken through the real spawner, a gate rolled through, and the launch
# landing on the next stage; each world's last launch lands in that world's arena, whose
# module is the one flow names for the world. Brindle falls through the harness defeat seam
# (boss.gd _defeat); any other boss module's Warden through its TARGET surface (judge_hit,
# on_struck, take_damage on a shatter). Victory follows each boss; after the last one the
# summary, run_won, one run_ended, and a run store left as a tombstone that refuses a stale
# write. Everything is read from ctx.stages, so it holds on any stage count.
#
# Evidence limit: a Warden's strikes are the spawner's strike() as a slam with the ball's
# smash_landing mark set on it, and a stub boss's are TARGET calls, not ball contacts; the
# gate is rolled through from a placed approach, not steered to. Unsplit: six stages walk
# in about 20 s.

const STORE_DIR := "user://alpha_flow_run_test"
const STORE_PATH := STORE_DIR + "/run.json"
# The 180 s cap, counted in physics frames at the project's 90 ticks per second.
const FRAME_CAP := 180 * 90
const STATE_FRAMES := 90 * 20
const STRIKE_FRAMES := 90 * 10
const GATE_APPROACH := 3.0
const GATE_SPEED := 20.0
const GATE_RETRY := 45
const SLAM := 1.0e6

var _t := T.new("alpha_flow_run_test")
var _game
var _source := Intent.Scripted.new()
var _began := 0
var _states: Array[String] = []
var _entered: Array[int] = []
var _worlds: Array[int] = []
var _arenas := 0
var _ended := 0
var _won := false
var _deaths := 0


func _initialize() -> void:
	_began = Engine.get_physics_frames()
	_clean_store()
	DirAccess.make_dir_recursive_absolute(STORE_DIR)
	_game = _make_game()
	_game.test_mode = true
	_game.run_store_path = STORE_PATH
	root.add_child(_game)
	_run()


func _make_game():
	return Game.new()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	# The Mind's win opens the Q16 ending (fly-over, victory lap, credits); victory_lap_test owns it. This walk ends on the summary.
	_game.flow.victory_lap = false
	await _walk()
	var frames: int = Engine.get_physics_frames() - _began
	_t.check("within the cap", frames < FRAME_CAP, "%d physics frames, %.1f s simulated" % [frames, frames / 90.0])
	_game.free()
	_clean_store()
	quit(_t.verdict())


func _walk() -> void:
	var game = _game
	var flow = game.flow
	var stages = game.ctx.stages
	var ev = game.events
	ev.flow_changed.connect(func(s: String): _states.append(s))
	ev.stage_entered.connect(func(s: int, _retry: bool): _entered.append(s))
	ev.world_entered.connect(func(w: int): _worlds.append(w))
	ev.boss_arena_entered.connect(func(): _arenas += 1)
	ev.run_ended.connect(func(won: bool):
		_ended += 1
		_won = won)
	ev.player_died.connect(func(): _deaths += 1)
	game.player.source = _source
	_t.check("bot driven", game.bot_driven and flow.store != null, "bot_driven %s, store on %s" % [game.bot_driven, flow.store != null])
	_t.eq("boots on the title", flow.state_name(), "title")
	game._screen_key(KEY_SPACE)
	_t.eq("Space opens class select", flow.state_name(), "class_select")
	game._screen_key(KEY_1)
	_t.eq("key 1 starts the run", flow.state_name(), "stage")
	_t.eq("state order", _states.slice(0, 2), ["class_select", "stage"])
	# A second store on the same file, loaded at the first entrance: after the run ends it
	# holds a generation the tombstone has passed, so its write is a stale one.
	var stale := RunStore.new(STORE_PATH)
	var stale_doc: Dictionary = stale.load()
	var worlds: Array = stages.worlds()
	print("table: %d stages in worlds %s" % [stages.DEFS.size(), worlds])
	for w in worlds:
		for s in range(stages.first_of(w), stages.last_of(w) + 1):
			if not await _clear_stage(s):
				return
		if not await _beat_boss(w):
			return
	await _settle_summary(stale, stale_doc)


func _clear_stage(s: int) -> bool:
	var game = _game
	var flow = game.flow
	if not _t.check("stage %d entered" % s, game.run.stage == s and flow.state_name() == "stage" and _entered.has(s),
			"run.stage %d in %s, entered %s" % [game.run.stage, flow.state_name(), _entered]):
		return false
	var warden = flow.warden
	if not _t.check("stage %d sealed by a spawned Warden" % s, flow.sealed and is_instance_valid(warden),
			"sealed %s, Warden %s" % [flow.sealed, warden]):
		return false
	var strikes := 0
	while flow.state_name() in ["stage", "beacon"] and strikes < STRIKE_FRAMES:
		if is_instance_valid(flow.warden):
			# A slam landed on the Warden, as the ball marks one: the alpha rows set
			# ram_shatters false, so only a smash shatters the open core.
			game.player.smash_landing = flow.warden
			game.ctx.spawner.strike(flow.warden, "slam", SLAM)
			game.player.smash_landing = null
		strikes += 1
		await physics_frame
	if not _t.check("stage %d Warden broken" % s, flow.state_name() == "gates" and not flow.sealed,
			"state %s after %d spawner strikes" % [flow.state_name(), strikes]):
		return false
	var placed := -GATE_RETRY
	var frames := 0
	while flow.state_name() == "gates" and frames < STATE_FRAMES:
		if frames - placed >= GATE_RETRY and game.build.gates.is_open():
			placed = frames
			_approach(game.build.gates.offers[0])
		frames += 1
		await physics_frame
	_source.hold = {}
	if not _t.check("stage %d gate taken" % s, flow.state_name() == "launch", "state %s after %d frames" % [flow.state_name(), frames]):
		return false
	var last_of_world: bool = game.ctx.stages.is_world_last(s)
	var want := "boss" if last_of_world else "stage"
	await _until(func(): return flow.state_name() == want or flow.state_name() == "dead")
	if last_of_world:
		return _t.check("stage %d launch lands in the arena" % s, flow.state_name() == "boss", "state %s" % flow.state_name())
	return _t.check("stage %d launch lands on stage %d" % [s, s + 1], flow.state_name() == "stage" and game.run.stage == s + 1,
		"state %s on stage %d" % [flow.state_name(), game.run.stage])


func _approach(offer: Dictionary) -> void:
	var facing: Vector3 = offer["facing"]
	var start: Vector3 = offer["at"] - facing * GATE_APPROACH
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.player.reset_to(at, facing * GATE_SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(facing)
	_source.hold = {"move": Vector2(0.0, 1.0)}


func _beat_boss(w: int) -> bool:
	var game = _game
	var flow = game.flow
	var module = flow._module_for(w)
	var path: String = module.get_script().resource_path if module != null else "none"
	if not _t.check("world %d arena" % w, flow.state_name() == "boss" and flow.in_arena and module != null and game.ctx.boss == module,
			"state %s, in_arena %s, ctx.boss is the world's module %s (%s)" % [flow.state_name(), flow.in_arena, game.ctx.boss == module, path]):
		return false
	var hits := 0
	if path == flow.SCENE_BOSS:
		Harness.defeat(game)
		hits = 1
	else:
		while is_instance_valid(module.warden) and not module.warden.is_dead() and hits < STRIKE_FRAMES:
			_target_hit(module.warden)
			hits += 1
			await physics_frame
	print("world %d boss %s: %d hit(s) to defeat" % [w, path.get_file(), hits])
	await _until(func(): return flow.state_name() != "boss")
	if not _t.eq("world %d victory" % w, flow.state_name(), "victory"):
		return false
	var run_last: bool = game.ctx.stages.is_run_last(game.run.stage)
	var want := "summary" if run_last else "stage"
	await _until(func(): return flow.state_name() == want)
	if run_last:
		return _t.eq("world %d victory leads to the summary" % w, flow.state_name(), "summary")
	var next: int = game.ctx.stages.first_of(w + 1)
	return _t.check("world %d victory lands on world %d's first stage %d" % [w, w + 1, next],
		flow.state_name() == "stage" and game.run.stage == next and _worlds.has(w + 1),
		"state %s on stage %d, worlds entered %s" % [flow.state_name(), game.run.stage, _worlds])


# BossContract.TARGET: the hit judged, applied, and on a shatter the chunk's damage taken.
func _target_hit(warden) -> void:
	var result: Dictionary = warden.judge_hit("slam", 9999.0, true, 3)
	warden.on_struck("slam", String(result.get("part", "")), result)
	if bool(result.get("shatter", false)):
		warden.take_damage(float(result.get("dealt", 0.0)))


func _settle_summary(stale, stale_doc: Dictionary) -> void:
	var game = _game
	var flow = game.flow
	var stages = game.ctx.stages
	for _i in 30:
		await physics_frame
	var count: int = stages.DEFS.size()
	var all: Array[int] = []
	for i in range(1, count + 1):
		all.append(i)
	_t.eq("every stage entered once, in order", _entered, all)
	_t.eq("every world entered", _worlds, stages.worlds())
	_t.eq("one arena per world", _arenas, stages.worlds().size())
	_t.check("run won on the summary", flow.state_name() == "summary" and flow.run_won and _won,
		"state %s, run_won %s, run_ended(won) %s" % [flow.state_name(), flow.run_won, _won])
	_t.eq("run_ended emitted once", _ended, 1)
	_t.eq("no death on the walk", _deaths, 0)
	var tombstone := RunStore.new(STORE_PATH)
	var loaded: Dictionary = tombstone.load()
	var late: String = stale.save(stale_doc)
	_t.check("run store is a tombstone", FileAccess.file_exists(STORE_PATH) and loaded.is_empty() and tombstone.refusal == RunStore.REFUSED_ENDED
			and late == RunStore.REFUSED_ENDED and RunStore.new(STORE_PATH).load().is_empty(),
		"file %s, load empty %s, stale write refused as '%s' (%s)" % [FileAccess.file_exists(STORE_PATH), loaded.is_empty(), late, stale.last_error])


func _until(done: Callable) -> void:
	var frames := 0
	while not done.call() and frames < STATE_FRAMES and Engine.get_physics_frames() - _began < FRAME_CAP:
		frames += 1
		await physics_frame


func _clean_store() -> void:
	var dir := DirAccess.open(STORE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(STORE_DIR)
