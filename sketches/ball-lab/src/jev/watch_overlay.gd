extends CanvasLayer

# The watch overlay (JL-31): what a person sees while an arm plays a real trial in
# `scrapkeep lab watch`. jev_run.gd adds it only when it is given --watch=<dir>; a
# headless trial never loads it.
#
# It reads, and never writes, the trial: the ball's position, the held intent and
# the tick come from the runner's JevState view and agent, and the exact state file
# for a decision comes from the trial's io directory. What Node knows about each
# decision (the options on offer, the probabilities, how it was chosen and how long
# it took) arrives in <dir>/decisions.ndjson, and the arm, scenario, preflight
# verdict, call cap and palette in <dir>/session.json. Every colour and shape comes
# from that palette, which scripts/lab/metrics/status.mjs owns, so the overlay, the
# replay page and the terminal draw one intent the same way.
#
# Its only writes are Andrew's marks (--marks=<file>, JSONL, with a PNG of the
# frame beside it), the screenshots --shots asks for and a 3D ribbon mesh of the
# ball's recent path, which has no collision.
#
# Keys: M marks this moment and opens a note (Enter saves, Esc saves without one),
# T shows the exact state and options sent for the current decision, S cycles 1×,
# ½× and ¼× speed, H hides the key line. Slowing down renders fewer frames with one
# physics tick each, so every tick is the same fixed step as at full speed.

const Tuning := preload("res://src/tuning.gd")

const MARK_SCHEMA := "scrapkeep-watch-mark/1"
# One sample every TRAIL_EVERY ticks, TRAIL_KEEP of them: 20 s of path.
const TRAIL_EVERY := 3
const TRAIL_KEEP := 600
const RIBBON_HALF := 0.22
const STRIP := 10
const SPARK := 30
const SPEEDS := [{"word": "1×", "fps": 0}, {"word": "½×", "fps": 45}, {"word": "¼×", "fps": 22}]
const LINGER_S := 3.0
const MAP_SPAN := 80.0
const PANEL_ALPHA := 0.86
const MARGIN := 16.0
const SIDE_W := 440.0
const PREFLIGHT_LINES := 4

var trial
var settings := {}
var session := {}
var decisions: Array = []
var trail: Array = []
var marks_written := 0
var show_state := false
var show_help := true
var speed := 0
var pending := {}
var ended := {}
var watch_dir := ""
var marks_file := ""

var _offset := 0
var _canvas: Control
var _note: LineEdit
var _mesh: ImmediateMesh
var _font: Font
var _page := {}
var _intents := {}
var _sources := {}
var _status := {}
var _watch := {}
var _flash := ""
var _flash_until := 0.0
var _shots: Array = []
var _mark_at := -1
var _auto_commit := -1
var _end_shot := -1
var _defaults := {}


func setup(trial_ref, settings_ref: Dictionary) -> void:
	trial = trial_ref
	settings = settings_ref
	layer = 10
	watch_dir = str(settings.get("watch", ""))
	var text := FileAccess.get_file_as_string(watch_dir.path_join("session.json"))
	var parsed = JSON.parse_string(text) if text != "" else null
	session = parsed if parsed is Dictionary else {}
	marks_file = str(settings.get("marks", session.get("marks", "")))
	if marks_file != "" and marks_file.is_relative_path():
		marks_file = ProjectSettings.globalize_path("res://").path_join("../..").path_join(marks_file).simplify_path()
	_read_palette(session.get("palette", {}))
	for part in str(settings.get("shots", "")).split(",", false):
		if part.is_valid_int():
			_shots.append(part.to_int())
	_shots.sort()
	_mark_at = int(settings.get("mark_at", -1))
	_font = ThemeDB.fallback_font
	_defaults = {"fps": Engine.max_fps, "steps": Engine.max_physics_steps_per_frame}

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_overlay)
	add_child(_canvas)

	_note = LineEdit.new()
	_note.placeholder_text = "what did you see? (optional)"
	_note.visible = false
	_note.custom_minimum_size = Vector2(560, 38)
	_note.add_theme_font_size_override("font_size", 18)
	_note.text_submitted.connect(func(value: String) -> void: commit_mark(value))
	_note.gui_input.connect(_on_note_input)
	add_child(_note)

	_mesh = ImmediateMesh.new()
	var ribbon := MeshInstance3D.new()
	ribbon.name = "WatchTrail"
	ribbon.mesh = _mesh
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon.material_override = material
	trial.lab.add_child(ribbon)


