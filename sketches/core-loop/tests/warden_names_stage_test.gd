extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# The Warden's name through the real wiring (alpha_defs.gd warden_variant -> fleet.dress ->
# warden.gd variant -> the plate): the flow spawns each world 1 stage's Warden and the plate bound
# to it reads the dam's as "Reactor Warden" and the flume's as "Meltdown Warden" (its card's name).
# Evidence limit: names and wiring, not how the plate looks.

var _game
var _t := T.new("warden_names_stage_test")
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	_game.player.source = Intent.Scripted.new()
	_run()
	return false


func _run() -> void:
	await physics_frame
	Harness.start_run(_game)
	for want in [{"stage": 1, "variant": "", "name": "Reactor Warden"}, {"stage": 2, "variant": "meltdown", "name": "Meltdown Warden"}]:
		_game.flow.enter_stage(int(want.stage), Vector3(0.0, 0.0, 16.0), false)
		await physics_frame
		await physics_frame
		var warden = _game.flow.warden
		_t.check("stage %d spawns its Warden" % want.stage, is_instance_valid(warden), "warden %s" % [warden])
		if not is_instance_valid(warden):
			continue
		_t.eq("stage %d's def sets variant '%s'" % [want.stage, want.variant], [String(_game.flow.stage_def().get("warden_variant", "?")), warden.variant], [want.variant, want.variant])
		var plate := BossPlate.new()
		plate.bind(warden)
		_t.eq("stage %d's plate reads %s" % [want.stage, want.name], plate.plate_name(), want.name)
		plate.free()
	var code: int = _t.verdict()
	_game.free()
	quit(code)
