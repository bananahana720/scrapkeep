extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Waking := preload("res://src/boss/waking.gd")
const WakingFloors := preload("res://src/boss/waking_floors.gd")
const Warden := preload("res://src/combat/warden.gd")
const T := preload("res://tests/support/t.gd")

# The Waking fought floor by floor on the default table: world two's arena entered through
# flow's seams, its Warden struck through the module harness's TARGET hit, paced so each
# shattered chunk's floor drop finishes before the next hit. Each floor is telegraphed, then
# drops, highest first; the ground under the Warden falls a tier per drop and ends at the pit,
# the Warden is re-seated each time, the music's phase climbs, the objective names each
# floor, and the fourth chunk is the win.
#
# Evidence limit: hits are TARGET calls, not ball contacts, and the pacing is the test's own:
# it stops hitting for one floor drop after every shatter.

const FIGHT_CAP := 90 * 60
const STATE_FRAMES := 90 * 10
# Frames the test holds its hits after a shatter: the drop's warning plus a margin.
const REST_FRAMES := int(Waking.FLOOR_WARN * 90.0) + 30
const LEAD_FRAMES := Waking.FLOOR_WARN * 90.0 * 0.9

var _t := T.new("waking_fight_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await _walk()
	_game.free()
	quit(_t.verdict())


func _walk() -> void:
	var game = _game
	var flow = game.flow
	_t.check("bot driven", game.bot_driven, "bot_driven %s" % game.bot_driven)
	var seen = Harness.counter(game)
	Harness.boot(game)
	Harness.enter_world(game, 2)
	var mod = Harness.module(game, 2)
	var path: String = mod.get_script().resource_path if mod != null else "none"
	if not _t.check("world 2 module is waking.gd and ctx.boss", path.ends_with("waking.gd") and game.ctx.boss == mod,
			"module %s, ctx.boss is it %s" % [path, game.ctx.boss == mod]):
		return
	var shape: Dictionary = Harness.conforms(mod)
	_t.eq("module conforms to MODULE", shape["module"], [])
	_t.eq("target conforms to TARGET", shape["target"], [])

	var telegraphs: Array = []
	game.ctx.events.boss_attack_telegraphed.connect(func(id: String, _seconds: float):
		telegraphs.append([id, Engine.get_physics_frames()]))

	var floors: WakingFloors = mod.floors
	var center: Vector3 = mod.pad.global_position
	var pit: float = center.y + Waking.PAD_THICK * 0.5
	var top_height: float = pit + floors.floor_height(1)
	_t.near("ground starts on floor 1", mod.ground_height_at(center), top_height)
	_t.check("ball enters on floor 1", game.ctx.player.ball_position().y >= top_height,
			"ball y %.2f, floor 1 top %.2f" % [game.ctx.player.ball_position().y, top_height])
	_t.near("Warden seated on floor 1", mod.warden.global_position.y, top_height + Warden.HALF_HEIGHT, 0.01)

	var changes: Array = []
	var phases: Array = []
	var objectives := {}
	var last_height: float = mod.ground_height_at(center)
	var chunks_before: int = mod.warden.chunks_left()
	var rest := 0
	var frames := 0
	while Harness._alive(Harness.target(mod)) and frames < FIGHT_CAP:
		if rest > 0:
			rest -= 1
		else:
			Harness.hit(mod)
		frames += 1
		await physics_frame
		if not mod.active():
			break
		var chunks: int = mod.warden.chunks_left() if is_instance_valid(mod.warden) else 0
		if chunks < chunks_before:
			rest = REST_FRAMES
		chunks_before = chunks
		var h: float = mod.ground_height_at(center)
		if h != last_height:
			changes.append({"frame": Engine.get_physics_frames(), "from": last_height, "to": h,
					"warden_y": mod.warden.global_position.y if is_instance_valid(mod.warden) else NAN})
			last_height = h
		var music: Dictionary = mod.music_state()
		if not music.is_empty() and (phases.is_empty() or phases[-1] != int(music["phase"])):
			phases.append(int(music["phase"]))
		objectives[mod.objective_text()] = true

	print("waking fight: %d frame(s), %d drop(s), telegraphs %s" % [frames, changes.size(), str(telegraphs)])
	_t.check("defeated within the cap", seen.defeated == 1 and not Harness._alive(Harness.target(mod)),
			"%d frames of %d, boss_defeated %d" % [frames, FIGHT_CAP, seen.defeated])

	# The Waking's own attacks telegraph on the same signal (waking_attacks.gd); the floors are these.
	telegraphs = telegraphs.filter(func(t): return String(t[0]).begins_with("waking_floor_"))
	var ids: Array = telegraphs.map(func(t): return t[0])
	_t.eq("floors dropped in order", ids, ["waking_floor_1", "waking_floor_2", "waking_floor_3"])
	_t.eq("three height changes", changes.size(), 3)
	for i in mini(changes.size(), telegraphs.size()):
		var c: Dictionary = changes[i]
		var lead: int = c["frame"] - telegraphs[i][1]
		_t.check("drop %d telegraphed %d frames ahead" % [i + 1, lead], lead >= LEAD_FRAMES, "need %.0f" % LEAD_FRAMES)
		_t.near("drop %d falls one tier" % (i + 1), c["from"] - c["to"], WakingFloors.SPACING)
		_t.near("drop %d Warden re-seated" % (i + 1), c["warden_y"], c["to"] + Warden.HALF_HEIGHT, 0.01)
	_t.near("ground ends at the pit", last_height, pit)
	_t.eq("music phase climbs 1, 2, 3", phases, [1, 2, 3])
	for n in Waking.FLOOR_NAMES:
		var named := false
		for text in objectives.keys():
			named = named or String(text).contains("%s floor" % n)
		_t.check("objective named the %s floor" % n, named, str(objectives.keys()))

	await _until(func(): return flow.state_name() != "boss")
	if not _t.eq("victory", flow.state_name(), "victory"):
		return
	var next: int = game.ctx.stages.first_of(3)
	await _until(func(): return flow.state_name() == "stage")
	_t.check("victory lands on world 3's first stage %d" % next, flow.state_name() == "stage" and game.run.stage == next,
			"state %s on stage %d" % [flow.state_name(), game.run.stage])


func _until(done: Callable) -> void:
	var frames := 0
	while not done.call() and frames < STATE_FRAMES:
		frames += 1
		await physics_frame