func _read_palette(palette: Dictionary) -> void:
	_page = {}
	for key in palette.get("page", {}):
		_page[key] = _hex(palette["page"][key])
	for id in palette.get("intents", {}):
		var look: Dictionary = palette["intents"][id]
		var shape := PackedVector2Array()
		for point in look.get("shape", []):
			shape.append(Vector2(float(point[0]), float(point[1])))
		_intents[id] = {"color": _hex(look.get("hex")), "word": str(look.get("word", id)), "shape": shape}
	for key in palette.get("sources", {}):
		var source: Dictionary = palette["sources"][key]
		_sources[key] = {"word": str(source.get("word", key)), "color": _hex(source.get("hex"))}
	for key in palette.get("status", {}):
		var status: Dictionary = palette["status"][key]
		_status[key] = {"color": _hex(status.get("hex")), "glyph": str(status.get("glyph", ""))}
	for key in palette.get("watch", {}):
		var entry: Dictionary = palette["watch"][key]
		_watch[key] = {"color": _hex(entry.get("hex")), "glyph": str(entry.get("glyph", "")),
			"banner": str(entry.get("banner", "")), "word": str(entry.get("word", ""))}


static func _hex(value) -> Color:
	if typeof(value) == TYPE_STRING and Color.html_is_valid(value):
		return Color.html(value)
	return Color.WHITE


func page(key: String) -> Color:
	return _page.get(key, Color.WHITE)


func intent_look(id) -> Dictionary:
	if _intents.has(id):
		return _intents[id]
	var box := PackedVector2Array([Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.8), Vector2(-0.8, 0.8)])
	return {"color": page("muted"), "word": str(id), "shape": box}


func source_look(kind) -> Dictionary:
	return _sources.get(kind, {"word": str(kind).to_upper(), "color": page("soft")})


func current_tick() -> int:
	return trial.view.tick if trial != null and trial.view != null else 0


func latest() -> Dictionary:
	return decisions[-1] if not decisions.is_empty() else {}


# --- per tick and per frame ---------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if trial == null or trial.view == null or not ended.is_empty():
		return
	var tick: int = trial.view.tick
	if tick % TRAIL_EVERY != 0 or (not trail.is_empty() and trail[-1]["tick"] == tick):
		return
	var held: String = trial.agent.intent_id if trial.agent != null else ""
	trail.append({"tick": tick, "pos": trial.view.position(), "intent": held})
	if trail.size() > TRAIL_KEEP:
		trail.pop_front()


func _process(_delta: float) -> void:
	if trial == null:
		return
	poll()
	var tick := current_tick()
	while not _shots.is_empty() and tick >= int(_shots[0]):
		shot_to(watch_dir.path_join("shot-%06d.png" % int(_shots.pop_front())))
	if _mark_at >= 0 and tick >= _mark_at and pending.is_empty() and ended.is_empty():
		begin_mark("auto mark at tick %d (verification)" % _mark_at)
		_mark_at = -1
		_auto_commit = 150
	if _auto_commit > 0:
		_auto_commit -= 1
		if _auto_commit == 0:
			commit_mark(_note.text)
	if _end_shot > 0:
		_end_shot -= 1
		if _end_shot == 0:
			shot_to(watch_dir.path_join("shot-end.png"))
	_rebuild_ribbon()
	_place_note()
	_canvas.queue_redraw()


# Reads whole lines appended to decisions.ndjson since the last poll.
func poll() -> void:
	var path := watch_dir.path_join("decisions.ndjson")
	if watch_dir == "" or not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var length := file.get_length()
	if length <= _offset:
		return
	file.seek(_offset)
	var bytes := file.get_buffer(length - _offset)
	var last_newline := bytes.rfind(10)
	if last_newline < 0:
		return
	_offset += last_newline + 1
	for line in bytes.slice(0, last_newline + 1).get_string_from_utf8().split("\n", false):
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			decisions.append(parsed)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_M:
			begin_mark()
		KEY_T:
			show_state = not show_state
		KEY_S:
			cycle_speed()
		KEY_H:
			show_help = not show_help
		_:
			return
	get_viewport().set_input_as_handled()


func _on_note_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		commit_mark("")
		_note.accept_event()


func cycle_speed() -> void:
	speed = (speed + 1) % SPEEDS.size()
	if speed == 0:
		Engine.max_fps = _defaults["fps"]
		Engine.max_physics_steps_per_frame = _defaults["steps"]
	else:
		Engine.max_fps = SPEEDS[speed]["fps"]
		Engine.max_physics_steps_per_frame = 1


# --- marks --------------------------------------------------------------------------

