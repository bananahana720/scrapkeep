extends Node

# The verify-game driver (.agents/skills/scrapkeep-verify-game/SKILL.md). The launched game loads
# this through its own --self-play-script hook (src/game.gd), so the game runs as a player's game
# runs: nothing tells it a bot is at the controls, and every key and click goes through Godot's
# input path. It reads a step file, one step a line, and writes one row a step to steps.ndjson
# beside the pictures it takes. A failed step takes a picture, writes its row and quits 1.
#
# Flags (after `--`): --drive-steps=<file>  --drive-out=<dir>  --drive-live=1
# Only the frames a shot keeps are drawn, because a software renderer takes over a second a frame;
# --drive-live=1 draws every frame (a machine with a graphics card, where somebody watches).
#
# Steps (seconds are game seconds; a quoted text matches any visible Control's text, ignoring case):
#   wait <s>
#   until state <name> [<timeout s>]      title, class_select, stage, beacon, gates, launch,
#                                         summary, dead, boss, victory, lap
#   until play [<timeout s>]              the ball is in play (stage, beacon, gates, launch, boss, lap)
#   until text "<words>" [<timeout s>]    the words are drawn somewhere, even under another layer
#   until no_text "<words>" [<timeout s>]
#   until clickable "<words>" [<timeout s>]  the words are drawn AND the pointer over them lands on them
#                                         (nothing covers them): the wait to use before a click
#   until read <expression> [<timeout s>] until the expression is true (see read)
#   key <NAME> [<hold s>]                 SPACE, E, 1, ESCAPE, TAB, W ... (Godot key names)
#   down <NAME> / up <NAME>               hold a key across other steps
#   tap_until <NAME> <state|play|text|no_text|clickable|read> <what> [<timeout s>]
#                                         tap the key every 0.6 s until the condition holds (a page
#                                         turner: tap_until E no_text "FIRST SHIFT")
#   mouse <left|right> [<hold s>]         a mouse button at the pointer
#   click "<words>"                       left click the middle of the first visible Control with that
#                                         text; fails when something else is under the pointer there
#   click_at <x> <y>                      left click a point of the game's own 1600x900 view (the
#                                         boxes a ui step lists use it; pictures are saved smaller)
#   look <dx> <dy>                        move the mouse (the camera) by that many pixels
#   shot <name>                           <out>/<nn>-<name>.png
#   ui                                    <out>/<nn>-ui.txt: every visible Control with words, its script and box
#   read <expression>                     a live value, written to the step's row. The expression is
#                                         evaluated on the game node: flow.state_name(), player.global_position
#   meshes "<text>" [<at least>]          counts the drawn 3D meshes whose file path holds the text (which model
#                                         file is on screen: "_tripo", "ball_look_cutaway"); the row lists the
#                                         first few. Fails when fewer than <at least> (default 0: only counts)
#   expect state <name> | expect text "<words>" | expect no_text "<words>" | expect read <expression>
#   quit                                  quits 0 (the end of the file does the same)
#   quits <step>                          the last step, when that step must make the game itself quit
#                                         (quits click "Quit"): fails if the game still runs 10 s later
#
# A check on a live value (read, expect read) is ground truth for the row, never the proof itself:
# the proof is the picture and the side effect on disk.

const DEFAULT_TIMEOUT := 60.0
const TAP_S := 0.1
const TAP_GAP_S := 0.6
# The fewest words a step needs, itself included; a short step fails by name, not by a runtime error.
const NEEDS := {"wait": 2, "until": 2, "tap_until": 3, "expect": 3, "key": 2, "down": 2, "up": 2, "mouse": 2, "click": 2, "click_at": 3, "look": 3, "quits": 2, "meshes": 2}

