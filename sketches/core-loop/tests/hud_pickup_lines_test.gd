extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const Panels := preload("res://src/build/panels.gd")
const PanelFx := preload("res://src/presentation/panel_fx.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const T := preload("res://tests/support/t.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# W1-11 (PF-14): a grey panel's pickup line rises at the HUD's edge, not over the fight. On a real
# game in play, two pickups in a row:
#   - both lines show in the HUD's pickup lines inside POP_LIFE of the pickup (PF-19), on two rows;
#   - the column sits on the bottom band's top edge at the left, inside the screen and out of
#     the top, toasts and bottom bands, and clear of the ball and the reticle;
#   - no machine word is stamped for the pickup (the old pop at the ball is gone);
#   - a prompt opened in the band's lower left while the lines show stands clear of them;
#   - the lines have gone after POP_LIFE.
# The planted control: a column seated where the old pop stood (over the ball) must fail the
# keep-clear check.

var _t := T.new("hud_pickup_lines_test")
var _game
var _hud
var _phase := "boot"
var _wait := 0
var _words_before := 0
var _anchor: Node3D
var _since := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


# The ball's square on screen, as the HUD's marks keep clear of it.
func _ball_rect() -> Rect2:
	var cam: Camera3D = _game.camera.cam
	var at: Vector3 = _game.player.shown_position()
	if cam.is_position_behind(at):
		return Rect2()
	var centre := cam.unproject_position(at)
	var half := centre.distance_to(cam.unproject_position(at + cam.global_basis.x * Tuning.RADIUS))
	return Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)


func _clear(rect: Rect2, size: Vector2) -> bool:
	var ring: Rect2 = _hud.part_name.avoid
	var ball: Rect2 = _ball_rect()
	return not rect.intersects(ring) and not (ball.has_area() and rect.intersects(ball)) \
		and ["top", "toasts", "bottom"].all(func(b): return not rect.intersects(ScreenRegions.rect(b, size))) \
		and Rect2(Vector2.ZERO, size).encloses(rect)


func _process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	_since += delta
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_hud = _game.get_node("Hud")
			_phase = "settle"
			_wait = 0
		"settle":
			if _wait == 10:
				_words_before = int(_game.presentation.machine_fx.spawned.get("word", 0))
				var ids: Array = Panels.ids()
				_game.events.panel_gained.emit(ids[0], 1, _game.player.shown_position(), false)
				_game.events.panel_gained.emit(ids[1], 1, _game.player.shown_position(), true)
				_phase = "shown"
				_wait = 0
		"shown":
			if _wait == 6:
				_check_shown()
				_open_prompt()
				_phase = "prompt"
				_wait = 0
		"prompt":
			if _wait == 3:
				_check_prompt()
				_phase = "gone"
				_since = 0.0
		"gone":
			if _since >= PanelFx.POP_LIFE + 0.2:
				_t.check("the lines have gone after their life", not _hud.pickup_lines.showing() and not _hud.pickup_lines.rect().has_area(),
					"lines %s" % [_hud.pickup_lines.drawn_words()])
				quit(_t.verdict())
				return true
	return false


func _check_shown() -> void:
	var size: Vector2 = _hud._screen_size()
	var lines: Control = _hud.pickup_lines
	var words: PackedStringArray = lines.drawn_words()
	var ids: Array = Panels.ids()
	_t.check("both pickups show as lines at the HUD's edge", words.size() == 2 and Panels.pop_text(ids[0]) in words and Panels.pop_text(ids[1]) in words, "%s" % [words])
	_t.check("they take two rows", lines.lines.map(func(l): return int(l[2])) == [0, 1], "%s" % [lines.lines])
	var rect: Rect2 = lines.rect()
	var bottom := ScreenRegions.rect("bottom", size)
	_t.check("the column sits on the bottom band's top edge at the left", rect.has_area() and rect.end.y <= bottom.position.y and bottom.position.y - rect.end.y <= 8.0
		and rect.position.x < size.x * 0.1, "column %s, bottom band %s" % [rect, bottom])
	_t.check("the column is clear of the ball, the reticle and the other bands", _clear(rect, size), "column %s ball %s reticle %s" % [rect, _ball_rect(), _hud.part_name.avoid])
	var words_now := int(_game.presentation.machine_fx.spawned.get("word", 0))
	_t.eq("no word is stamped at the ball for the pickup", words_now, _words_before)
	# The planted control: the old place, a column standing over the ball.
	var ball: Rect2 = _ball_rect()
	var old := Rect2(ball.get_center() - Vector2(lines.size.x * 0.5, lines.size.y + ball.size.y * 0.5), lines.size)
	_t.check("planted: a column over the ball fails the keep-clear check", ball.has_area() and not _clear(old.grow(ball.size.y), size), "old %s" % old)


# A prompt whose anchor projects into the lines' corner of the prompts band.
func _open_prompt() -> void:
	var cam: Camera3D = _game.camera.cam
	var size: Vector2 = _hud._screen_size()
	var rect: Rect2 = _hud.pickup_lines.rect()
	var target := Vector2(rect.get_center().x, rect.position.y + 4.0)
	_anchor = Node3D.new()
	_game.ctx.root.add_child(_anchor)
	_anchor.global_position = cam.project_position(target, 12.0)
	var prompt := WorldPrompt.new()
	prompt.set_parts("Corner prompt", "")
	prompt.attach(_anchor, Vector3.ZERO, 200.0)
	_anchor.add_child(prompt)
	_t.check("the probe's anchor lands in the lines' corner", ScreenRegions.rect("prompts", size).has_point(target), "target %s" % target)


func _check_prompt() -> void:
	var rect: Rect2 = _hud.pickup_lines.rect()
	var placed: Array = _hud.prompt_rects.keys().filter(func(p): return p.get_parent() == _anchor)
	_t.check("a prompt in the lines' corner stands clear of them", placed.size() == 1 and not (_hud.prompt_rects[placed[0]] as Rect2).intersects(rect),
		"prompt %s, lines %s" % [placed.map(func(p): return _hud.prompt_rects[p]), rect])
