extends SceneTree

const Game := preload("res://src/game.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const EdgeFlash := preload("res://src/presentation/edge_flash.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const T := preload("res://tests/support/t.gd")

# Reduce flashes (Andrew, design question 7, 17 Oct 2026): a saved toggle on the settings
# page that cuts the brightness of flashes and stops strobes. Measured on the real nodes:
# the hit edge flash, glyph alphas, an enemy's hit whitening, the tenacity bracket's blink,
# comic sound words and FlashGuard's rate cap; plus the save round trip and launch. Rendered peak brightness
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
	_t.eq("RF-2 the row reads off", page.read("reduce_flashes"), {"label": "Fewer flashes", "value": "", "pip": 0})
	page.press("reduce_flashes")
	_t.eq("RF-2 the row reads on", page.read("reduce_flashes"), {"label": "Fewer flashes", "value": "", "pip": 1})
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
	_notch(edge)

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
		lit[mode] = {"energy": mat.emission_energy_multiplier, "albedo": mat.albedo_color}
		enemy._flash = 0.001
		enemy._update_flash(1.0)
	var rest: Color = enemy._material.albedo_color
	var push_off := _distance(lit[false]["albedo"], rest)
	var push_on := _distance(lit[true]["albedo"], rest)
	_t.check("RF-6 hit glow is lower", lit[true]["energy"] < lit[false]["energy"] * 0.5 and lit[true]["energy"] > 0.0, "%s" % [lit])
	_t.check("RF-6 hit whitening keeps the white share and is still there", push_off > 0.0 and absf(push_on - push_off * FlashGuard.WHITE_SHARE) < 0.002, "push %f -> %f" % [push_off, push_on])

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

	# RF-9: comic sound words (player and machine) dim their coloured face, keep their ink outline.
	var pfx = _game.presentation.player_fx
	var mfx = _game.presentation.machine_fx
	var faces := {}
	for mode in [false, true]:
		_game.set_reduce_flashes(mode)
		for w in pfx._words:
			w["t"] = 1.0
			(w["node"] as Label3D).visible = false
		pfx._last_word = -1.0e9
		pfx._word_seen = {}
		var stamped: bool = pfx.word("wham", ball + Vector3.UP * 1.8)
		var label: Label3D = null
		for w in pfx._words:
			if w["id"] == "wham" and (w["node"] as Label3D).visible:
				label = w["node"]
		mfx.word("KLANG", ball + Vector3.UP * 2.0, Color(0.9, 0.7, 0.3), true)
		var mlabel: Label3D = mfx._words[(mfx._word_next - 1 + mfx._words.size()) % mfx._words.size()]["node"]
		faces[mode] = {"stamped": stamped, "player": label.modulate.a if label != null else -1.0, "player_ink": label.outline_modulate.a if label != null else -1.0,
			"machine": mlabel.modulate.a, "machine_ink": mlabel.outline_modulate.a}
	_t.check("RF-9 a player sound word's face keeps the information share, its outline stays", faces[false]["stamped"] and faces[true]["stamped"] \
		and absf(faces[true]["player"] - faces[false]["player"] * FlashGuard.INFO_SHARE) < 0.001 and faces[true]["player_ink"] == faces[false]["player_ink"], "%s" % [faces])
	_t.check("RF-9 a machine word's face keeps the information share, its outline stays", absf(faces[true]["machine"] - faces[false]["machine"] * FlashGuard.INFO_SHARE) < 0.001 \
		and faces[true]["machine_ink"] == faces[false]["machine_ink"], "%s" % [faces])

	# RF-8: no repeating pulse over 3 Hz.
	_t.check("RF-8 the rate cap is 3 Hz", FlashGuard.rate(20.0) <= 3.0 and FlashGuard.rate(2.0) == 2.0 and FlashGuard.blink(false), "cap")
	_game.set_reduce_flashes(false)
	_t.check("RF-8 off, every helper returns its input", FlashGuard.rate(20.0) == 20.0 and not FlashGuard.blink(false) and FlashGuard.alpha(0.8) == 0.8 \
		and FlashGuard.info(0.8) == 0.8 and FlashGuard.spike(1.0, 4.0) == 4.0 and FlashGuard.whiten(0.6) == 0.6 and FlashGuard.period(0.05) == 0.05, "identity")


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _finish() -> void:
	_game.set_reduce_flashes(false)
	quit(_t.verdict())


# RF-4b (FX-06): the flash dims, but a hit from a known side also gets a steady ink notch on that
# edge, the same NOTCH_S in every mode, inside the screen with its tip on the edge toward the
# source. An unknown source flashes every edge and draws no notch.
func _notch(edge) -> void:
	var shown := []
	for mode in [[false, false], [true, false], [false, true], [true, true]]:
		_game.set_reduce_flashes(mode[0])
		_game.set_reduced_motion(mode[1])
		edge.flash(Vector2.LEFT, Color.RED, 0.3, 0.4)
		edge._process(EdgeFlash.NOTCH_S - 0.05)
		var held: bool = edge.notch_shown()
		edge._process(0.06)
		shown.append([held, edge.notch_shown()])
	_game.set_reduce_flashes(false)
	_game.set_reduced_motion(false)
	_t.eq("RF-4b the notch holds NOTCH_S in every mode, then clears", shown, [[true, false], [true, false], [true, false], [true, false]])
	edge.flash(Vector2.ZERO, Color.RED, 0.3, 0.4)
	_t.check("RF-4b an unknown source draws no notch", not edge.notch_shown())
	var view := Vector2(1600, 900)
	var inside := Rect2(Vector2.ZERO, view)
	var placed := true
	for toward in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(1, -1), Vector2(-3, 1), Vector2(0.2, 1)]:
		var wedge: PackedVector2Array = EdgeFlash.notch_points(toward, view)
		var tip := wedge[0]
		var on_edge := minf(minf(tip.x, view.x - tip.x), minf(tip.y, view.y - tip.y)) <= EdgeFlash.NOTCH_INSET + 0.5
		var facing := (tip - view * 0.5).normalized().dot(toward.normalized()) > 0.7
		placed = placed and on_edge and facing and Array(wedge).all(func(p): return inside.grow(0.5).has_point(p))
	_t.check("RF-4b the notch's tip sits on the edge toward the source, the wedge on screen", placed)