var game: Node
var _out := ""
var _steps: PackedStringArray = []
var _clock := 0.0
var _n := 0
var _rows: FileAccess
var _pointer := Vector2(800, 450)
var _live := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var steps_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--drive-steps="):
			steps_path = arg.trim_prefix("--drive-steps=")
		elif arg.begins_with("--drive-out="):
			_out = arg.trim_prefix("--drive-out=")
		elif arg == "--drive-live=1":
			_live = true
	if steps_path == "" or _out == "" or not FileAccess.file_exists(steps_path):
		push_error("drive: needs --drive-steps=<file> and --drive-out=<dir>")
		get_tree().quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("drive: needs a drawn display (macOS --embedded --rendering-driver metal or Linux xvfb-run), not --headless")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_rows = FileAccess.open(_out.path_join("steps.ndjson"), FileAccess.WRITE)
	for line in FileAccess.get_file_as_string(steps_path).split("\n"):
		var step := line.strip_edges()
		if step != "" and not step.begins_with("#"):
			_steps.append(step)
	RenderingServer.render_loop_enabled = _live
	print("drive: %d steps from %s" % [_steps.size(), steps_path])
	_run.call_deferred()


func _process(delta: float) -> void:
	_clock += delta


func _run() -> void:
	for step in _steps:
		_n += 1
		var result: Dictionary = await _do(step)
		_row(step, result)
		if not result.ok:
			await _shot("FAILED")
			print("drive: FAILED step %d '%s': %s" % [_n, step, result.get("detail", "")])
			_end(1)
			return
		if step == "quit":
			break
	print("drive: done, %d steps passed" % _n)
	_end(0)


func _end(code: int) -> void:
	_rows.close()
	get_tree().quit(code)


func _row(step: String, result: Dictionary) -> void:
	var row := {"n": _n, "step": step, "ok": result.ok, "at_s": snappedf(_clock, 0.01), "state": game.flow.state_name(), "in_play": game.flow.in_play(), "paused": get_tree().paused}
	for key in result:
		if key != "ok":
			row[key] = result[key]
	_rows.store_line(JSON.stringify(row))
	_rows.flush()
	print("drive: %s %d '%s' state=%s%s" % ["ok" if result.ok else "FAIL", _n, step, row.state, (" " + str(result.get("detail", ""))) if result.has("detail") else ""])


