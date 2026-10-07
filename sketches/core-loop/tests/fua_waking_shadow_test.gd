extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("fua_waking_shadow_test")
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	Harness.boot(game)
	Preset.apply("high")
	Harness.enter_world(game, 2)
	var mod = Harness.module(game, 2)
	var dress = mod._arena_dress
	if t.check("real Waking dress builds", dress != null):
		var key := dress.get_node("CoreKey") as SpotLight3D
		t.check("high keeps CoreKey shadows", key.shadow_enabled)
		Preset.apply("low")
		t.check("low disables CoreKey shadows immediately", not key.shadow_enabled)
		Preset.apply("target")
		t.check("target restores CoreKey shadows", key.shadow_enabled)
		mod.exit_arena()
		Preset.apply("low")
		Harness.enter_world(game, 2)
		dress = Harness.module(game, 2)._arena_dress
		t.check("Waking entry on low starts without CoreKey shadows", dress != null and not dress._core_key.shadow_enabled)
	game.free()
	Preset.apply("high")
	quit(t.verdict())
