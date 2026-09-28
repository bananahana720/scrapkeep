extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")

# The HUD redraws only when a shown value changes (perf-lab H4). In a calm, idle scene
# the gauges, objective, ability bar, key glyphs and edge markers each draw (almost)
# nothing over a second of frames; a reading that changes draws on the next frame; an
# unchanged one, however often it is set, does not.

const WARM := 120
const WINDOW := 60

var _game
var _failures := 0
var _frame := 0
var _started := false
var _draws := {}
var _watched := {}
var _runs := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _watch(label: String, item: CanvasItem) -> void:
	_draws[label] = 0
	_watched[label] = item
	item.draw.connect(func(): _draws[label] += 1)


func _count(label: String) -> int:
	return _draws[label]


func _reset() -> void:
	for label in _draws:
		_draws[label] = 0


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_frame += 1
	var hud = _game.hud
	if _frame == 1:
		_watch("health", hud._health)
		_watch("scrap", hud._scrap)
		_watch("objective", hud._objective)
		_watch("ability_bar", hud.ability_bar)
		_watch("key_glyphs", hud.key_glyphs)
		_watch("edge_markers", hud.edge_markers)
		# A glyph that is shown follows the ball or aim point, so it legitimately redraws
		# as they move; retire them all to test the idle case.
		for action in hud.key_glyphs.ACTIONS:
			for i in 3:
				hud.profile.add_use(action)
	if _frame == WARM:
		_reset()
		_runs = hud.layout_runs
	if _frame == WARM + WINDOW:
		for label in _draws:
			_report("idle " + label, _count(label) <= 2, "%s drew %d times over %d idle frames" % [label, _count(label), WINDOW])
		_report("idle layout", hud.layout_runs == _runs, "layout ran %d times over %d idle frames" % [hud.layout_runs - _runs, WINDOW])
		_reset()
		# Same reading set again and again: no draw.
		var gauge = hud._scrap
		for i in 5:
			gauge.set_reading(-1.0, gauge.color, gauge.label, gauge.warn, gauge.warn_color)
		return false
	if _frame == WARM + WINDOW + 2:
		_report("same reading", _count("scrap") == 0, "scrap drew %d times for 5 identical readings" % _count("scrap"))
		var gauge = hud._scrap
		_runs = hud.layout_runs
		_game.run.scrap = 123456
		return false
	if _frame == WARM + WINDOW + 4:
		_report("changed reading", _count("scrap") >= 1, "scrap drew %d times after its label changed" % _count("scrap"))
		var scrap = hud._scrap
		var heft_edge: float = hud._heft.position.x + hud._heft.size.x + hud.BOTTOM_GAP
		_report("relayout on size", hud.layout_runs > _runs and absf(heft_edge - scrap.position.x) < 0.5,
			"layout ran %d times, scrap at %.1f, heft edge %.1f" % [hud.layout_runs - _runs, scrap.position.x, heft_edge])
		var health = hud._health
		health.set_reading(0.4, health.color, "", false, Color.WHITE)
		return false
	if _frame == WARM + WINDOW + 6:
		_report("changed fraction", _count("health") >= 1, "health drew %d times after its fill changed" % _count("health"))
		_reset()
		var bar = hud.ability_bar
		var slots: Array = bar.slots.duplicate(true)
		slots[0]["state"] = "cooling"
		slots[0]["cooldown_frac"] = 0.5
		bar.update_slots(slots, bar.tint, bar.motif)
		return false
	if _frame == WARM + WINDOW + 8:
		_report("changed slot", _count("ability_bar") >= 1, "ability bar drew %d times after a slot went cooling" % _count("ability_bar"))
		print("ui_redraw_gate_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	return false