# Captures this moment at once; the note is typed while the trial runs on.
func begin_mark(note := "") -> void:
	if trial == null or trial.view == null:
		return
	if not pending.is_empty():
		commit_mark(_note.text)
	var decision := latest()
	var seq = int(decision["seq"]) if decision.get("seq") != null else null
	var state_tick = int(decision["tick"]) if decision.get("tick") != null else null
	var hold := int(session.get("hold_ticks", trial.settings.get("hold_ticks", 0)))
	pending = {
		"schema": MARK_SCHEMA,
		"marked_at": Time.get_datetime_string_from_system(true),
		"run_id": session.get("run_id", null),
		"trial": int(session["trial"]) if session.get("trial") != null else null,
		"scenario": trial.settings.get("scenario", null),
		"arm": session.get("arm", null),
		"mode": trial.settings.get("mode", null),
		"seed": trial.settings.get("seed", null),
		"demo": session.get("demo", false),
		"label": session.get("label", null),
		"tick": trial.view.tick,
		"held": trial.agent.intent_id if trial.agent != null else "",
		"seq": seq,
		# The decision this mark links to was made on the state at state_tick; it
		# drives the ball from state_tick + hold_ticks. A mark on a snapshot tick
		# before that still shows the previous intent in `held`.
		"state_tick": state_tick,
		"hold_ticks": hold,
		"applied": state_tick != null and int(trial.view.tick) >= state_tick + hold,
		"kind": decision.get("kind", null),
		"chosen": decision.get("intent", null),
		"options": decision.get("offered", []),
		"gated": decision.get("gated", []),
		"probabilities": decision.get("probabilities", null),
		"confidence": decision.get("confidence", null),
		"latency_ms": decision.get("latency_ms", null),
		"state_file": _state_file(seq),
		"live": trial.view.snapshot(),
		"screenshot": _mark_shot(),
		"note": null,
	}
	_note.text = note
	_note.visible = true
	_note.grab_focus()


func commit_mark(note: String) -> void:
	if pending.is_empty():
		return
	var text := note.strip_edges()
	pending["note"] = text if text != "" else null
	_append_mark(pending)
	pending = {}
	_note.visible = false
	_note.release_focus()
	marks_written += 1
	_flash = "mark %d saved to %s" % [marks_written, marks_file.get_file()]
	_flash_until = Time.get_ticks_msec() / 1000.0 + 2.0


# The state file Node answered, byte for byte: its sha256 and its message.
func _state_file(seq) -> Variant:
	if seq == null or trial.io == null:
		return null
	var path: String = trial.io.dir.path_join("state-%06d.json" % int(seq))
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return {"name": path.get_file(), "sha256": hashing.finish().hex_encode(),
		"message": JSON.parse_string(bytes.get_string_from_utf8())}


func _append_mark(mark: Dictionary) -> void:
	if marks_file == "":
		printerr("jev_run: watch: no --marks file, mark at tick %s not saved" % mark["tick"])
		return
	DirAccess.make_dir_recursive_absolute(marks_file.get_base_dir())
	var file: FileAccess
	if FileAccess.file_exists(marks_file):
		file = FileAccess.open(marks_file, FileAccess.READ_WRITE)
		file.seek_end()
	else:
		file = FileAccess.open(marks_file, FileAccess.WRITE)
	file.store_string(JSON.stringify(mark) + "\n")
	file.close()


func _mark_shot() -> Variant:
	if marks_file == "":
		return null
	var name := "%s-mark-%02d.png" % [marks_file.get_file().get_basename(), marks_written + 1]
	var saved = shot_to(marks_file.get_base_dir().path_join(name))
	return repo_relative(saved) if saved != null else null


# Paths in marks are relative to the repository when they lie inside it.
static func repo_relative(path: String) -> String:
	var root := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	return path.trim_prefix(root + "/") if path.begins_with(root + "/") else path


# The last rendered frame as a PNG; null when there is no renderer (headless).
func shot_to(path: String) -> Variant:
	if DisplayServer.get_name() == "headless":
		return null
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return null
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if image.save_png(path) != OK:
		return null
	print("jev_run: watch shot %s" % path)
	return path


# The trial has ended: save any open mark, stop slow motion and show the result.
func finish() -> void:
	if not pending.is_empty():
		commit_mark(_note.text)
	var result: String = trial.run.result() if trial.run != null else "not started"
	var good: bool = result == "success" or (result == "running" and trial.outcome == "complete")
	ended = {"result": result, "outcome": trial.outcome, "tick": current_tick(), "good": good}
	if speed != 0:
		speed = SPEEDS.size() - 1
		cycle_speed()
	if str(settings.get("shots", "")) != "" or int(settings.get("mark_at", -1)) >= 0:
		_end_shot = 20
	_canvas.queue_redraw()


