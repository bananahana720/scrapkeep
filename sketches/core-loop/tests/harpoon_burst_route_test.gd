extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

# --harpoon-keys=shift routes Shift to the class burst only when the burst rule can take the
# press this tick; otherwise Shift stays the plain boost (DESIGN-NOTES "harpoon-keys"):
#   Rivet   already sprinting with a ready charge: the press is a boost, not a swallowed burst
#   Kest    planted by a slam with a ready blink: the press is the plant's held boost and fires
#           the tick the plant lets go
#   Rivet   not sprinting with a ready charge: Shift still starts the sprint (the routing survives)
# Evidence limit: rules through real physics from a placed start, not a player's run.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _failures := 0
var _game
var _player
var _source := Intent.Scripted.new()
var _counts := {"boosted": 0, "sprint_started": 0, "blink_used": 0}


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _pilot(class_id: String) -> void:
	var def: Resource = ClassDef.by_id(class_id)
	_game.tuning.set_option("harpoon", "shot")
	_game.tuning.set_option("harpoon_keys", "shift")
	_game.run.class_def = def
	_player.fit_class(def)
	_player.abilities.refill()
	_source.hold = {}
	_source.press = {}
	var at: Vector3 = _game.ctx.terrain.drop_point(FLAT_SHELF.x, FLAT_SHELF.z, 3.0)
	_player.reset_to(at, Vector3(0, 0, -6))
	for kind in _counts:
		_counts[kind] = 0


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	_game.run.set_max_hp(99999.0)
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.get("kind") in ["warden", "vault"]:
			enemy.queue_free()
	for kind in _counts:
		var tally := func(): _counts[kind] += 1
		var arity: int = {"boosted": 1, "sprint_started": 1, "blink_used": 2}[kind]
		_game.events.get(kind).connect(tally.unbind(arity))

	_pilot("runner_gunner")
	_source.hold = {"movement_held": true}
	_source.press = {"boost_pressed": true}
	await _sim(0.1)
	var sprinting: bool = _player.kit.sprinting
	_check("rivet: Shift starts the sprint when it can", sprinting and _counts["sprint_started"] == 1 and _counts["boosted"] == 0,
		"sprinting %s, sprint_started %d, boosts %d" % [sprinting, _counts["sprint_started"], _counts["boosted"]])
	_player.refresh_air()
	_counts["boosted"] = 0
	_counts["sprint_started"] = 0
	var ready: bool = _player.abilities.ready(AbilityState.MOVEMENT)
	_source.press = {"boost_pressed": true}
	await _sim(0.1)
	_check("rivet: Shift mid-sprint with a ready charge is the plain boost",
		ready and _player.kit.sprinting and _counts["boosted"] == 1 and _counts["sprint_started"] == 0,
		"charge ready %s, sprinting %s, boosts %d, sprint restarts %d" % [ready, _player.kit.sprinting, _counts["boosted"], _counts["sprint_started"]])

	_pilot("demolitions_caster")
	var kit = _player.kit
	await _sim(0.3)
	kit.plant_time = 0.3
	kit.plant_total = 0.3
	kit.plant_at = _player.ball_position()
	kit.plant_exit = Vector3.ZERO
	kit.plant_normal = Vector3.UP
	kit.plant_boost = false
	kit.plant_jump = false
	_counts["boosted"] = 0
	_counts["blink_used"] = 0
	var blink_ready: bool = _player.abilities.ready(AbilityState.MOVEMENT)
	_source.press = {"boost_pressed": true}
	await physics_frame
	var held: bool = kit.plant_boost
	await _sim(0.6)
	_check("kest: Shift while planted is the held boost, fired when the plant lets go",
		blink_ready and held and _counts["boosted"] == 1 and _counts["blink_used"] == 0,
		"blink ready %s, plant_boost held %s, boosts %d, blinks %d" % [blink_ready, held, _counts["boosted"], _counts["blink_used"]])

	_game.free()
	print("harpoon_burst_route_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(_failures)
