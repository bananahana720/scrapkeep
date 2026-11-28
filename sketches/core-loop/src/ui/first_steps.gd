extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const Glyphs := preload("res://src/core/glyphs.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const Tuning := preload("res://src/movement/tuning.gd")


const RETIRE_AFTER := {"roll": 3, "slam": 3, "plate": 1}
const DRIVE_LEARNED := 1.5
const STEER_DEADZONE := 0.3
const DRIVE_ACTIONS := ["cl_forward", "cl_left", "cl_back", "cl_right"]
const DRIVE_WORD := "DRIVE"
const SLAM_WORD := "SLAM"
const CORE_LIFT := Vector3(0.0, 3.0, 0.0)
const SLAM_REACH := 8.0
const BALL_OFFSET := Vector2(-24.0, -34.0)
const KEY_H := 28.0
const GAP := 6.0
const WORD_SIZE := UiTokens.BODY
const PLATE_SHOW := 1.4
const STREAK_GROW := 0.18
const STREAK_FADE := 0.35
const STREAK_SHORT := UiTokens.TARGET
const STREAK_LONG := UiTokens.TARGET * 2.5
const STREAK_SPREAD := UiTokens.GAP_S
const STREAK_LEAD := UiTokens.GAP_S
const STREAK_WIDTH := UiTokens.GAP_S

var game
var profile
var shown: Array = []
var _placed: Array = []
var _steered := 0.0
var _drive_done := false
var _was_drawn := {}
var _glance := {}
var _contact := {}
var _plate_shown := false


func setup(game_ref, profile_ref) -> void:
	game = game_ref
	profile = profile_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.events.run_started.connect(func(_class_id: String): new_run())
	game.events.slammed.connect(func(at: Vector3, _strength: float, _flatness: float):
		if game.flow.in_play() and core_open() and at.distance_to(game.flow.warden.global_position) <= SLAM_REACH:
			profile.add_use("slam"))
	game.events.strike_deflected.connect(_on_glanced)
	game.events.enemy_struck.connect(_on_struck)


func new_run() -> void:
	_steered = 0.0
	_drive_done = false
	shown = []
	_was_drawn = {}
	_glance = {}


func retired(id: String) -> bool:
	return profile.uses(id) >= RETIRE_AFTER[id]


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
	if core_open() and not retired("slam") and not player.line_stands():
		var parts: Array = [{"key": Glyphs.of("haul")}, {"word": SLAM_WORD}]
		if player.state.grounded:
			parts.push_front({"key": Glyphs.of("jump")})
		_add("slam", game.flow.warden.global_position + CORE_LIFT, Vector2.ZERO, "centre", parts)
	if not _glance.is_empty():
		_glance["left"] = float(_glance["left"]) - delta
		_glance["age"] = float(_glance["age"]) + delta
		if retired("plate") or float(_glance["left"]) <= 0.0 or not is_instance_valid(_glance["target"]):
			_glance = {}
		else:
			_add("plate", player.shown_position(), Vector2.ZERO, "streak", [])
	var drawn_now := {}
	for lesson in shown:
		drawn_now[lesson["id"]] = true
		if not _was_drawn.has(lesson["id"]):
			game.events.prompt_shown.emit(lesson["id"])
	_was_drawn = drawn_now


func _on_glanced(enemy: Node3D, _kind: String, punch: float, plating: float) -> void:
	if game == null or not game.flow.in_play() or retired("plate") or not is_instance_valid(enemy):
		return
	if enemy.get("tint_state") != "slate":
		return
	var hit: Dictionary = _contact.get("hit", {}) if _contact.get("id", 0) == enemy.get_instance_id() else {}
	if hit.is_empty() or bool(hit.get("guarded", false)):
		return
	if enemy.has_method("flare_glance"):
		enemy.flare_glance()
	_plate_shown = true
	_glance = {"target": enemy, "short": clampf(1.0 - punch / maxf(plating, 1.0), 0.0, 1.0), "left": PLATE_SHOW,
		"age": 0.0 if _glance.is_empty() else minf(float(_glance["age"]), STREAK_GROW)}


func _on_struck(enemy: Node3D, kind: String, force: float) -> void:
	_contact = {}
	if game == null or retired("plate") or not is_instance_valid(enemy):
		return
	var hit := _settled(enemy, kind, force)
	if hit.is_empty():
		return
	_contact = {"id": enemy.get_instance_id(), "hit": hit}
	if _plate_shown and bool(hit.get("full", false)) and float(hit.get("plating", 0.0)) > 0.0 and not bool(hit.get("absorbed", false)):
		profile.add_use("plate")
		_glance = {}


func _settled(enemy: Node3D, kind: String, force: float) -> Dictionary:
	var spawner = game.ctx.spawner if game.get("ctx") != null else null
	if spawner == null or not spawner.has_method("resolve") or not kind in spawner.CONTACT_KINDS:
		return {}
	return spawner.resolve(enemy, kind, force)


func _streak(cam: Camera3D, ball_world: Vector3) -> Dictionary:
	var target: Node3D = _glance["target"]
	var ball := cam.unproject_position(ball_world)
	var radius := ball.distance_to(cam.unproject_position(ball_world + cam.global_basis.x * Tuning.RADIUS))
	var ground := ball_world - target.global_position
	ground.y = 0.0
	var away := Vector2.DOWN
	if ground.length() > 0.01:
		var back := ball_world + ground.normalized() * Tuning.RADIUS
		if not cam.is_position_behind(back) and cam.unproject_position(back).distance_to(ball) >= 1.0:
			away = cam.unproject_position(back) - ball
	var age := float(_glance["age"])
	var grow := clampf(age / STREAK_GROW, 0.0, 1.0)
	var fade := clampf(float(_glance["left"]) / STREAK_FADE, 0.0, 1.0)
	return {"at": ball.round(), "lead": round(radius) + STREAK_LEAD, "dir": away.normalized(), "length": lerpf(STREAK_SHORT, STREAK_LONG, float(_glance["short"])) * ease(grow, 0.4),
		"alpha": fade}


func _drive_parts() -> Array:
	var parts: Array = []
	if Glyphs.is_pad():
		parts.append({"key": Glyphs.of("roll")})
	else:
		for action in DRIVE_ACTIONS:
			parts.append({"key": Glyphs.of_action(action, "key_w")})
	parts.append({"word": DRIVE_WORD})
	return parts


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


func _placements() -> Array:
	var out := []
	var camera = game.get("camera") if game != null else null
	if camera == null:
		return out
	var cam: Camera3D = camera.cam
	for lesson in shown:
		if cam.is_position_behind(lesson["world"]):
			continue
		if lesson["align"] == "streak":
			if not _glance.is_empty() and is_instance_valid(_glance["target"]):
				out.append(_streak(cam, lesson["world"]))
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
		if lesson.has("dir"):
			_draw_streak(lesson, live)
			continue
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


func _draw_streak(streak: Dictionary, live: Color) -> void:
	var dir: Vector2 = streak["dir"]
	var side := dir.orthogonal()
	for i in [-1, 0, 1]:
		var length: float = float(streak["length"]) * (1.0 if i == 0 else 0.6)
		var head: Vector2 = streak["at"] + dir * float(streak["lead"]) + side * STREAK_SPREAD * 1.5 * i
		var tail := head + dir * length
		var color := Color(live, float(streak["alpha"]))
		draw_polygon(PackedVector2Array([head + side * STREAK_WIDTH * 0.5, tail, head - side * STREAK_WIDTH * 0.5]),
			PackedColorArray([color, Color(color, 0.0), color]))
