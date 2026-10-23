extends SceneTree

const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# The Brindle unlock through a live run, not the bus: a test-mode game on a fresh profile
# shows Tarn locked on class select, key 1 starts Sable on the default table, world one's
# stages are walked the way alpha_flow_run_test walks them (each Warden slammed through the
# real spawner, a gate rolled through, the launch landing on the next stage, then the
# arena), and Brindle falls by the real damage path: guns stagger the hull through
# combat.strike, a smash in the opening takes a chunk, boss.gd's own jump_to_phase(4) dev
# hook starts the eject, the scooter lands on its own flight, and a ram on it through
# combat.strike is the catch (boss.gd _on_enemy_struck -> _defeat). The test never emits a
# bus signal. The bus is recorded during the kill: enemy_killed("brindle") must come before
# boss_defeated, both in world one. Victory leads to world two, where the run ends by death
# (a death ends the run: there is no free retry), the summary shows, and Space returns to class select with
# Tarn's card open and its key starting a Tarn run. The profile is reloaded from disk at the
# end.
#
# Evidence limit: strikes are combat.strike() calls, not flown ball contacts; phases 2 and 3
# are skipped by jump_to_phase, so the 75 s set-piece pacing is not exercised here
# (boss_flow_test owns it).

const TARN := "tarn"
const SABLE := "pylon_engineer"
const ROW := "brindle_routed"
const STORE_DIR := "user://unlock_live_brindle_test"
const STORE_PATH := STORE_DIR + "/run.json"
const STATE_FRAMES := 90 * 20
const STRIKE_FRAMES := 90 * 10
const GATE_APPROACH := 3.0
const GATE_SPEED := 20.0
const GATE_RETRY := 45
const SLAM := 1.0e6

var _t := T.new("unlock_live_brindle_test")
var _game
var _source := Intent.Scripted.new()
var _bus: Array = []
var _earned: Array = []
var _began := 0


func _initialize() -> void:
	_began = Engine.get_physics_frames()
	_clean_store()
	DirAccess.make_dir_recursive_absolute(STORE_DIR)
	_game = Game.new()
	_game.test_mode = true
	_game.run_store_path = STORE_PATH
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await _frames(5)
	await _walk()
	var frames: int = Engine.get_physics_frames() - _began
	print("simulated %d physics frames (%.1f s)" % [frames, frames / 90.0])
	_game.free()
	_clean_store()
	quit(_t.verdict())


func _walk() -> void:
	var game = _game
	var flow = game.flow
	var ev = game.events
	game.player.source = _source
	ev.achievement_earned.connect(func(id: String): _earned.append(id))
	ev.enemy_killed.connect(func(kind: String, _at: Vector3, _scrap: int):
		if kind == "brindle":
			_bus.append(["enemy_killed:brindle", game.run.world]))
	ev.boss_defeated.connect(func(): _bus.append(["boss_defeated", game.run.world]))
	var profile = game.ctx.profile
	_t.check("fresh profile under the test storage_dir", profile.path.begins_with(game.storage_dir + "/"), profile.path)
	_t.check("fresh profile has no Brindle row", not profile.earned(ROW), ROW)
	_t.check("fresh profile has no Tarn", not profile.has_pilot(TARN), TARN)
	_t.eq("boots on the title", flow.state_name(), "title")
	game._screen_key(KEY_SPACE)
	if not await _settle_select("fresh"):
		return
	_t.eq("fresh: Sable only selectable, Tarn not", _selectable(), [SABLE])
	_t.check("fresh: Tarn's card is locked", _card(TARN) != null and _card(TARN).locked, str(_card(TARN)))
	game._screen_key(KEY_1 + _index(TARN))
	_t.check("fresh: Tarn's key starts nothing", flow.state_name() == "class_select" and not flow.in_play(), flow.state_name())
	game._screen_key(KEY_1 + _index(SABLE))
	if not _t.check("key starts a Sable run on stage 1", flow.state_name() == "stage" and game.run.stage == 1 and game.run.class_def.id == SABLE,
			"%s on stage %d" % [flow.state_name(), game.run.stage]):
		return
	var stages = game.ctx.stages
	for s in range(stages.first_of(1), stages.last_of(1) + 1):
		if not await _clear_stage(s):
			return
	await _fight_brindle()
	await _end_by_death()
	await _after_run()


