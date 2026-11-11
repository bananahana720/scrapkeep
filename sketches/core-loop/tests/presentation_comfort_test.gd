extends SceneTree

const Game := preload("res://src/game.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")

# The comfort rows (v3 W11): the pause menu's Screen shake and Hit-stop rows scale every
# camera shake, kick and punch and every freeze, and settings.json keeps them. Measured
# on the real camera and juice: the same shake, kick, punch and stop at full, at half
# (set through the menu row, as a player would) and at zero.

var _game
var _failures := 0
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null or _done:
		return false
	_done = true
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var juice = _game.presentation.juice
	var menu = _game.get_node("PauseMenu")
	var full := _measure(juice)
	menu.settings_page().row("shake").set_level(0.5)
	menu.settings_page().row("hitstop").set_level(0.5)
	var half := _measure(juice)
	menu.settings_page().row("shake").set_level(0.0)
	menu.settings_page().row("hitstop").set_level(0.0)
	var none := _measure(juice)
	_check("shake scales", is_equal_approx(half["shake"], full["shake"] * 0.5) and is_equal_approx(half["kick"], full["kick"] * 0.5)
			and is_equal_approx(half["punch"], full["punch"] * 0.5) and none["shake"] == 0.0 and none["kick"] == 0.0 and none["punch"] == 0.0,
		"shake / kick / punch at full %.2f / %.2f / %.1f, at half %.2f / %.2f / %.1f, at zero %.2f / %.2f / %.1f"
			% [full["shake"], full["kick"], full["punch"], half["shake"], half["kick"], half["punch"], none["shake"], none["kick"], none["punch"]])
	_check("hit-stop scales", is_equal_approx(half["stop"], full["stop"] * 0.5) and none["stop"] == 0.0 and full["stop"] > 0.0,
		"a 40 ms stop sends %.0f ms at full, %.0f ms at half, %.0f ms at zero" % [full["stop"] * 1000.0, half["stop"] * 1000.0, none["stop"] * 1000.0])
	var saved := SettingsStore.new(_game.storage_dir)
	juice.set_comfort("shake", 1.0)
	juice.set_comfort("hitstop", 1.0)
	menu.apply_saved()
	_check("saved and restored", saved.comfort.get("shake", -1.0) == 0.0 and saved.comfort.get("hitstop", -1.0) == 0.0
			and juice.comfort("shake") == 0.0 and juice.comfort("hitstop") == 0.0 and _game.camera.motion_scale == 0.0,
		"settings.json holds %s; after a reset to full, the saved levels put shake %.1f and hit-stop %.1f back" % [saved.comfort, juice.comfort("shake"), juice.comfort("hitstop")])
	print("presentation_comfort_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _measure(juice) -> Dictionary:
	var camera = _game.camera
	camera._shake = 0.0
	camera._kick = Vector3.ZERO
	camera._punch = 0.0
	camera.shake(0.6, 0.3)
	camera.kick(Vector3.RIGHT, 0.4)
	camera.punch_fov(6.0, 0.3)
	juice.reset_stops()
	juice.request_hit_stop(0.04, "comfort")
	var out := {"shake": camera._shake, "kick": camera._kick.length(), "punch": camera._punch, "stop": juice.hit_stop_log.back()[1]}
	camera._shake = 0.0
	camera._kick = Vector3.ZERO
	camera._punch = 0.0
	return out


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
