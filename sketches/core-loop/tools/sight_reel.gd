extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const EnemyClips := preload("res://src/presentation/enemy_clips.gd")
const PanelFx := preload("res://src/presentation/panel_fx.gd")
const PickupLines := preload("res://src/ui/pickup_lines.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const Panels := preload("res://src/build/panels.gd")
const Palette := preload("res://src/core/palette.gd")
const MossBubble := preload("res://src/ui/moss_bubble.gd")

const KINDS := ["chaser", "lobber", "mag_trapper", "jolt_layer", "catch_trap", "hooker", "ramp_flipper", "boom_tender", "plated_brute",
	"splitter", "linker", "foreman", "dispatcher", "miniboss"]
const BASE_KINDS := ["chaser", "lobber", "miniboss"]
const POP := "pop"
const CAP := 0.7 / 0.96
const AHEAD := 14.0
const WORK := 8.0
const HIT := 1.0
const STUN := 2.0
const DEATH := 2.5
const GAP := 0.5
const SNAP_DEG := 360.0
const SNAP_M := 3.0
const SNAP_RATIO := 4.0
const FLINCH_FRAMES := 8
const WAIT_TICKS := 2400
const QUIET_TICKS := 900
const LANDED := 1.6
const HULL := 999999.0
const CLOSE_M := 7.0
const CLOSE_UP := 2.4
const CLOSE_AIM := 1.0
const CLOSE_TURN := 0.6

var game
var out := ""
var only: Array = [POP] + KINDS
var captions := true
var failed := ""
var rows := []
var pops := []
var hit_word := false
var clock := 0.0

var _caption: Label
var _enemy: Node3D
var _body: Node3D
var _row := {}
var _parts := {}
var _clip := ""
var _cut_age := 0
var _step_min := INF
var _step_max := 0.0
var _play_camera: Camera3D
var _close_camera: Camera3D
var _close := false
var _spot := Vector3.ZERO
var _bubble: Node


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
		elif arg.begins_with("--captions="):
			captions = arg.trim_prefix("--captions=") != "0"
	if out.is_empty():
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(3)
		return
	EnemyClips.headless = true
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	var waited := 0
	while game.flow == null and waited < 600:
		waited += 1
		await physics_frame
	if game.flow == null:
		return _fail("the game never built its flow")
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	var ground = game.ctx.spawner.ground
	var down := 0
	for i in WAIT_TICKS:
		await physics_frame
		var p: Vector3 = game.player.ball_position()
		down = down + 1 if p.y - Telegraph.ground_under(ground, p) < LANDED else 0
		if down >= 30:
			break
	if down < 30:
		return _fail("the ball never landed")
	if game.hud.get("first_steps") != null:
		game.hud.first_steps.modulate.a = 0.0
	var spot: Vector3 = game.player.ball_position()
	_spot = spot
	var ahead := Vector3.BACK
	if is_instance_valid(game.flow.beacon):
		ahead = game.flow.beacon.global_position - spot
		ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
	game.player.reset_to(spot)
	await _ticks(2)
	game.player.body().freeze = true
	game.camera.snap(ahead)
	await _ticks(QUIET_TICKS)
	_build_caption()
	var first_scene := snappedf(clock, 0.01)

	var at := spot + ahead * AHEAD
	at.y = Telegraph.ground_under(ground, at) + 1.0
	_hush()
	if POP in only:
		await _pop()
	for kind in only:
		if failed != "":
			return
		if kind == POP:
			continue
		if not (kind in BASE_KINDS or game.combat.fleet.makes(kind)):
			rows.append({"kind": kind, "skipped": "the game makes no such kind"})
			continue
		if not game.run.alive():
			return _fail("the ball was scrapped before the %s" % kind)
		game.run.set_max_hp(HULL)
		game.run.heal(HULL)
		_hush()
		_row = {"kind": kind, "start_s": snappedf(clock, 0.01), "clips": false, "parts": 0, "frames": 0, "snaps": [], "cuts": [], "beats": {}}
		_say("%s  arrives and works" % kind)
		_enemy = game.combat.spawn_enemy(kind, at)
		_body = _enemy
		_parts.clear()
		_clip = ""
		await _seconds(WORK)
		if is_instance_valid(_enemy):
			_closeup(true)
			_beat("hit")
			_say("%s  takes a hit" % kind)
			if _enemy.has_method("react"):
				_enemy.react("stagger", _enemy.global_position - spot)
			_enemy.take_damage(1.0)
			_cut_age = -FLINCH_FRAMES
			await _seconds(HIT)
		if is_instance_valid(_enemy) and _enemy.get("stun_left") != null:
			_beat("stun")
			_say("%s  stunned" % kind)
			_enemy.stun_left = STUN
			await _seconds(STUN)
		if is_instance_valid(_enemy):
			_beat("death")
			_say("%s  dies" % kind)
			var pivot = _enemy.get("reaction_pivot")
			_enemy.take_damage(1.0e9)
			if pivot is Node3D and is_instance_valid(pivot) and pivot.get_parent() is Node3D and pivot.get_parent() != _enemy:
				_body = pivot.get_parent()
		await _seconds(DEATH)
		_closeup(false)
		if not game.run.alive():
			return _fail("the ball was scrapped while the %s was up" % kind)
		_row["hull_left"] = snappedf(game.run.hp / game.run.max_hp, 0.001)
		_row["end_s"] = snappedf(clock, 0.01)
		_row["in_clip"] = (_row["snaps"] as Array).size()
		_row["measured"] = int(_row["frames"]) > 0 and (_row["beats"] as Dictionary).has("death")
		rows.append(_row)
		_enemy = null
		_body = null
		for group in ["enemy", "enemy_shot"]:
			for node in get_nodes_in_group(group):
				if is_instance_valid(node):
					node.queue_free()
		_say("")
		await _seconds(GAP)

	var file := FileAccess.open(out.path_join("reel.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	var size := root.get_visible_rect().size
	file.store_string(JSON.stringify({"tool": "sight_reel.gd", "table": game.table, "size": [size.x, size.y],
		"adapter": RenderingServer.get_video_adapter_name(), "seconds": snappedf(clock, 0.01), "first_scene_s": first_scene,
		"fixed_fps": is_equal_approx(_step_min, _step_max), "frame_s": [snappedf(_step_min, 0.0001), snappedf(_step_max, 0.0001)],
		"snap": {"deg_s": SNAP_DEG, "m_s": SNAP_M, "ratio": SNAP_RATIO}, "pop": pops, "hit_word_shown": hit_word, "kinds": rows,
		"limits": "One of each kind against a ball that stands still, so no pack, no chase and no knock. Parts only, not skinned bones. The count is the game's motion and compares between runs at the same fixed frame rate; the look is the film's, and only on the PC."}, "\t"))
	file.close()
	quit(0)


func _pop() -> void:
	var font := UiFonts.bold()
	var lines := []
	for id in Panels.ids():
		var text := Panels.pop_text(id)
		lines.append([font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PickupLines.FONT).x, text])
	if lines.is_empty():
		return
	lines.sort_custom(func(a, b): return a[0] < b[0])
	var view := root.get_visible_rect().size
	var shown: Control = game.hud.pickup_lines
	for line in [lines[0], lines[lines.size() / 2], lines[-1]]:
		var text: String = line[1]
		_say("pickup pop  %s" % text)
		shown.show_line(text, Palette.SAND, 0, PanelFx.POP_LIFE)
		await _seconds(PanelFx.POP_LIFE * 0.4)
		if not text in shown.drawn_words():
			return _fail("the pop did not show")
		var scale := shown.get_global_transform_with_canvas().get_scale().y
		pops.append({"text": text, "reel_s": snappedf(clock, 0.01), "scale": snappedf(scale, 0.001),
			"width_of_view": snappedf(float(line[0]) * scale / view.x, 0.001),
			"letters_of_height": snappedf(PickupLines.FONT * CAP * scale / view.y, 0.0001)})
		await _seconds(PanelFx.POP_LIFE * 0.6 + GAP)
	hit_word = game.presentation.player_fx.word("wham", game.player.shown_position() + Vector3.UP * 1.8)
	_say("the player's own hit word, for scale" if hit_word else "")
	await _seconds(1.5)
	_say("")
	await _seconds(GAP)


func _process(delta: float) -> bool:
	clock += delta
	_aim_close()
	if not is_instance_valid(_body) or delta <= 0.0 or _row.is_empty():
		return false
	_step_min = minf(_step_min, delta)
	_step_max = maxf(_step_max, delta)
	var driver := _driver(_body)
	var clip: String = String(driver.clip) if driver != null else ""
	if driver != null:
		_row["clips"] = true
	_cut_age = 0 if clip != _clip else _cut_age + 1
	_clip = clip
	_row["frames"] = int(_row["frames"]) + 1
	var inverse := _body.global_transform.affine_inverse()
	for node in _body.find_children("*", "Node3D", true, false):
		if node is GPUParticles3D or node is CPUParticles3D or node is Label3D or node is CollisionShape3D \
				or String(node.name).begins_with(EnemyClips.JOINT_PREFIX):
			continue
		var id: int = node.get_instance_id()
		if not node.is_visible_in_tree():
			_parts.erase(id)
			continue
		var now: Transform3D = inverse * (node as Node3D).global_transform
		var turn := now.basis.get_rotation_quaternion()
		if not _parts.has(id):
			_parts[id] = {"name": String(node.name), "at": now.origin, "turn": turn, "deg": [], "m": [], "clip": [], "cut": [], "paired": {}}
			_row["parts"] = _parts.size()
			continue
		var part: Dictionary = _parts[id]
		(part["deg"] as Array).append(rad_to_deg((part["turn"] as Quaternion).angle_to(turn)) / delta)
		(part["m"] as Array).append((part["at"] as Vector3).distance_to(now.origin) / delta)
		(part["clip"] as Array).append(clip)
		(part["cut"] as Array).append(_cut_age <= 1)
		part["at"] = now.origin
		part["turn"] = turn
		for unit in ["deg", "m"]:
			var steps: Array = part[unit]
			if steps.size() < 4:
				continue
			var floor_speed := SNAP_DEG if unit == "deg" else SNAP_M
			var named: bool = (part["paired"] as Dictionary).get(unit, false)
			part["paired"][unit] = false
			if named:
				continue
			var lone: bool = steps[1] > floor_speed and steps[1] > SNAP_RATIO * maxf(maxf(steps[0], steps[2]), 1.0e-6)
			var pair: bool = not lone and steps[1] > floor_speed and steps[2] > floor_speed \
				and maxf(steps[1], steps[2]) > SNAP_RATIO * maxf(maxf(steps[0], steps[3]), 1.0e-6)
			part["paired"][unit] = pair
			if lone or pair:
				var cut: bool = part["cut"][1] or part["cut"][2] or (pair and part["cut"][3])
				(_row["cuts" if cut else "snaps"] as Array).append({"part": part["name"], "clip": part["clip"][1],
					"reel_s": snappedf(clock - delta * 2.0, 0.01), "frames": 2 if pair else 1,
					"speed": snappedf(maxf(steps[1], steps[2]) if pair else steps[1], 0.1),
					"beside": snappedf(maxf(steps[0], steps[3] if pair else steps[2]), 0.1), "unit": "deg/s" if unit == "deg" else "m/s"})
		if (part["deg"] as Array).size() >= 4:
			for key in ["deg", "m", "clip", "cut"]:
				(part[key] as Array).pop_front()
	return false


func _closeup(on: bool) -> void:
	if on and _close_camera == null:
		_play_camera = root.get_camera_3d()
		_close_camera = Camera3D.new()
		_close_camera.name = "ReelClose"
		if _play_camera != null:
			_close_camera.fov = _play_camera.fov
			_close_camera.far = _play_camera.far
		root.add_child(_close_camera)
	_close = on
	if on:
		_aim_close()
		_close_camera.make_current()
	elif is_instance_valid(_play_camera):
		_play_camera.make_current()


func _aim_close() -> void:
	if not _close or not is_instance_valid(_body) or not is_instance_valid(_close_camera):
		return
	var at: Vector3 = _body.global_position
	var back := _spot - at
	back.y = 0.0
	back = (back.normalized() if back.length() > 0.5 else Vector3.BACK).rotated(Vector3.UP, CLOSE_TURN)
	var eye := at + back * CLOSE_M + Vector3.UP * CLOSE_UP
	_close_camera.look_at_from_position(eye, at + Vector3.UP * CLOSE_AIM, Vector3.UP)


func _hush() -> void:
	if _bubble == null:
		for node in game.find_children("*", "Control", true, false):
			if node.get_script() == MossBubble:
				_bubble = node
				break
	if is_instance_valid(_bubble) and _bubble.showing():
		_bubble.dismiss_exchange()
		_bubble.hush()


static func _driver(enemy: Node) -> Node:
	var found := enemy.find_child("EnemyClips", true, false)
	return found if found != null and found.get_script() == EnemyClips else null


func _beat(id: String) -> void:
	(_row["beats"] as Dictionary)[id] = snappedf(clock, 0.01)


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	root.add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_caption.position += Vector2(24.0, -150.0)
	_caption.visible = captions
	layer.add_child(_caption)


func _say(text: String) -> void:
	if _caption != null:
		_caption.text = text.replace("_", " ").to_upper()


func _fail(why: String) -> void:
	if failed != "":
		return
	failed = why
	push_error("sight_reel: %s" % why)
	quit(4)


func _seconds(n: float) -> void:
	var until := clock + n
	while clock < until:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
