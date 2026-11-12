extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")

# SR6 damage numbers (W13-INTEGRATION-3). A number and a hit effect take one colour per
# damage type and team from one table, every colour is a Palette row (no new meaning colour),
# numbers on one target merge inside a short window, and at 20 hits per second the visible
# numbers stay under the declared cap. The HUD layer is fed by the real events.
# Comps note: ror2/characters-and-feel (damage numbers coloured by type and team; the merge
# window is not in the code searched, so MERGE_WINDOW_S is this unit's start value).

const HITS_PER_SECOND := 20
const STEP := 1.0 / 60.0
const SETTLE_TICKS := 300

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_pure_checks()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _palette_values() -> Array:
	var values: Array = []
	var script: GDScript = Palette
	var map: Dictionary = script.get_script_constant_map()
	for name in map:
		if map[name] is Color:
			values.append(map[name])
	return values


func _pure_checks() -> void:
	# FX-02: every figure wears an ink outline three tenths of its size, so copper reads on sand.
	_report("a figure's ink outline grows with it and never thins under the floor",
		DamageNumbers.outline_px(DamageNumbers.FONT) == DamageNumbers.OUTLINE_MIN
		and DamageNumbers.outline_px(DamageNumbers.MEGA_FONT) == 18,
		"%d at %d pt, %d at %d pt" % [DamageNumbers.outline_px(DamageNumbers.FONT), DamageNumbers.FONT,
			DamageNumbers.outline_px(DamageNumbers.MEGA_FONT), DamageNumbers.MEGA_FONT])
	var rows := _palette_values()
	var pairs := 0
	var mismatches := 0
	var off_palette := 0
	for type in DamageNumbers.TYPES:
		for team in DamageNumbers.TEAMS:
			pairs += 1
			var layer = DamageNumbers.new()
			layer.add("t", 5.0, Vector2.ZERO, type, team)
			var shown: Array = layer.shown()
			var number_colour: Color = shown[0]["color"]
			if shown.size() != 1 or number_colour != DamageNumbers.effect_colour(type, team):
				mismatches += 1
			if not number_colour in rows:
				off_palette += 1
			layer.free()
	_report("colour agreement", pairs == DamageNumbers.TYPES.size() * DamageNumbers.TEAMS.size() and pairs >= 9 and mismatches == 0,
		"%d type x team pairs, %d number/effect colour mismatches" % [pairs, mismatches])
	_report("palette rows only", off_palette == 0, "%d pair colours outside palette.gd rows" % off_palette)
	_report("today's strike effect", EventKinds.color("enemy_struck") == DamageNumbers.effect_colour("kinetic", "player"),
		"enemy_struck burst colour equals the kinetic/player number colour")
	_report("team reads apart", DamageNumbers.effect_colour("kinetic", "player") != DamageNumbers.effect_colour("kinetic", "monster"),
		"the same type reads differently for player and monster")
	var taken_mismatches := 0
	for type in DamageNumbers.TYPES:
		for team in ["monster", "neutral"]:
			if DamageNumbers.effect_colour(type, team) != EventKinds.juice("player_hit")["color"]:
				taken_mismatches += 1
	_report("hit-taken row", taken_mismatches == 0,
		"6 hit-taken type/team pairs: %d mismatches against the player_hit juice colour" % taken_mismatches)
	_report("kind map", DamageNumbers.type_of_kind("arc") == "arc" and DamageNumbers.type_of_kind("ram") == "kinetic",
		"arc strike -> arc, ram -> kinetic")

	var one = DamageNumbers.new()
	var total := 0.0
	var seconds := 2.0
	for i in int(seconds * HITS_PER_SECOND):
		one.add("boss", 3.0, Vector2(100.0, 100.0), "kinetic", "player")
		total += 3.0
		one.step(1.0 / HITS_PER_SECOND)
	var shown_one: Array = one.shown()
	var sum := 0.0
	for entry in shown_one:
		sum += float(entry["value"])
	_report("merge", shown_one.size() == 1 and is_equal_approx(sum, total),
		"%d hits on one target in %.0f s show %d number(s) summing to %.0f of %.0f" % [int(seconds * HITS_PER_SECOND), seconds, shown_one.size(), sum, total])
	one.step(DamageNumbers.MERGE_WINDOW_S + DamageNumbers.LIFE_S)
	_report("expiry", one.visible_count() == 0, "numbers expire after %.2f s" % DamageNumbers.LIFE_S)
	one.free()

	var wide = DamageNumbers.new()
	var peak := 0
	var targets := 40
	for i in int(5.0 * HITS_PER_SECOND):
		wide.add("t%d" % (i % targets), 2.0 + (i % 7), Vector2(50.0 + i, 80.0), "kinetic", "player")
		wide.step(1.0 / HITS_PER_SECOND)
		peak = maxi(peak, wide.visible_count())
	_report("visible cap", peak <= DamageNumbers.MAX_VISIBLE and peak > 1,
		"20 hits per second on %d targets for 5 s: peak %d visible, cap %d" % [targets, peak, DamageNumbers.MAX_VISIBLE])
	wide.free()


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_wait += 1
	if _phase == "boot":
		var source := Intent.Scripted.new()
		_game.player.source = source
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_phase = "settle"
		_wait = 0
	elif _phase == "settle" and _wait == SETTLE_TICKS:
		_hud_checks()
		print("damage_numbers_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	return false


func _hud_checks() -> void:
	var layer = _game.hud.damage_numbers
	_report("hud layer", layer != null and layer.get_parent() == _game.hud and layer.visible_count() == 0, "the HUD mounts one damage-number layer, empty at rest")
	_game.events.player_hit.emit(7.0, "cutter")
	var taken: Array = layer.shown()
	_report("hit taken", taken.size() == 1 and taken[0]["color"] == DamageNumbers.effect_colour("kinetic", "monster"),
		"player_hit shows %d number in the monster/kinetic colour" % taken.size())
	var warden = _game.flow.warden
	var before: int = layer.visible_count()
	_game.ctx.spawner.strike(warden, "arc", 1.0)
	_report("glancing hit", layer.visible_count() == before, "an arc strike the Warden's plating turns away adds no number (%d -> %d)" % [before, layer.visible_count()])
	var target := Node3D.new()
	_game.add_child(target)
	target.global_position = _game.player.ball_position() + Vector3(0.0, 0.0, -4.0)
	_game.events.enemy_struck.emit(target, "arc", 30.0)
	_game.presentation.juice.flush()
	var dealt: Array = layer.shown()
	var arc_ok = dealt.size() == before + 1 and dealt[dealt.size() - 1]["color"] == DamageNumbers.effect_colour("arc", "player")
	_report("hit dealt", arc_ok, "an arc strike on a plain target adds one arc/player number (%d -> %d)" % [before, dealt.size()])
	_live_colour_checks(layer)


# The colour juice.gd actually hands the effect layer (a recorder in place of vfx) against the
# colour of the number the same event leaves on the HUD layer. Neither side reads the table
# the other one does, so a change to either colour shows here.
class Recorder:
	extends RefCounted
	var fx_tint := []
	var flash_tint := []

	func play_fx(_kind: String, _at: Vector3, tint := Color.TRANSPARENT, _variant := "", _toward := Vector3.ZERO) -> void:
		fx_tint.append(tint)

	func edge_flash(_direction: Vector2, color: Color, _strength: float, _seconds: float) -> void:
		flash_tint.append(color)


func _live_colour_checks(layer) -> void:
	var juice = _game.presentation.juice
	var real_vfx = juice.vfx
	var real_resolve: Callable = juice.resolve_of
	var real_plating: Callable = juice.plating_of
	var rec := Recorder.new()
	juice.vfx = rec
	var cases := 0
	var mismatches := 0
	var taken_row_mismatches := 0
	var detail := ""
	# kind, crit by size, crit by weak point
	for kind in ["burst", "arc", "frost"]:
		for mode in ["plain", "big", "weak"]:
			var target := Node3D.new()
			_game.add_child(target)
			target.global_position = _game.player.ball_position() + Vector3(0.0, 0.0, -4.0)
			var dealt := 12.0 * (2.0 if mode == "big" else 1.0)
			juice.resolve_of = func(_e, _k, _f): return {"dealt": dealt, "punch": 12.0, "full": true, "part": "head" if mode == "weak" else "", "plating": 1.0}
			juice.plating_of = func(_e): return 5.0
			layer.clear()
			rec.fx_tint.clear()
			_game.events.enemy_struck.emit(target, kind, 12.0)
			juice.flush()
			cases += 1
			var shown: Array = layer.shown()
			var want_crit: bool = mode != "plain"
			if shown.size() != 1 or rec.fx_tint.size() != 1 or shown[0]["color"] != rec.fx_tint[0] or bool(shown[0]["crit"]) != want_crit:
				mismatches += 1
				detail += " %s/%s" % [kind, mode]
			target.queue_free()
	for source in ["cutter", ""]:
		layer.clear()
		rec.flash_tint.clear()
		_game.events.player_hit.emit(7.0, source)
		cases += 1
		var shown_taken: Array = layer.shown()
		if shown_taken.size() != 1 or rec.flash_tint.size() != 1 or shown_taken[0]["color"] != rec.flash_tint[0]:
			mismatches += 1
			detail += " taken/%s" % source
		if shown_taken.size() != 1 or rec.flash_tint.size() != 1 or shown_taken[0]["color"] != EventKinds.juice("player_hit")["color"] or rec.flash_tint[0] != EventKinds.juice("player_hit")["color"]:
			taken_row_mismatches += 1
	juice.vfx = real_vfx
	juice.resolve_of = real_resolve
	juice.plating_of = real_plating
	_report("live colour agreement", cases == 11 and mismatches == 0,
		"%d live events (3 strike kinds x plain, size crit, weak-point crit, 2 hits taken): %d number/effect colour mismatches%s" % [cases, mismatches, detail])
	_report("live hit-taken row", taken_row_mismatches == 0,
		"2 recorded hit-taken events: %d number/flash mismatches against the player_hit juice colour" % taken_row_mismatches)