func _do(step: String) -> Dictionary:
	var words := _split(step)
	var verb: String = words[0]
	var needs: int = NEEDS.get(verb, 1)
	if verb in ["until", "tap_until"] and words.size() >= needs and words[needs - 1] != "play":
		needs += 1
	if words.size() < needs:
		return {"ok": false, "detail": "'%s' needs %d more word(s); the step list is at the top of drive.gd" % [verb, needs - words.size()]}
	match verb:
		"wait":
			await _sleep(float(words[1]))
			return {"ok": true}
		"until":
			return await _until(words, KEY_NONE, step)
		"tap_until":
			var tapped := OS.find_keycode_from_string(words[1])
			if tapped == KEY_NONE:
				return {"ok": false, "detail": "no key named " + words[1]}
			words.remove_at(1)
			return await _until(words, tapped, step)
		"expect":
			return _expect(words, step)
		"key":
			var key := OS.find_keycode_from_string(words[1])
			if key == KEY_NONE:
				return {"ok": false, "detail": "no key named " + words[1]}
			_key(key, true)
			await _sleep(float(words[2]) if words.size() > 2 else TAP_S)
			_key(key, false)
			await _sleep(TAP_S)
			return {"ok": true}
		"down", "up":
			var held := OS.find_keycode_from_string(words[1])
			if held == KEY_NONE:
				return {"ok": false, "detail": "no key named " + words[1]}
			_key(held, verb == "down")
			return {"ok": true}
		"mouse":
			var button := MOUSE_BUTTON_RIGHT if words[1] == "right" else MOUSE_BUTTON_LEFT
			_button(button, true)
			await _sleep(float(words[2]) if words.size() > 2 else TAP_S)
			_button(button, false)
			await _sleep(TAP_S)
			return {"ok": true}
		"click":
			var hit := _find(words[1])
			if hit == null:
				return {"ok": false, "detail": "no visible control says '%s'" % words[1]}
			if not await _lands_on(hit):
				var under := get_viewport().gui_get_hovered_control()
				return {"ok": false, "detail": "'%s' is covered: the pointer there is over %s" % [words[1], "nothing" if under == null else str(under.get_path())]}
			return await _click(hit.get_global_rect().get_center(), hit.get_path())
		"click_at":
			return await _click(Vector2(float(words[1]), float(words[2])), "")
		"look":
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(float(words[1]), float(words[2]))
			motion.position = _to_window(_pointer)
			Input.parse_input_event(motion)
			await _sleep(TAP_S)
			return {"ok": true}
		"shot":
			return {"ok": true, "file": await _shot(words[1] if words.size() > 1 else "shot")}
		"ui":
			var file := "%02d-ui.txt" % _n
			var text := FileAccess.open(_out.path_join(file), FileAccess.WRITE)
			for control in _visible_controls():
				text.store_line("%s | %s | %s | %s" % [_words_of(control).replace("\n", " / "), control.get_class() if control.get_script() == null else control.get_script().resource_path.get_file(), control.get_global_rect(), control.get_path()])
			text.close()
			return {"ok": true, "file": file}
		"read":
			var value: Variant = _read(step.trim_prefix("read").strip_edges())
			return {"ok": value[0], "value": str(value[1]), "detail": str(value[1])}
		"meshes":
			var found: Array = []
			for node in get_tree().root.find_children("*", "MeshInstance3D", true, false):
				var mesh: Mesh = node.mesh
				if mesh != null and node.is_visible_in_tree() and words[1] in mesh.resource_path:
					found.append("%s at %s" % [mesh.resource_path.get_slice("::", 0).get_file(), node.global_position.snappedf(0.1)])
			var least := int(words[2]) if words.size() > 2 else 0
			return {"ok": found.size() >= least, "value": str(found.size()), "first": found.slice(0, 6), "detail": "%d mesh(es) from a file with '%s'" % [found.size(), words[1]]}
		"quit":
			return {"ok": true}
		"quits":
			print("drive: awaiting the game's own quit")
			var inner: Dictionary = await _do(step.trim_prefix("quits").strip_edges())
			if not inner.ok:
				return inner
			await _sleep(10.0)
			return {"ok": false, "detail": "the game is still running 10 s later"}
	return {"ok": false, "detail": "no step called '%s'" % verb}


func _until(words: Array, tap: Key, step: String) -> Dictionary:
	var kind: String = words[1]
	var what: String = "" if kind == "play" else words[2]
	var limit_at := 2 if kind == "play" else 3
	if kind == "read":
		# The expression is the step's own text after "read" (quotes and spaces kept); a trailing
		# number is the timeout.
		what = step.substr(step.find(" read ") + 6).strip_edges()
		limit_at = words.size()
		var last := what.rfind(" ")
		if last > 0 and what.substr(last + 1).is_valid_float():
			limit_at = words.size() - 1
			what = what.substr(0, last).strip_edges()
		var parsed := _read(what)
		if not parsed[0]:
			return {"ok": false, "detail": "%s: %s" % [what, parsed[1]]}
	var limit := float(words[limit_at]) if words.size() > limit_at else DEFAULT_TIMEOUT
	var start := _clock
	var taps := 0
	var tap_at := -1.0
	while _clock - start <= limit:
		var held: bool
		if kind == "clickable":
			var hit := _find(what)
			held = hit != null and await _lands_on(hit)
		else:
			held = _holds(kind, what)
		if held:
			return {"ok": true, "waited_s": snappedf(_clock - start, 0.01), "taps": taps}
		if tap != KEY_NONE and _clock - tap_at >= TAP_GAP_S:
			tap_at = _clock
			taps += 1
			_key(tap, true)
			await _sleep(TAP_S)
			_key(tap, false)
		await get_tree().process_frame
	return {"ok": false, "detail": "'%s %s' not reached in %.0f s (state %s)" % [kind, what, limit, game.flow.state_name()]}


