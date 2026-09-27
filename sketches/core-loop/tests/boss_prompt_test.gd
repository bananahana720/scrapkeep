extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const Palette := preload("res://src/core/palette.gd")

# Brindle's name plate follows the UI-regions rule: a screen-space world prompt, never
# a Label3D, anchored to the ship and to the scooter in the chase. The HUD places it
# inside the prompts band, so it never covers the objective line and nothing in the
# arena can hide it. Its colour says whether your punch beats the live plating.

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
	_report("colour carries the gap", beats == Palette.AMBER and short != Palette.AMBER and _plate().text.contains("plating 120"),
		"plate \"%s\": amber at punch 130, %s at punch 40 against plating 120" % [_plate().text, short.to_html(false)])
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


func _plate():
	for prompt in get_nodes_in_group(ScreenRegions.PROMPT_GROUP):
		if prompt.name == "BrindlePlate":
			return prompt
	return null


# The prompt exists, follows the named anchor, and lands inside the prompts band at
# both window sizes, with the camera looking at its anchor.
func _check_band(when: String, anchor: Node3D) -> void:
	var plate = _plate()
	var ok: bool = plate is WorldPrompt and plate.anchor == anchor and plate.text != ""
	var spans: Array[String] = []
	if ok:
		var ball: Vector3 = _game.player.ball_position()
		var flat := Vector3(anchor.global_position.x - ball.x, 0.0, anchor.global_position.z - ball.z)
		_game.camera.yaw = atan2(-flat.x, -flat.z)
		await physics_frame
		for size in SIZES:
			_game.hud.place_prompts(size, true)
			var band := ScreenRegions.rect("prompts", size)
			var placed: Rect2 = _game.hud.prompt_rects.get(plate, Rect2())
			var inside: bool = placed.size != Vector2.ZERO and band.encloses(placed)
			ok = ok and inside
			spans.append("%dx%d at %s in band %s: %s" % [size.x, size.y, placed, band, inside])
	_report("plate in the prompts band (%s)" % when, ok,
		"prompt \"%s\" anchored to %s; %s" % [plate.text if plate != null else "none", anchor.name if is_instance_valid(anchor) else "?", "; ".join(spans)])