# --- the 3D trail -------------------------------------------------------------------

func _rebuild_ribbon() -> void:
	_mesh.clear_surfaces()
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var n := trail.size()
	var lift := Vector3(0.0, -Tuning.RADIUS + 0.08, 0.0)
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	for i in range(1, n):
		var a: Vector3 = trail[i - 1]["pos"] + lift
		var b: Vector3 = trail[i]["pos"] + lift
		var along := b - a
		# A segment that mostly rises or falls (a bounce on a dummy) is left out:
		# drawn at any width it stands up as a column under the ball.
		if Vector2(along.x, along.z).length() < absf(along.y) or along.length() < 0.01:
			continue
		# Width faces the camera, so a slope or a jump arc draws a line, never a
		# sheet; with no camera (a headless test) it lies flat.
		var facing := Vector3.UP
		if camera != null:
			facing = (camera.global_position - (a + b) * 0.5).normalized()
		var side := along.cross(facing)
		if side.length() < 0.001:
			continue
		side = side.normalized() * RIBBON_HALF
		var color: Color = intent_look(trail[i]["intent"])["color"]
		color.a = lerpf(0.08, 0.9, float(i) / float(n))
		for v in [a + side, a - side, b + side, a - side, b - side, b + side]:
			vertices.append(v)
			colors.append(color)
	if vertices.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in vertices.size():
		_mesh.surface_set_color(colors[i])
		_mesh.surface_add_vertex(vertices[i])
	_mesh.surface_end()


# --- drawing ------------------------------------------------------------------------

func _place_note() -> void:
	if _note.visible:
		var size := _canvas.size
		_note.position = Vector2((size.x - 560.0) * 0.5, size.y - 176.0)
		_note.size = Vector2(560, 38)


