extends SceneTree

# A reel of the Spillway's crew at play speed (design-v3/SIGHT-PERSONA.md section 7, steps 4 and
# 5): the game on its dam, the chase camera and the HUD. First the panel pickup's pop at the ball
# (its shortest, middle and longest line, then one of the player's own hit words for scale). Then
# one kind at a time arrives ahead of the ball, works on it, takes a hit, stands stunned if it can
# be (the kinds built on counter.gd), and dies, with its name on screen.
# Record it with Godot's movie writer, which draws every frame at the stated rate whatever the
# machine's speed, so the film runs at play speed:
#   <godot> --path sketches/core-loop --resolution 1920x1080 --fixed-fps 60 --write-movie /abs/dir/reel.avi \
#     --script res://tools/sight_reel.gd -- --out=/abs/dir [--only=pop,chaser,lobber] [--captions=0]
# A display is needed for the film (xvfb-run works; the cloud's renderer judges motion and place,
# not the look). Headless, with --fixed-fps 60 and no --write-movie, it plays the same reel and
# writes only reel.json. The movie writer films from the engine's first frame, so the reel's
# seconds count from there too: reel.json's first_scene_s is where the lead-in (the load, the
# ball's opening drop, the opening toasts) ends.
#
# reel.json is the motion count, taken from the game and not from the film. Every frame, each part
# of the body is measured against the body itself (so travel is not counted), and a snap is the
# clip scan's own (tools/model_audit.py): a step faster than SNAP_DEG degrees a second or SNAP_M
# metres a second, and over SNAP_RATIO times the steps either side of it: one frame that jumps.
# Two fast steps in a row between slow ones count too: a part that jumps and jumps back.
# A snap on the frame a clip starts is a cut, which the wind-up, the attack, the hit and the death
# make by design (enemy_clips.gd), and so is the flinch a hit gives; it is listed and not counted. The pass line is no snap inside a
# clip, counted through the hit and the death clip too. A number cannot tell style from fault:
# watch the second it names before calling it a pop. The game steps its clips 90 times a second
# and the film draws 60, so a frame carries one step or two and speeds swing by up to a half:
# counts compare only between runs at the same --fixed-fps (reel.json says whether the step held).
# Skinned bones are not measured (the brute's pads), only the parts. For the pop, reel.json holds
# each line's width as a share of the view's width and its letters' height as a share of the
# view's height, counted as the player's words count theirs (player_fx.gd WORD_SCREEN).

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const EnemyClips := preload("res://src/presentation/enemy_clips.gd")
const MachineFx := preload("res://src/presentation/machine_fx.gd")
const PanelFx := preload("res://src/presentation/panel_fx.gd")
const Panels := preload("res://src/build/panels.gd")
const Palette := preload("res://src/core/palette.gd")

# The Spillway roster (design-v3/SPILLWAY-ROSTER.md), ordinary kinds first, then the specials.
const KINDS := ["chaser", "lobber", "mag_trapper", "jolt_layer", "catch_trap", "hooker", "ramp_flipper", "boom_tender", "plated_brute",
	"splitter", "linker", "foreman", "dispatcher", "miniboss"]
const BASE_KINDS := ["chaser", "lobber", "miniboss"]
const POP := "pop"
# A word's letters stand this share of its font size tall (player_fx.gd: 0.7 m of cap at 96 px).
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
# The flinch rises in a twentieth of a second and holds (event_kinds.gd REACTIONS): the frames
# after a hit are a cut, as a clip's first frame is.
const FLINCH_FRAMES := 8
const WAIT_TICKS := 2400
const QUIET_TICKS := 900
# The ball's centre this close over the ground is the ball on the ground.
const LANDED := 1.6

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
# What the count measures: the enemy, or the holder its look moves to when it dies.
var _body: Node3D
var _row := {}
var _parts := {}
var _clip := ""
var _cut_age := 0
var _step_min := INF
var _step_max := 0.0


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
	# Headless runs play no clips unless asked (enemy_clips.gd); the count needs them.
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
	# The run opens with the ball on its drop.
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
	var ahead := Vector3.BACK
	if is_instance_valid(game.flow.beacon):
		ahead = game.flow.beacon.global_position - spot
		ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
	game.player.reset_to(spot)
	await _ticks(2)
	game.player.body().freeze = true
	game.camera.snap(ahead)
	# The run's opening toasts and its first hint clear before the reel starts.
	await _ticks(QUIET_TICKS)
	_build_caption()
	var first_scene := snappedf(clock, 0.01)

	var at := spot + ahead * AHEAD
	at.y = Telegraph.ground_under(ground, at) + 1.0
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
		_row = {"kind": kind, "start_s": snappedf(clock, 0.01), "clips": false, "parts": 0, "frames": 0, "snaps": [], "cuts": [], "beats": {}}
		_say("%s  arrives and works" % kind)
		_enemy = game.combat.spawn_enemy(kind, at)
		_body = _enemy
		_parts.clear()
		_clip = ""
		await _seconds(WORK)
		if is_instance_valid(_enemy):
			_beat("hit")
			_say("%s  takes a hit" % kind)
			# The flinch a player's hit gives it (its hit clip rides on the reaction), and the damage.
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
			# A kind with a death clip hands its look to a holder in the world and is gone the
			# same frame (enemy_clips.gd die); the count follows the look.
			var pivot = _enemy.get("reaction_pivot")
			_enemy.take_damage(1.0e9)
			if pivot is Node3D and is_instance_valid(pivot) and pivot.get_parent() is Node3D and pivot.get_parent() != _enemy:
				_body = pivot.get_parent()
		await _seconds(DEATH)
		_row["end_s"] = snappedf(clock, 0.01)
		_row["in_clip"] = (_row["snaps"] as Array).size()
		# A kind that never stood, or that the light hit killed, was not counted through its death.
		_row["measured"] = int(_row["frames"]) > 0 and (_row["beats"] as Dictionary).has("death")
		rows.append(_row)
		_enemy = null
		_body = null
		# What a kind leaves behind (a splitter's halves, shells in the air) goes before the next.
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