func _clear_stage(s: int) -> bool:
	var game = _game
	var flow = game.flow
	if not _t.check("stage %d entered" % s, game.run.stage == s and flow.state_name() == "stage", "run.stage %d in %s" % [game.run.stage, flow.state_name()]):
		return false
	var strikes := 0
	while flow.state_name() in ["stage", "beacon"] and strikes < STRIKE_FRAMES:
		if is_instance_valid(flow.warden):
			game.player.smash_landing = flow.warden
			game.ctx.spawner.strike(flow.warden, "slam", SLAM)
			game.player.smash_landing = null
		strikes += 1
		await physics_frame
	if not _t.check("stage %d Warden broken" % s, flow.state_name() == "gates", "state %s after %d strikes" % [flow.state_name(), strikes]):
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
	if not _t.check("stage %d gate taken" % s, flow.state_name() == "launch", "state %s" % flow.state_name()):
		return false
	var want := "boss" if game.ctx.stages.is_world_last(s) else "stage"
	await _until(func(): return flow.state_name() == want or flow.state_name() == "dead")
	return _t.eq("stage %d launch lands in %s" % [s, want], flow.state_name(), want)


func _approach(offer: Dictionary) -> void:
	var facing: Vector3 = offer["facing"]
	var start: Vector3 = offer["at"] - facing * GATE_APPROACH
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.player.reset_to(at, facing * GATE_SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(facing)
	_source.hold = {"move": Vector2(0.0, 1.0)}


# Brindle by the real damage path. Returns once the boss is defeated or the attempt failed.
func _fight_brindle() -> void:
	var game = _game
	var flow = game.flow
	var boss = game.ctx.boss
	var combat = game.ctx.spawner
	if not _t.check("world one's arena is Brindle's", flow.state_name() == "boss" and boss != null and boss.has_method("scooter_landed") and game.run.world == 1,
			"state %s, boss %s, world %d" % [flow.state_name(), boss, game.run.world]):
		return
	var hull = boss.ship.hull
	var chunks_before: int = boss.chunks_left()
	var shots := 0
	while not boss.staggered() and shots < 200:
		combat.strike(hull, "arc", 5000.0, "", "weapon")
		shots += 1
	var opened_on: int = Engine.get_physics_frames()
	while Engine.get_physics_frames() == opened_on:
		await physics_frame
	game.player.smash_landing = hull
	combat.strike(hull, "ram", 150.0)
	game.player.smash_landing = null
	_t.check("guns stagger the hull and a smash takes a chunk", boss.chunks_left() == chunks_before - 1,
		"%d shots, chunks %d -> %d" % [shots, chunks_before, boss.chunks_left()])
	boss.jump_to_phase(4)
	var frames := 0
	while not boss.scooter_landed() and frames < STATE_FRAMES:
		frames += 1
		await physics_frame
	if not _t.check("the scooter lands on its own eject flight", boss.scooter_landed() and flow.state_name() == "boss",
			"landed %s after %d frames, state %s" % [boss.scooter_landed(), frames, flow.state_name()]):
		return
	_t.eq("no Brindle event before the catch", _bus, [])
	var scooter = boss.scooter
	game.player.reset_to(scooter.global_position)
	game.player.body().global_position = scooter.global_position
	combat.strike(scooter, "ram", 50.0)
	_t.eq("the catch defeats Brindle", boss.state_name(), "defeated")
	_t.eq("bus order: enemy_killed(brindle) then boss_defeated, both in world 1", _bus, [["enemy_killed:brindle", 1], ["boss_defeated", 1]])
	_t.check("profile records the Brindle row at the kill", game.ctx.profile.earned(ROW) and game.ctx.profile.has_pilot(TARN), ROW)
	await _until(func(): return flow.state_name() != "boss")
	_t.eq("victory follows", flow.state_name(), "victory")
	var next: int = game.ctx.stages.first_of(2)
	await _until(func(): return flow.state_name() == "stage")
	_t.check("victory lands on world two", flow.state_name() == "stage" and game.run.stage == next and game.run.world == 2,
		"state %s on stage %d, world %d" % [flow.state_name(), game.run.stage, game.run.world])


# The run ends the way a player loses it: a death, with no free retry to spend.
# Wherever the run stands (the arena if the kill failed), it ends on the summary.
func _end_by_death() -> void:
	var game = _game
	var flow = game.flow
	for attempt in 3:
		if flow.state_name() == "summary":
			break
		await _until(func(): return flow.in_play())
		await _frames(10)
		game.run.damage(99999.0, "test")
		await _until(func(): return flow.state_name() == "dead" or flow.state_name() == "summary")
		if flow.state_name() == "dead":
			game._screen_key(KEY_N)
	await _frames(5)
	_t.eq("the run ends on the summary", flow.state_name(), "summary")
	var screens = game.screens
	_t.check("the summary is shown", screens._state == "summary" and screens._title.visible and screens._title.text == "RUN OVER",
		"screen %s, title '%s' visible %s" % [screens._state, screens._title.text, screens._title.visible])


func _after_run() -> void:
	var game = _game
	var flow = game.flow
	var profile = game.ctx.profile
	var frames := 0
	while flow.state_name() == "summary" and frames < STATE_FRAMES:
		game._screen_key(KEY_SPACE)
		frames += 1
		await physics_frame
	if not await _settle_select("after the run"):
		return
	_t.eq("after the run: Tarn joins the selectable set", _selectable(), [SABLE, TARN])
	_t.check("after the run: Tarn's card is open", _card(TARN) != null and not _card(TARN).locked, str(_card(TARN)))
	_t.check("after the run: profile holds the Brindle row and Tarn", profile.earned(ROW) and profile.has_pilot(TARN), profile.path)
	_t.eq("the Brindle row announced once", _earned.count(ROW), 1)
	var reloaded := Profile.new(profile.path)
	_t.check("reload succeeds", reloaded.load_profile(), reloaded.last_error)
	_t.check("reloaded profile holds the Brindle row and Tarn", reloaded.earned(ROW) and reloaded.has_pilot(TARN), profile.path)
	game._screen_key(KEY_1 + _index(TARN))
	_t.check("Tarn's key starts a Tarn run", flow.in_play() and game.run.class_def.id == TARN, flow.state_name())


func _selectable() -> Array:
	var out: Array = []
	for def in _game.flow.classes:
		if _game.pilot_unlocked(def):
			out.append(def.id)
	return out


func _index(id: String) -> int:
	for i in _game.flow.classes.size():
		if _game.flow.classes[i].id == id:
			return i
	return -1


func _card(id: String):
	var cards: Array = _game.screens.class_cards()
	var i := _index(id)
	return cards[i] if i >= 0 and i < cards.size() else null


func _settle_select(label: String) -> bool:
	for i in 120:
		await physics_frame
		var cards: Array = _game.screens.class_cards()
		if i >= 20 and _game.flow.state_name() == "class_select" and not cards.is_empty() and cards.all(func(c): return not c.disabled):
			return true
	return _t.check("%s: class select settles" % label, false, _game.flow.state_name())


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _until(done: Callable) -> void:
	var frames := 0
	while not done.call() and frames < STATE_FRAMES:
		frames += 1
		await physics_frame


func _clean_store() -> void:
	var dir := DirAccess.open(STORE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(STORE_DIR)