# Words laid into lines no wider than `width` at `size`; a word longer than the
# line is split by characters.
func wrap_text(text: String, width: float, size: int) -> Array:
	var lines := []
	var line := ""
	for word in text.split(" ", false):
		var candidate := word if line == "" else line + " " + word
		if _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			line = candidate
			continue
		if line != "":
			lines.append(line)
		line = word
		while _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line.length() > 1:
			var cut := line.length() - 1
			while cut > 1 and _font.get_string_size(line.substr(0, cut), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				cut -= 1
			lines.append(line.substr(0, cut))
			line = line.substr(cut)
	if line != "":
		lines.append(line)
	return lines


func _panel(rect: Rect2) -> void:
	var fill := page("panel")
	fill.a = PANEL_ALPHA
	_canvas.draw_rect(rect, fill)
	_canvas.draw_rect(rect, page("rule"), false, 1.0)


func _text(at: Vector2, text: String, size: int, color: Color, width := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_canvas.draw_string(_font, at, text, align, width, size, color)


func _shape(shape: PackedVector2Array, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point in shape:
		points.append(center + point * radius)
	_canvas.draw_colored_polygon(points, color)


# Status glyphs (●, ▲, ■, ○, ◇) as shapes, so no font has to carry them.
func _glyph(glyph: String, center: Vector2, radius: float, color: Color) -> void:
	match glyph:
		"●":
			_canvas.draw_circle(center, radius, color)
		"▲":
			_shape(PackedVector2Array([Vector2(0, -1), Vector2(1, 0.8), Vector2(-1, 0.8)]), center, radius, color)
		"■":
			_canvas.draw_rect(Rect2(center - Vector2(radius, radius) * 0.85, Vector2(radius, radius) * 1.7), color)
		"◇":
			_shape(PackedVector2Array([Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]), center, radius, color)
		_:
			_canvas.draw_arc(center, radius * 0.8, 0.0, TAU, 20, color, 2.0)


func _draw_overlay() -> void:
	if _font == null:
		return
	var size := _canvas.size
	_draw_header()
	_draw_banner(size)
	var below := _draw_decision(Rect2(size.x - SIDE_W - MARGIN, MARGIN, SIDE_W, 0))
	_draw_telemetry(Rect2(size.x - SIDE_W - MARGIN, below + 10.0, SIDE_W, 0))
	_draw_map(Rect2(MARGIN, 104, 250, 250))
	_draw_strip(Rect2(MARGIN, size.y - 92.0, size.x - SIDE_W - MARGIN * 3.0, 76))
	if show_state:
		_draw_state(Rect2(MARGIN + 266, 104, 640, size.y - 220.0))
	if not pending.is_empty():
		_draw_mark_prompt(size)
	if _flash != "" and Time.get_ticks_msec() / 1000.0 < _flash_until:
		var accent: Color = _watch.get("mark", {}).get("color", page("accent"))
		_text(Vector2(size.x * 0.5 - 260.0, 150), _flash, 18, accent, 520.0, HORIZONTAL_ALIGNMENT_CENTER)
	if show_help:
		_panel(Rect2(size.x - SIDE_W - MARGIN, size.y - 36.0, SIDE_W, 30))
		_text(Vector2(size.x - SIDE_W - MARGIN, size.y - 15.0),
			"M mark · T state sent · S speed %s · H hide · Ctrl-C in terminal stops" % SPEEDS[speed]["word"],
			13, page("soft"), SIDE_W - 12.0, HORIZONTAL_ALIGNMENT_RIGHT)
	if not ended.is_empty():
		_draw_end(size)


func _draw_header() -> void:
	var rect := Rect2(MARGIN, MARGIN, 520, 72)
	_panel(rect)
	var scenario := str(trial.settings.get("scenario", "?"))
	var arm := str(session.get("arm", "?"))
	_text(rect.position + Vector2(14, 30), "%s · %s arm" % [scenario, arm], 24, page("bright"))
	var result: String = trial.run.result() if trial.run != null else "starting"
	var tick := current_tick()
	var line := "%s · seed %s · trial %d · tick %d · %.1f s · %s" % [
		trial.settings.get("mode", "?"), trial.settings.get("seed", "?"), int(session.get("trial", 0)),
		tick, float(tick) / float(Engine.physics_ticks_per_second), result]
	_text(rect.position + Vector2(14, 58), line, 15, page("soft"))


func _draw_banner(size: Vector2) -> void:
	var demo := bool(session.get("demo", false))
	var look: Dictionary = _watch.get("demo" if demo else "watch", {})
	var banner := str(session.get("banner", look.get("banner", "WATCH")))
	var color: Color = look.get("color", page("soft"))
	var width := _font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 58.0
	var rect := Rect2(size.x * 0.5 - width * 0.5, MARGIN, width, 36)
	if demo:
		_canvas.draw_rect(rect, color)
		_glyph(str(look.get("glyph", "")), rect.position + Vector2(20, 18), 9.0, page("deep"))
		_text(rect.position + Vector2(36, 25), banner, 20, page("deep"))
	else:
		_panel(rect)
		_glyph(str(look.get("glyph", "")), rect.position + Vector2(20, 18), 8.0, color)
		_text(rect.position + Vector2(36, 25), banner, 20, color)
	var preflight = session.get("preflight", null)
	if not (preflight is Dictionary):
		return
	var passed := bool(preflight.get("passed", false))
	var status: Dictionary = _status.get("pass" if passed else "fail", {})
	var verdict := "preflight %s %s · %d live calls" % [preflight.get("controls_version", "?"),
		"passed" if passed else "did not pass", int(preflight.get("calls", 0))]
	# Between the header and the decision panel, so it covers neither; failing
	# controls wrap onto as many lines as they need, up to PREFLIGHT_LINES.
	var left := MARGIN * 2.0 + 520.0
	var box_w := size.x - SIDE_W - MARGIN * 2.0 - left
	var lines: Array = []
	if not passed:
		for entry in preflight.get("lines", []):
			if str(entry).contains("did not pass"):
				lines.append_array(wrap_text(str(entry), box_w - 44.0, 14))
	var shown := mini(lines.size(), PREFLIGHT_LINES)
	var box := Rect2(left, MARGIN + 44.0, box_w, 36.0 + 20.0 * shown)
	_panel(box)
	_glyph(str(status.get("glyph", "")), box.position + Vector2(18, 18), 7.0, status.get("color", page("soft")))
	_text(box.position + Vector2(34, 24), verdict, 17, status.get("color", page("soft")), box_w - 44.0)
	for i in shown:
		var line: String = lines[i]
		if i == shown - 1 and lines.size() > shown:
			line += " …"
		_text(box.position + Vector2(34, 46 + 20.0 * i), line, 14, page("soft"), box_w - 44.0)


# The current decision: options on offer with their bars, the chosen one outlined,
# how it was chosen and how long it took against the hold window. Returns its bottom.
func _draw_decision(area: Rect2) -> float:
	var decision := latest()
	var offered: Array = decision.get("offered", [])
	var height := 214.0 + 34.0 * maxf(1.0, offered.size())
	var rect := Rect2(area.position, Vector2(area.size.x, height))
	_panel(rect)
	var x := rect.position.x + 14.0
	var y := rect.position.y + 30.0
	if decision.is_empty():
		_text(Vector2(x, y), "waiting for the first decision", 18, page("soft"))
		return rect.end.y
	var source := source_look(decision.get("kind", ""))
	_text(Vector2(x, y), "decision #%d · tick %d" % [int(decision.get("seq", 0)), int(decision.get("tick", 0))], 20, page("bright"))
	var badge := str(source["word"])
	var badge_w := _font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0
	var badge_rect := Rect2(rect.end.x - badge_w - 14.0, y - 19.0, badge_w, 24)
	_canvas.draw_rect(badge_rect, source["color"], false, 2.0)
	_text(badge_rect.position + Vector2(8, 17), badge, 14, source["color"])
	y += 16.0
	var probabilities = decision.get("probabilities", null)
	var chosen = decision.get("intent", null)
	var dim := bool(decision.get("low_confidence", false))
	for option in offered:
		y += 34.0
		var id := str(option.get("id", "?"))
		var look := intent_look(id)
		var color: Color = look["color"]
		var is_chosen: bool = id == chosen
		if is_chosen:
			var outline := color
			outline.a = 0.45 if dim else 1.0
			_canvas.draw_rect(Rect2(x - 6.0, y - 24.0, area.size.x - 16.0, 32), outline, false, 2.0)
		_shape(look["shape"], Vector2(x + 10.0, y - 8.0), 10.0, color)
		_text(Vector2(x + 28.0, y), id, 16, page("bright") if is_chosen else page("soft"), 150.0)
		var track := Rect2(x + 186.0, y - 15.0, 150.0, 12.0)
		_canvas.draw_rect(track, page("deep"))
		var p = probabilities.get(id, null) if probabilities is Dictionary else null
		var value := ""
		if p != null:
			var fill := color
			if is_chosen and dim:
				fill.a = 0.45
			_canvas.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(p), 0.0, 1.0), track.size.y)), fill)
			value = "%d%%" % roundi(float(p) * 100.0)
		elif is_chosen:
			var fill := color
			fill.a = 0.35
			_canvas.draw_rect(track, fill)
			value = "chosen"
		_text(Vector2(track.end.x + 8.0, y), value, 15, page("bright") if is_chosen else page("soft"), 60.0,
			HORIZONTAL_ALIGNMENT_RIGHT)
	y += 30.0
	var note := _decision_note(decision)
	if note != "":
		_text(Vector2(x, y), note, 15, source["color"] if decision.get("kind", "") in ["fallback", "failed"] else page("soft"),
			area.size.x - 28.0)
	y += 26.0
	var gated: Array = decision.get("gated", [])
	if not gated.is_empty():
		_text(Vector2(x, y), "gated out: %s" % ", ".join(PackedStringArray(gated)), 14, page("soft"), area.size.x - 28.0)
	y += 30.0
	_draw_latency(Rect2(x, y, area.size.x - 28.0, 40), float(decision.get("latency_ms", 0.0)))
	return rect.end.y


