extends SceneTree

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Spillway := preload("res://src/world/map_spillway.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const Weir := preload("res://src/world/map_weir.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")

# The stage table is chosen when the game is built. The slice table plays the Cable Reach
# as stage 1 and ends the run won at its gate with no arena; no choice keeps the three
# stages. Phases advance one physics frame at a time.

var _game
var _boss
var _phase := "slice_build"
var _won := false
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	match _phase:
		"slice_build":
			_slice_checks()
			_game.free()
			_game = Game.new()
			_game.test_mode = true
			root.add_child(_game)
			_phase = "default_build"
		"default_build":
			_default_checks()
			_game.free()
			print("stage_table_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
	return false


func _slice_checks() -> void:
	var double := SpawnerDouble.new()
	_game.add_child(double)
	double.setup(_game.ctx)
	_game.ctx.spawner = double
	_boss = BossDouble.new()
	_game.add_child(_boss)
	_boss.setup(_game.ctx)
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = Intent.Scripted.new()
	_game.events.run_ended.connect(func(won: bool): _won = won)
	_game.flow.press_start()
	_game.flow.choose_class(0)

	var flow = _game.flow
	var stage_one: Dictionary = StageDefs.of(1)
	_report("slice map", _game.ctx.terrain.maps.size() == 1 and _game.ctx.terrain.map().get_script() == Gorge,
		"slice terrain holds %d map(s), the active one is the gorge: %s" % [_game.ctx.terrain.maps.size(), _game.ctx.terrain.map().get_script() == Gorge])
	_report("slice card", _game.hud.launch_card.title == "The Cable Reach",
		"stage card reads '%s'" % _game.hud.launch_card.title)
	_report("slice scenery", _game.ctx.terrain.geometry_root(1).get_node_or_null("SpillwayScenery") == null,
		"the Reach's root carries no Spillway dam")
	var warden: Node3D = flow.warden
	if is_instance_valid(warden):
		_report("slice warden", warden.plating == stage_one["warden_plating"] and warden.max_hp == stage_one["warden_hp"],
			"warden plating %.0f hp %.0f against stage 1's %.0f and %.0f" % [warden.plating, warden.max_hp, stage_one["warden_plating"], stage_one["warden_hp"]])
	else:
		_report("slice warden", false, "no Warden stands on the slice's stage")

	flow._finish_stage()
	_report("slice ends won", flow.state_name() == "summary" and _won and _game.run.over and _boss.entries == 0,
		"after the last stage: state %s, run_ended won %s, arena entries %d" % [flow.state_name(), _won, _boss.entries])
	_report("slice no replay", not flow.can_replay_final_stage(), "can_replay_final_stage is %s" % flow.can_replay_final_stage())


func _default_checks() -> void:
	var maps: Array = _game.ctx.terrain.maps
	var order: bool = maps.size() == 3 and maps[0].get_script() == Spillway and maps[1].get_script() == Gorge and maps[2].get_script() == Weir
	_report("default maps", order, "terrain maps are spillway, gorge, weir in order: %s" % order)
	_report("default count", _game.ctx.stages.COUNT == 3 and _game.ctx.stages == StageDefs,
		"ctx.stages.COUNT is %d" % _game.ctx.stages.COUNT)
	_report("default scenery", _game.ctx.terrain.geometry_root(1).get_node_or_null("SpillwayScenery") != null,
		"the Spillway's root carries its dam")