func _expect(words: Array, step: String) -> Dictionary:
	var kind: String = words[1]
	var what: String = step.substr(step.find(" read ") + 6).strip_edges() if kind == "read" else words[2]
	if _holds(kind, what):
		return {"ok": true}
	return {"ok": false, "detail": "expected %s '%s' (state %s)" % [kind, what, game.flow.state_name()]}


func _holds(kind: String, what: String) -> bool:
	match kind:
		"state":
			return game.flow.state_name() == what
		"play":
			return game.flow.in_play()
		"text":
			return _find(what) != null
		"no_text":
			return _find(what) == null
		"read":
			var value: Variant = _read(what)
			return value[0] and value[1] is bool and value[1]
	return false


# [ok, value]: an expression evaluated on the game node.
func _read(source: String) -> Array:
	var expression := Expression.new()
	if expression.parse(source) != OK:
		return [false, "cannot parse: " + expression.get_error_text()]
	var value: Variant = expression.execute([], game, false)
	if expression.has_execute_failed():
		return [false, "cannot run: " + expression.get_error_text()]
	return [true, value]


func _sleep(seconds: float) -> void:
	var until := _clock + seconds
	while _clock < until:
		await get_tree().process_frame


func _key(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func _button(button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = _to_window(_pointer)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2, path: Variant) -> Dictionary:
	_pointer = at
	var motion := InputEventMouseMotion.new()
	motion.position = _to_window(at)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _sleep(TAP_S)
	_button(MOUSE_BUTTON_LEFT, true)
	await _sleep(TAP_S)
	_button(MOUSE_BUTTON_LEFT, false)
	await _sleep(TAP_S)
	return {"ok": true, "at": [at.x, at.y], "control": str(path)}


# Moves the pointer to the control's middle and says whether the control (or a part of it) is what
# the pointer is then over, as the engine itself answers it.
func _lands_on(control: Control) -> bool:
	# A captured mouse is the camera's (the ball is in play): no control can be clicked, and moving
	# the pointer to ask would turn the view.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return false
	_pointer = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = _to_window(_pointer)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(control):
		return false
	var under := get_viewport().gui_get_hovered_control()
	return under != null and (under == control or control.is_ancestor_of(under) or under.is_ancestor_of(control))


# A point of the game's view, as the window's own pixels (the view is stretched to the window).
func _to_window(point: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * point


func _shot(name: String) -> String:
	RenderingServer.render_loop_enabled = true
	# Two frames: the first one drawn after a pause in drawing can still hold the old picture.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = _live
	var file := "%02d-%s.png" % [_n, name]
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))
	return file


func _visible_controls() -> Array:
	var found: Array = []
	_walk(get_tree().root, found)
	return found


func _walk(node: Node, found: Array) -> void:
	if node is CanvasItem and not node.visible:
		return
	if node is CanvasLayer and not node.visible:
		return
	if node is Control and _words_of(node) != "" and _alpha(node) > 0.05:
		found.append(node)
	for child in node.get_children():
		_walk(child, found)


# How solid a control is drawn: its own alpha times every parent's (a faded-out screen is not on screen).
func _alpha(item: Node) -> float:
	var alpha := 1.0
	while item != null:
		if item is CanvasItem:
			alpha *= item.modulate.a
		item = item.get_parent()
	return alpha


func _words_of(control: Control) -> String:
	for property in ["text", "title", "label", "caption"]:
		var value: Variant = control.get(property)
		if value is String and value != "":
			return value
	return ""


func _find(words: String) -> Control:
	for control in _visible_controls():
		if _words_of(control).to_lower().contains(words.to_lower()):
			return control
	return null


# Splits a step into words, keeping a "quoted text" whole.
func _split(step: String) -> Array:
	var words: Array = []
	var word := ""
	var quoted := false
	for character in step:
		if character == "\"":
			quoted = not quoted
		elif character == " " and not quoted:
			if word != "":
				words.append(word)
			word = ""
		else:
			word += character
	if word != "":
		words.append(word)
	return words
