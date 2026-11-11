extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The two lessons no verb prompt carries (FIRST-TIMER audit, scripts/first-timer.mjs): the drive
# keys at the ball on a new save's first drops, and the slam on a Warden's open core. Each wears
# the key glyph's sand cap and the live colour like ui/key_glyphs.gd and retires the same way,
# after RETIRE_AFTER uses on the profile (ui_profile.gd glyph_uses).
#
#   roll  W A S D (the stick on a pad) and DRIVE beside the ball, from the drop until the run has
#         DRIVE_LEARNED seconds of steering; a run that gets there is one use. It never shows once
#         the stage's Warden is engaged, so a fight keeps its word budget (ui_word_budget_test).
#   slam  while the Warden is staggered: Space Ctrl SLAM over the core on the ground (jump, then
#         slam), Ctrl SLAM alone in the air. A slam within SLAM_REACH of the open core is one use.
#
# The drive row ends left of the ball so the ball verbs' prompts (key_glyphs BALL_OFFSET, to the
# right) stay clear; the slam row is centred over the core. Rules run on the physics tick, the
# screen placement in _process, redrawn only when it changes, as key_glyphs does.
#
# Each lesson emits events.prompt_shown on its rising edge, as the verb prompts do.

const RETIRE_AFTER := {"roll": 3, "slam": 3}
const DRIVE_LEARNED := 1.5
const STEER_DEADZONE := 0.3
const DRIVE_ACTIONS := ["cl_forward", "cl_left", "cl_back", "cl_right"]
const DRIVE_WORD := "DRIVE"
const SLAM_WORD := "SLAM"
const CORE_LIFT := Vector3(0.0, 3.0, 0.0)
const SLAM_REACH := 8.0
# The drive row's right end, from the ball: mirrors key_glyphs.BALL_OFFSET to the left.
const BALL_OFFSET := Vector2(-24.0, -34.0)
const KEY_H := 28.0
const GAP := 6.0
const WORD_SIZE := UiTokens.BODY

var game
var profile
# The lessons shown this tick: [{id, world, offset, align ("end" or "centre"), parts: [{key} or {word}]}].
var shown: Array = []
var _placed: Array = []
var _steered := 0.0
var _drive_done := false
var _was_drawn := {}


func setup(game_ref, profile_ref) -> void:
	game = game_ref
	profile = profile_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.events.run_started.connect(func(_class_id: String): new_run())
	game.events.slammed.connect(func(at: Vector3, _strength: float, _flatness: float):
		if game.flow.in_play() and core_open() and at.distance_to(game.flow.warden.global_position) <= SLAM_REACH:
			profile.add_use("slam"))


func new_run() -> void:
	_steered = 0.0
	_drive_done = false
	shown = []
	_was_drawn = {}


func retired(id: String) -> bool:
	return profile.uses(id) >= RETIRE_AFTER[id]


# The flow's Warden is staggered: its core is open to a smash.
func core_open() -> bool:
	var warden = game.flow.warden if is_instance_valid(game.flow.warden) else null
	return warden != null and warden.has_method("staggered") and warden.staggered()


func step(delta: float) -> void:
	shown = []
	if game == null or not game.flow.in_play():
		_was_drawn = {}
		return
	var player = game.player
	if not _drive_done and not retired("roll") and not game.flow.engaged():
		if player.intent.move.length() > STEER_DEADZONE:
			_steered += delta
		if _steered >= DRIVE_LEARNED:
			_drive_done = true
			profile.add_use("roll")
		else:
			_add("roll", player.shown_position(), BALL_OFFSET, "end", _drive_parts())
	if core_open() and not retired("slam"):
		var parts: Array = [{"key": Glyphs.of("haul")}, {"word": SLAM_WORD}]
		if player.state.grounded:
			parts.push_front({"key": Glyphs.of("jump")})
		_add("slam", game.flow.warden.global_position + CORE_LIFT, Vector2.ZERO, "centre", parts)
	var drawn_now := {}
	for lesson in shown:
		drawn_now[lesson["id"]] = true
		if not _was_drawn.has(lesson["id"]):
			game.events.prompt_shown.emit(lesson["id"])
	_was_drawn = drawn_now


# The four drive keys as bound on the keyboard, or the one stick glyph on a pad.
func _drive_parts() -> Array:
	var parts: Array = []
	if Glyphs.is_pad():
		parts.append({"key": Glyphs.of("roll")})
	else:
		for action in DRIVE_ACTIONS:
			parts.append({"key": Glyphs.of_action(action, "key_w")})
	parts.append({"word": DRIVE_WORD})
	return parts


# Shows a lesson only where its anchor is in front of the camera and inside the view.
func _add(id: String, world: Vector3, offset: Vector2, align: String, parts: Array) -> void:
	var camera = game.get("camera")
	if camera != null:
		var cam: Camera3D = camera.cam
		if cam.is_position_behind(world) or not cam.get_viewport().get_visible_rect().has_point(cam.unproject_position(world)):
			return
	shown.append({"id": id, "world": world, "offset": offset, "align": align, "parts": parts})


static func row_width(parts: Array) -> float:
	var w := 0.0
	for part in parts:
		w += Keycap.size_of(part["key"], KEY_H).x + GAP if part.has("key") else UiFonts.width(part["word"], WORD_SIZE) + GAP * 2.0
	return w - GAP


func shown_ids() -> Array[String]:
	var out: Array[String] = []
	for lesson in shown:
		out.append(lesson["id"])
	return out


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if not visible:
		return out
	for lesson in shown:
		for part in lesson["parts"]:
			out.append_array(Keycap.words(part["key"]) if part.has("key") else PackedStringArray([part["word"]]))
	return out


func _physics_process(delta: float) -> void:
	step(delta)


# Where each shown lesson's row starts on screen: [{at, parts}].
func _placements() -> Array:
	var out := []
	var camera = game.get("camera") if game != null else null
	if camera == null:
		return out
	var cam: Camera3D = camera.cam
	for lesson in shown:
		if cam.is_position_behind(lesson["world"]):
			continue
		var at: Vector2 = cam.unproject_position(lesson["world"]) + lesson["offset"]
		at.x -= row_width(lesson["parts"]) * (1.0 if lesson["align"] == "end" else 0.5)
		out.append({"at": at.round(), "parts": lesson["parts"]})
	return out


func _process(_delta: float) -> void:
	var now := _placements()
	if now != _placed:
		_placed = now
		queue_redraw()


func _draw() -> void:
	var cap_color: Color = EventKinds.UI_ROWS["key_glyph"]["color"]
	var live := EventKinds.role_color("live")
	for lesson in _placed:
		var x: float = lesson["at"].x
		var y: float = lesson["at"].y
		for part in lesson["parts"]:
			if part.has("key"):
				var size := Keycap.size_of(part["key"], KEY_H)
				Keycap.draw(self, Vector2(x + size.x * 0.5, y), part["key"], cap_color, KEY_H)
				x += size.x + GAP
			else:
				var word: String = part["word"]
				UiDraw.text(self, x, y, word, WORD_SIZE, live)
				x += UiFonts.width(word, WORD_SIZE) + GAP * 2.0