func _decision_note(decision: Dictionary) -> String:
	match str(decision.get("kind", "")):
		"live", "cache":
			return "chosen %s · Jev confidence %.2f (how sure it is overall)%s" % [_top_probability(decision),
				float(decision.get("confidence", 0.0)), " · cached" if decision.get("kind") == "cache" else ""]
		"fallback":
			return "Jev leaned %s at confidence %.2f, under its floor; held %s" % [decision.get("raw_intent", "?"),
				float(decision.get("confidence", 0.0)), decision.get("intent", "?")]
		"forced":
			return "one option on offer, so no arm was asked"
		"rule":
			return "rule %s" % decision.get("rule", "?")
		"seeded":
			return "uniform seeded draw over the offered options"
		"failed":
			return str(decision.get("error", "the arm failed"))
	return ""


func _hold_ms() -> float:
	return 1000.0 * float(session.get("hold_ticks", 26)) / float(session.get("tick_hz", 90))


func _draw_latency(area: Rect2, latency: float) -> void:
	var hold := _hold_ms()
	var scale := maxf(hold * 2.0, latency)
	var warn: Color = _status.get("warn", {}).get("color", page("accent"))
	var over := latency > hold
	_text(area.position + Vector2(0, 0), "decided in %d ms%s" % [roundi(latency), " · the game waited" if over else ""],
		15, warn if over else page("soft"))
	var track := Rect2(area.position + Vector2(0, 10), Vector2(area.size.x, 10))
	_canvas.draw_rect(track, page("deep"))
	_canvas.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(latency / scale, 0.0, 1.0), 10)),
		warn if over else page("soft"))
	var at := track.position.x + track.size.x * hold / scale
	_canvas.draw_line(Vector2(at, track.position.y - 4), Vector2(at, track.end.y + 4), page("bright"), 2.0)
	_text(Vector2(at + 4, track.end.y + 16), "hold window %d ms" % roundi(hold), 12, page("soft"))