# The panel pickup's pop as panel_fx.gd stamps it, for the shortest, the middle and the longest
# line a panel has, each for its whole life, then one of the player's own words beside the ball.
func _pop() -> void:
	var fx = game.presentation.machine_fx
	var label := MachineFx.word_label()
	var font := label.font if label.font != null else ThemeDB.fallback_font
	var lines := []
	for id in Panels.ids():
		var text := Panels.pop_text(id)
		lines.append([font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x, text])
	label.free()
	if lines.is_empty():
		return
	lines.sort_custom(func(a, b): return a[0] < b[0])
	var view := root.get_visible_rect().size
	for line in [lines[0], lines[lines.size() / 2], lines[-1]]:
		var text: String = line[1]
		_say("pickup pop  %s" % text)
		var before := _newest(fx)
		fx.word(text, game.player.shown_position() + Vector3.UP * PanelFx.POP_HEIGHT, Palette.SAND, true, PanelFx.POP_LIFE, PanelFx.POP_SIZE)
		var slot := _newest(fx)
		if slot.is_empty() or slot == before:
			return _fail("the pop did not stamp")
		await _seconds(PanelFx.POP_LIFE * 0.4)
		var word: Label3D = slot["node"]
		var cam := root.get_camera_3d()
		var at: Vector3 = slot["at"]
		var px_per_m := cam.unproject_position(at + cam.global_basis.x).distance_to(cam.unproject_position(at))
		var metres: float = word.pixel_size * word.scale.x
		pops.append({"text": text, "reel_s": snappedf(clock, 0.01), "scale": snappedf(word.scale.x, 0.001),
			"width_of_view": snappedf(float(slot["width_px"]) * metres * px_per_m / view.x, 0.001),
			"letters_of_height": snappedf(word.font_size * CAP * metres * px_per_m / view.y, 0.0001)})
		await _seconds(PanelFx.POP_LIFE * 0.6 + GAP)
	# The player's word may be refused (its own gap and density rules); the count says so.
	hit_word = game.presentation.player_fx.word("wham", game.player.shown_position() + Vector3.UP * 1.8)
	_say("the player's own hit word, for scale" if hit_word else "")
	await _seconds(1.5)
	_say("")
	await _seconds(GAP)


# The word slot machine_fx stamped last (its pool is a ring).
static func _newest(fx) -> Dictionary:
	var words: Array = fx._words
	return words[posmod(int(fx._word_next) - 1, words.size())] if not words.is_empty() else {}


# One step of the count, every drawn frame: each part against the body, and a snap named once
# the step after it is known.
func _process(delta: float) -> bool:
	clock += delta
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
		# The clip's joints carry the parts; the parts are what is drawn.
		if node is GPUParticles3D or node is CPUParticles3D or node is Label3D or node is CollisionShape3D \
				or String(node.name).begins_with(EnemyClips.JOINT_PREFIX):
			continue
		var id: int = node.get_instance_id()
		# A hidden part starts again when it shows: its last pose is stale by then.
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
		# The step onto a clip's first frame, or off its last, is the cut.
		(part["cut"] as Array).append(_cut_age <= 1)
		part["at"] = now.origin
		part["turn"] = turn
		for unit in ["deg", "m"]:
			var steps: Array = part[unit]
			if steps.size() < 4:
				continue
			# steps[1] is judged once the two after it are known: alone, or with steps[2] as a pair
			# (a part that jumps and jumps back is two fast steps, which the lone test cannot see).
			var floor_speed := SNAP_DEG if unit == "deg" else SNAP_M
			# The second step of a pair already named is not named again on its own.
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


# The kind's clip driver (enemy_clips.gd seats it on the body's pivot), or null for a kind with no clips.
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


# Game seconds, by the reel's own clock (the movie writer fixes the step).
func _seconds(n: float) -> void:
	var until := clock + n
	while clock < until:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
