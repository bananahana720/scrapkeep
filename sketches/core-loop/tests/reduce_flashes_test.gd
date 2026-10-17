extends SceneTree

const Game := preload("res://src/game.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const T := preload("res://tests/support/t.gd")

# Reduce flashes (Andrew, design question 7, 17 Oct 2026): a saved toggle on the settings
# page that cuts the brightness of flashes and stops strobes. Measured on the real nodes:
# the hit edge flash, glyph alphas, an enemy's hit whitening, the tenacity bracket's blink,
# and FlashGuard's rate cap; plus the save round trip and launch. Rendered peak brightness
# per site comes from tools/flash_capture.gd and still_compare --peak.

var _t := T.new("reduce_flashes_test")
var _game
var _step := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_step += 1
	if _step == 1:
		_settings()
	elif _step == 2:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
	elif _step == 6:
		_sites()
		_finish()
	return false


func _settings() -> void:
	var dir: String = _game.storage_dir
	var file := dir.path_join(SettingsStore.FILE)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	_game.settings_store().load_saved()
	_game.set_reduce_flashes(false)

	# RF-1: off by default.
	_t.check("RF-1 off by default", not _game.settings_store().reduce_flashes() and not FlashGuard.on, "store and guard")

	# RF-2: the Display page row turns it on, saves it and applies it at once.
	var page = _game.get_node("PauseMenu").settings_page()
	_t.check("RF-2 the page lists a Reduce flashes row", page.row("reduce_flashes") != null, "rows")
	_t.eq("RF-2 the row reads off", page.row("reduce_flashes").text, "Reduce flashes: off")
	page.press("reduce_flashes")
	_t.eq("RF-2 the row reads on", page.row("reduce_flashes").text, "Reduce flashes: on")
	_t.check("RF-2 the store holds it and the guard is on", _game.settings_store().reduce_flashes() and FlashGuard.on, "store")
	_t.check("RF-2 reduced motion is untouched", not _game.settings_store().reduced_motion(), "separate setting")

	# RF-3: round trip through the saved file, and launch applies it.
	_t.check("RF-3 the setting round-trips through save and load", SettingsStore.new(dir).reduce_flashes(), "reloaded")
	FlashGuard.on = false
	_game.apply_saved_display(["--preset=high"])
	_t.check("RF-3 launch applies the saved setting", FlashGuard.on, "guard after launch")
	page.press("reduce_flashes")
	_t.check("RF-3 off again", not FlashGuard.on and not SettingsStore.new(dir).reduce_flashes(), "restored")
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)


func _sites() -> void:
	var edge = _game.presentation.vfx.edge
	var vfx = _game.presentation.vfx
	var ball: Vector3 = _game.player.ball_position()

	# RF-4: the hit edge flash keeps the information share, still visible.
	_game.set_reduce_flashes(false)
	edge.flash(Vector2.LEFT, Color.RED, 0.8, 0.4)
	var full: float = edge.alpha
	_game.set_reduce_flashes(true)
	edge.flash(Vector2.LEFT, Color.RED, 0.8, 0.4)
	_t.near("RF-4 edge flash keeps the information share", edge.alpha, full * FlashGuard.INFO_SHARE)
	_game.set_reduced_motion(true)
	edge.flash(Vector2.LEFT, Color.RED, 0.8, 0.4)
	_t.check("RF-4 with reduced motion too, the lower share wins and the hit still reads", absf(edge.alpha - full * SettingsStore.REDUCED_FLASH) < 0.001 and edge.alpha > 0.1, "%f" % edge.alpha)
	_game.set_reduced_motion(false)

	# RF-5: a pop glyph drops to the decorative share, a reach ring to the information share.
	_game.set_reduce_flashes(false)
	var pop_off: float = vfx.glyph("sticky_detonated", ball, 1.0, 4.0, 0.5, Vector3.ZERO, "flash").get("alpha", 0.0)
	var ring_off: float = vfx.glyph("slammed", ball, 1.0, 4.0, 0.5, Vector3.UP, "ring").get("alpha", 0.0)
	_game.set_reduce_flashes(true)
	var pop_on: float = vfx.glyph("sticky_detonated", ball, 1.0, 4.0, 0.5, Vector3.ZERO, "flash").get("alpha", 0.0)
	var ring_on: float = vfx.glyph("slammed", ball, 1.0, 4.0, 0.5, Vector3.UP, "ring").get("alpha", 0.0)
	_t.check("RF-5 a pop glyph keeps the decorative share", pop_off > 0.0 and absf(pop_on - pop_off * FlashGuard.ALPHA_SHARE) < 0.001, "%f -> %f" % [pop_off, pop_on])
	_t.check("RF-5 a reach ring keeps the information share", ring_off > 0.0 and absf(ring_on - ring_off * FlashGuard.INFO_SHARE) < 0.001, "%f -> %f" % [ring_off, ring_on])

	# RF-6: an enemy's hit flash whitens less and glows less.
	var at: Vector3 = _game.ctx.terrain.drop_point(ball.x + 8.0, ball.z, 1.0)
	var enemy = _game.ctx.spawner.spawn_enemy("chaser", at)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var lit := {}
	for mode in [false, true]:
		_game.set_reduce_flashes(mode)
		enemy.flash()
		enemy._update_flash(0.0)
		var mat: StandardMaterial3D = enemy._material
		lit[mode] = {"energy": mat.emission_energy_multiplier, "white": mat.albedo_color.b}
		enemy._flash = 0.001
		enemy._update_flash(1.0)
	var rest_blue: float = enemy._material.albedo_color.b
	_t.check("RF-6 hit glow is lower", lit[true]["energy"] < lit[false]["energy"] * 0.5 and lit[true]["energy"] > 0.0, "%s" % [lit])
	_t.check("RF-6 hit whitening is smaller but still there", lit[true]["white"] - rest_blue < (lit[false]["white"] - rest_blue) * 0.5 and lit[true]["white"] >= rest_blue, "%s rest %f" % [lit, rest_blue])

	# RF-7: the tenacity bracket's 9 Hz blink holds steady instead.
	var holds = _game.ctx.spawner.fleet.holds
	holds.immune_left = 5.0
	holds._clock = 0.8 / holds.FLICKER_HZ
	_game.set_reduce_flashes(false)
	holds._draw_bracket(ball)
	var blinked_off: bool = not holds._bracket.visible
	_game.set_reduce_flashes(true)
	holds._draw_bracket(ball)
	_t.check("RF-7 the bracket blinks off normally and holds steady with the toggle", blinked_off and holds._bracket.visible, "off-phase visible %s" % holds._bracket.visible)
	holds.immune_left = 0.0

	# RF-8: no repeating pulse over 3 Hz.
	_t.check("RF-8 the rate cap is 3 Hz", FlashGuard.rate(20.0) <= 3.0 and FlashGuard.rate(2.0) == 2.0 and FlashGuard.blink(false), "cap")
	_game.set_reduce_flashes(false)
	_t.check("RF-8 off, rates and blinks are untouched", FlashGuard.rate(20.0) == 20.0 and not FlashGuard.blink(false), "untouched")


func _finish() -> void:
	_game.set_reduce_flashes(false)
	quit(_t.verdict())