func _latencies() -> Array:
	var out := []
	for decision in decisions:
		if decision.get("kind", "") != "forced":
			out.append(float(decision.get("latency_ms", 0.0)))
	return out


func _draw_telemetry(area: Rect2) -> void:
	var jev := str(session.get("arm", "")) == "jev"
	var rect := Rect2(area.position, Vector2(area.size.x, 150.0 if jev else 104.0))
	_panel(rect)
	var x := rect.position.x + 14.0
	var y := rect.position.y + 26.0
	var values := _latencies()
	if values.is_empty():
		_text(Vector2(x, y), "latency: no arm has been asked yet", 15, page("soft"))
	else:
		var sorted := values.duplicate()
		sorted.sort()
		var total := 0.0
		for value in values:
			total += value
		var p95: float = sorted[clampi(ceili(0.95 * sorted.size()) - 1, 0, sorted.size() - 1)]
		_text(Vector2(x, y), "latency ms  last %d · avg %d · p95 %d" % [roundi(values[-1]), roundi(total / values.size()), roundi(p95)],
			15, page("soft"))
		_draw_spark(Rect2(x, y + 10.0, rect.size.x - 28.0, 36.0), values.slice(maxi(0, values.size() - SPARK)))
	if not jev:
		_text(Vector2(x, rect.end.y - 14.0), "no Jev calls: %s arm" % session.get("arm", "?"), 14, page("soft"))
		return
	var decision := latest()
	var calls: Dictionary = decision.get("calls", {})
	var tokens: Dictionary = decision.get("tokens", {})
	var cap: Dictionary = session.get("cap", {})
	var preflight_calls := int(cap.get("preflight_calls", 0))
	var live := int(calls.get("live", preflight_calls))
	_text(Vector2(x, rect.end.y - 40.0), "Jev calls %d of %d (%d preflight) · %d cached" % [live,
		int(cap.get("session", 0)), preflight_calls, int(calls.get("cached", 0))], 15, page("bright"))
	# Before the first decision only the preflight has spent anything.
	var preflight = session.get("preflight", null)
	if tokens.is_empty() and preflight is Dictionary:
		tokens = preflight.get("tokens", {})
	var shown := []
	for field in ["input_tokens", "output_tokens"]:
		var value = tokens.get(field, null)
		shown.append("%s %s" % [field, "?" if value == null else str(int(value))])
	_text(Vector2(x, rect.end.y - 16.0), " · ".join(PackedStringArray(shown)), 14, page("soft"))


func _draw_spark(area: Rect2, values: Array) -> void:
	_canvas.draw_rect(area, page("deep"))
	var hold := _hold_ms()
	var top := hold * 2.0
	for value in values:
		top = maxf(top, float(value))
	var hold_y := area.end.y - area.size.y * hold / top
	_canvas.draw_line(Vector2(area.position.x, hold_y), Vector2(area.end.x, hold_y), page("muted"), 1.0)
	if values.size() < 2:
		return
	var points := PackedVector2Array()
	for i in values.size():
		var px := area.position.x + area.size.x * float(i) / float(values.size() - 1)
		points.append(Vector2(px, area.end.y - area.size.y * float(values[i]) / top))
	_canvas.draw_polyline(points, page("bright"), 2.0)


# Top-down, x across and z down as on the replay page, centred on the ball.
func _draw_map(rect: Rect2) -> void:
	_panel(rect)
	_text(rect.position + Vector2(10, 18), "top-down · %d m across" % int(MAP_SPAN), 13, page("soft"))
	if trail.is_empty() or trial.view == null:
		return
	var at: Vector3 = trial.view.position()
	var center := rect.get_center()
	var scale := rect.size.x / MAP_SPAN
	var clip := rect.grow(-4.0)
	for i in range(1, trail.size()):
		var a: Vector3 = trail[i - 1]["pos"]
		var b: Vector3 = trail[i]["pos"]
		var pa := center + Vector2(a.x - at.x, a.z - at.z) * scale
		var pb := center + Vector2(b.x - at.x, b.z - at.z) * scale
		if not (clip.has_point(pa) and clip.has_point(pb)):
			continue
		var color: Color = intent_look(trail[i]["intent"])["color"]
		color.a = lerpf(0.25, 1.0, float(i) / float(trail.size()))
		_canvas.draw_line(pa, pb, color, 3.0)
	_canvas.draw_circle(center, 5.0, page("bright"))


