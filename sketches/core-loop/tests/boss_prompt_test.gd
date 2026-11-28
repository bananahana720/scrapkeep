extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const ScreenRegions := preload("res://src/core/screen_regions.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const Palette := preload("res://src/core/palette.gd")

# Brindle's internal readout prompt is a WorldPrompt, never a Label3D, anchored to the ship
# and to the scooter in the chase. Its text and colour still track live plating for telemetry
# and tests, while owner_placed=true and visible=false keep hud.place_prompts() from drawing
# truncated "BRINDLE · plating/bow/on" text in the prompts band over the player ball (PF-54;
# BossPlate owns Brindle's HUD readout).

const SIZES := [Vector2(1600.0, 900.0), Vector2(1280.0, 720.0)]

var _game
var _double
var _boss
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_double = Harness.install(_game)
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	for _i in 10:
		await physics_frame
	var labels: Array = _boss.ship.find_children("*", "Label3D", true, false)
	_report("no 3D readout", labels.is_empty(), "the ship carries %d Label3D nodes" % labels.size())
	await _check_band("fight", _boss.ship)
	if _plate() == null:
		_finish()
		return
	_double.punch_override = 130.0
	await physics_frame
	var beats: Color = _plate().get_theme_color("font_color")
	_double.punch_override = 40.0
	await physics_frame
	var short: Color = _plate().get_theme_color("font_color")
	_double.punch_override = -1.0
	# Re-pinned 2026-10-15 (BRINDLE-SCUTTLE merge): hull plating 120 to 110 in boss_rules.gd; punch 130 and 40 still sit either side.
	_report("colour carries the gap", beats == Palette.AMBER and short != Palette.AMBER and _plate().text.contains("plating 110"),
		"plate \"%s\": amber at punch 130, %s at punch 40 against plating 110" % [_plate().text, short.to_html(false)])
	_check_shred()
	await _check_shred_charging()
	_boss.jump_to_phase(4)
	while not _boss.scooter_landed():
		await physics_frame
	await physics_frame
	await _check_band("chase", _boss.scooter)
	_finish()


func _finish() -> void:
	print("boss_prompt_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


# Ruling (coordinator, 2026-10-04, veto-listed for Andrew): decision row 107, no shred on
# a posture body, wins over the 2026-09-27 rule that combat's shred strips the hull's
# plating. Brindle's hull is a posture body (F2a), so rams through the game's own
# combat module build no shred and the plate holds at 120, the number the tint uses.
func _check_shred() -> void:
	var hull = _boss.ship.hull
	var real = _game.combat
	_game.ctx.spawner = real
	for _i in 8:
		real.strike(hull, "ram", 40.0)
	var shred: float = real.shred_of(hull)
	var got: float = _boss.hull_plating_now()
	_boss._update_readout()
	var text: String = _plate().text
	_report("plate holds under rams", shred == 0.0 and absf(got - 110.0) < 0.01 and text.contains("plating 110"),
		"after 8 ram strikes shred %.2f: hull_plating_now %.2f (want 110), plate \"%s\"" % [shred, got, text])
	_game.ctx.spawner = _double


# The bow's 150 while charging must drop under shred exactly as the hull's 120 does,
# and the plate, the objective's clash line and the ram-only tint must all agree on
# the same shredded number (Andrew's fix wave, 2026-09-27). Enter phase 3, let
# Brindle's own charge sequence reach "run" (never force the state directly, since its
# dict carries a live hazard _run_charge depends on), shred the hull fresh right as it
# starts, then read a ram punch set directly on the ball's state (no teleport, so the
# charge lane and its decay clock are undisturbed) that sits strictly between the
# shredded and the raw plating, the one value that tells the old, unfixed comparison
# "slate" and the fixed one "amber".
func _check_shred_charging() -> void:
	_boss.jump_to_phase(3)
	var charging_now := false
	for _i in 400:
		await physics_frame
		if _boss.charging():
			charging_now = true
			break
	var hull = _boss.ship.hull
	var real = _game.combat
	_game.ctx.spawner = real
	real.heft_override = 1.0
	for _i in 8:
		real.strike(hull, "ram", 40.0)
	var shred: float = real.shred_of(hull)
	var want: float = maxf(0.0, 150.0 - shred)
	var punch := (want + 150.0) * 0.5
	var force := (punch - 14.0) / 1.3
	_game.player.state.velocity = Vector3(force, 0.0, 0.0)
	_game.player.state.tier = 1
	var got: float = _boss.hull_plating_now()
	var tint: String = _boss.tint_for(hull, "slate")
	_boss._update_readout()
	var plate_text: String = _plate().text
	var objective: String = _boss.objective_text()
	var want_int := int(want)
	_report("charging plate, objective and tint agree under shred",
		charging_now and absf(got - want) < 0.01 and tint == "amber"
			and plate_text.contains("bow plating %d" % want_int)
			and objective.contains("bow plating %d" % want_int),
		"charging %s, shred %.2f, want %.2f: hull_plating_now %.2f, tint %s, plate \"%s\", objective \"%s\" (test ram punch %.1f)"
			% [charging_now, shred, want, got, tint, plate_text, objective, punch])
	_game.player.state.velocity = Vector3.ZERO
	_game.player.state.tier = 0
	real.heft_override = -1.0
	_game.ctx.spawner = _double


func _plate():
	for prompt in get_nodes_in_group(ScreenRegions.PROMPT_GROUP):
		if prompt.name == "BrindlePlate":
			return prompt
	return null


# The prompt exists, follows the named anchor, stays owner_placed and hidden, and is never
# placed in the prompts band at either window size (PF-54).
func _check_band(when: String, anchor: Node3D) -> void:
	var plate = _plate()
	var ok: bool = plate is WorldPrompt and plate.anchor == anchor and plate.text != "" and plate.owner_placed and not plate.visible
	var spans: Array[String] = []
	if ok:
		var ball: Vector3 = _game.player.ball_position()
		var flat := Vector3(anchor.global_position.x - ball.x, 0.0, anchor.global_position.z - ball.z)
		_game.camera.yaw = atan2(-flat.x, -flat.z)
		await physics_frame
		for size in SIZES:
			_game.hud.place_prompts(size, true)
			var suppressed: bool = not _game.hud.prompt_rects.has(plate) and not plate.visible
			ok = ok and suppressed
			spans.append("%dx%d owner_placed=%s visible=%s in_rects=%s" % [size.x, size.y, plate.owner_placed, plate.visible, _game.hud.prompt_rects.has(plate)])
	_report("plate stays off the prompts band (%s)" % when, ok,
		"prompt \"%s\" anchored to %s; %s" % [plate.text if plate != null else "none", anchor.name if is_instance_valid(anchor) else "?", "; ".join(spans)])