# The last decisions, oldest on the left. Each chip is its intent's colour and
# shape with its top probability, and the way it was chosen underneath.
func _draw_strip(area: Rect2) -> void:
	_panel(area)
	_text(area.position + Vector2(10, 16), "last %d decisions, newest right" % STRIP, 12, page("soft"))
	var shown := decisions.slice(maxi(0, decisions.size() - STRIP))
	var chip_w := minf(118.0, (area.size.x - 20.0) / float(STRIP))
	for i in shown.size():
		var decision: Dictionary = shown[i]
		var look := intent_look(decision.get("intent", null))
		var source := source_look(decision.get("kind", ""))
		var dim: bool = bool(decision.get("low_confidence", false)) or decision.get("kind", "") in ["forced", "failed"]
		var chip := Rect2(area.position.x + 10.0 + i * chip_w, area.position.y + 22.0, chip_w - 8.0, 48.0)
		var fill: Color = look["color"]
		fill.a = 0.10 if dim else 0.24
		_canvas.draw_rect(chip, fill)
		var edge: Color = look["color"]
		edge.a = 0.45 if dim else 1.0
		var newest := i == shown.size() - 1
		_canvas.draw_rect(chip, page("bright") if newest else edge, false, 3.0 if newest else 1.5)
		var shape_color: Color = look["color"]
		shape_color.a = edge.a
		_shape(look["shape"], chip.position + Vector2(16, 18), 9.0, shape_color)
		var top := _top_probability(decision)
		_text(chip.position + Vector2(32, 24), top, 16, page("bright") if not dim else page("soft"), chip.size.x - 36.0)
		_text(chip.position + Vector2(8, 42), str(source["word"]), 12, source["color"], chip.size.x - 12.0)


func _top_probability(decision: Dictionary) -> String:
	var probabilities = decision.get("probabilities", null)
	var chosen = decision.get("intent", null)
	if probabilities is Dictionary and chosen != null and probabilities.has(chosen):
		return "%d%%" % roundi(float(probabilities[chosen]) * 100.0)
	return str(intent_look(chosen)["word"]) if chosen != null else "—"


func _draw_state(rect: Rect2) -> void:
	_panel(rect)
	var decision := latest()
	_text(rect.position + Vector2(12, 22), "state and options sent for decision #%s (T hides)" % decision.get("seq", "?"), 15, page("bright"))
	var text := JSON.stringify(decision.get("state", {}), "  ")
	var lines := text.split("\n")
	var room := int((rect.size.y - 40.0) / 17.0)
	for i in mini(lines.size(), room):
		_text(rect.position + Vector2(12, 44 + 17.0 * i), lines[i], 13, page("soft"), rect.size.x - 24.0)


func _draw_mark_prompt(size: Vector2) -> void:
	var accent: Color = _watch.get("mark", {}).get("color", page("accent"))
	var rect := Rect2((size.x - 600.0) * 0.5, size.y - 222.0, 600, 92)
	_panel(rect)
	_canvas.draw_rect(rect, accent, false, 2.0)
	_canvas.draw_circle(rect.position + Vector2(20, 22), 7.0, accent)
	_text(rect.position + Vector2(36, 28), "MARK at tick %d · type a note, Enter saves, Esc saves without" % int(pending.get("tick", 0)),
		16, accent, 550.0)


func _draw_end(size: Vector2) -> void:
	var status: Dictionary = _status.get("pass" if ended["good"] else "fail", {})
	var color: Color = status.get("color", page("bright"))
	var rect := Rect2(size.x * 0.5 - 300.0, size.y * 0.5 - 70.0, 600, 120)
	_panel(rect)
	_canvas.draw_rect(rect, color, false, 3.0)
	_glyph(str(status.get("glyph", "")), rect.position + Vector2(34, 46), 12.0, color)
	_text(rect.position + Vector2(58, 56), "%s at tick %d" % [ended["result"], int(ended["tick"])], 30, color, 520.0)
	_text(rect.position + Vector2(58, 92), "trial %s · %d mark%s · the window closes in %d s" % [ended["outcome"], marks_written,
		"" if marks_written == 1 else "s", int(LINGER_S)],
		15, page("soft"), 520.0)
