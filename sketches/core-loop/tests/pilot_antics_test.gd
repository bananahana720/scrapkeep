extends SceneTree

# Pilots climbing out of their balls (pilot_antics.gd) in the three places they play: the title
# openings, the title deck and the pilot select cards; plus "look closer" on the deck and the
# cards, and the bosses' closer card. TTL_CAPTURE_DIR saves stills of each pilot's move in its
# opening and of the deck look on a rendered display.

const Game := preload("res://src/game.gd")
const PilotAntics := preload("res://src/presentation/pilot_antics.gd")
const TitleIntros := preload("res://src/presentation/title_intros.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const T := preload("res://tests/support/t.gd")
const AppShell := preload("res://src/core/app_shell.gd")

var _t := T.new("pilot_antics_test")
var _capture := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture = OS.get_environment("TTL_CAPTURE_DIR")
	if _capture != "":
		if AppShell.headless():
			_t.check("capture requires a rendered display", false)
			quit(_t.verdict())
			return
		root.size = Vector2i(1600, 900)
		DirAccess.make_dir_recursive_absolute(_capture)
	_moves()
	await _shells()
	var game := Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	await process_frame
	await physics_frame
	var display = game.presentation.title_stage
	var bodies := _bodies(root)
	await _openings(display)
	await _deck(game, display)
	await _cards()
	_t.eq("body count unchanged", _bodies(root), bodies)
	game.free()
	await process_frame
	quit(_t.verdict())


func _moves() -> void:
	var seen := {}
	for id in PilotAntics.MOVES:
		var mid: Dictionary = PilotAntics.pose_at(id, 0.5)
		var signature := "%s|%.2f|%.2f|%.2f" % [mid.at.snapped(Vector3.ONE * 0.1), mid.yaw, mid.spin, mid.roll]
		_t.check(id + " has its own move", not seen.has(signature))
		seen[signature] = true
		_t.check(id + " has a word and a line", PilotAntics.word(id) != "" and PilotAntics.line(id) != "")
		var start: Dictionary = PilotAntics.pose_at(id, 0.0)
		var finish: Dictionary = PilotAntics.pose_at(id, 0.999)
		_t.check(id + " starts and ends in the pod", start.at.distance_to(PilotAntics.SEAT) < 0.05
			and finish.at.distance_to(PilotAntics.SEAT) < 0.1)
	for row in TitleIntros.ROWS:
		if row.kind == "pilot":
			_t.check(String(row.pilot) + " has a move", PilotAntics.has_move(String(row.pilot)))
	_t.eq("six distinct moves", seen.size(), 6)


# Each real shell and pilot: out mid-move, back in the pod as it was after.
func _shells() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var painter := HeroAssets.new()
	for id in PilotAntics.MOVES:
		var holder := Node3D.new()
		holder.position = Vector3(0.0, 1.04, 0.0)
		stage.add_child(holder)
		var shell := (load(HeroAssets.SHELLS[id]) as PackedScene).instantiate() as Node3D
		holder.add_child(shell)
		var pod := shell.find_child("Pod", true, false) as Node3D
		var core := shell.find_child("Core", true, false) as Node3D
		var fitted := painter.fit_pilot_into(pod, id, Color.WHITE)
		if not _t.check(id + " pilot fits", not fitted.is_empty() and pod != null and core != null):
			continue
		var pilot: Node3D = fitted.pilot
		var seated := pilot.transform
		var seated_at := pilot.global_position
		var core_rest := core.transform
		for entry in PilotAntics.MOVES[id].clips:
			_t.check("%s clip %s plays or falls back" % [id, entry[1]], PilotAntics.clip_for(fitted.animator, String(entry[1])) != "")
		var antic := PilotAntics.new({"holder": holder, "core": core, "pod": pod, "pilot": pilot, "animator": fitted.animator}, id)
		antic.apply(0.5)
		await process_frame
		_t.check(id + " climbs out of the pod", antic.out and pilot.get_parent() == holder)
		_t.check(id + " is visibly away from the seat", pilot.global_position.distance_to(seated_at) > 0.4)
		antic.apply(1.0)
		_t.check(id + " is back in the pod as it sat", not antic.out and pilot.get_parent() == pod
			and pilot.transform.is_equal_approx(seated) and core.transform.is_equal_approx(core_rest))
		_stream(antic, fitted.animator, pilot, id)
		await _in_engine(antic, fitted.animator, pilot, id)
	painter.free()
	stage.free()


# The whole bit sampled at 1/60 s, the way a 60 fps display would see it. One continuous
# performance means: (a) no frame-to-frame bone rotation jump above what the pilot's own clips
# move in one frame, (b) no segment asks a clip for time past its end (a hold), (c) the last
# frame before the pod takes the pilot back is at rest, so seat() snaps nothing.
#
# (a) The threshold is per bone: that bone's largest one-frame rotation (angle between frames) in
# the pilot's own clips as this move plays them (clip time stepped by speed/60), measured by
# _clip_motion at run time. Measured on 21 Oct 2026 at clip speed 1.0 (Godot 4.7.2): drop_land
# 0.90 (Sable), 0.48 (Rivet), 0.84 (Kest), 0.06 (Tarn), 0.03 (Tally), 0.05 (Cannon); big_cheer
# 0.17 to 0.18 (Sable, Rivet, Kest), 0.06 (Tarn), 0.11 (Tally, Cannon); cast_line 1.50 (Tally).
# (c) REST_TOLERANCE is 0.02 rad: an authored clip's rest key sits 0.0007 rad off the skeleton's
# bind rest (measured, every pilot), so 0.02 is 28 times that floor and still under a degree.
const REST_TOLERANCE := 0.02
# The move is sampled at 1/60 s from t 0, a clip's own motion at 1/60 s from clip time 0, so the
# frames land in different phases; SLACK 1.1 covers that (Cannon's base run: 0.066 against 0.066).
# BONE_FLOOR 0.02 rad (1.1 degrees, the same as REST_TOLERANCE) lets a bone that no clip moves absorb rounding (the clips' rest noise is
# 0.0007 rad); any real pop on such a bone is far above it.
const BONE_FLOOR := 0.02
const SLACK := 1.1
const FRAME := 1.0 / 60.0
# Chosen: a 25 degree planted pop, 6.6x and 19.9x the per-bone limit on the two control bones.
const POP := 0.436
# Chosen: the most new clip samples (cache misses) one apply() may take. Measured 3 at worst on all six bits (fixed grid
# plus caches); without the grid cache a late frame seeks one sample per grid point already passed,
# up to the bit's 224 frames.
const SEEK_CAP := 4


func _stream(antic, animator: AnimationPlayer, pilot: Node3D, id: String) -> void:
	var skeleton := pilot.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	skeleton.reset_bone_poses()
	var rest := _rotations(skeleton)
	var rows: Array = antic.segments()
	var limits: Array = []
	limits.resize(rest.size())
	limits.fill(BONE_FLOOR)
	var past_end := ""
	var peak := 0.0
	var peak_clip := ""
	for row in rows:
		if row.clip == "":
			continue
		var moved := _clip_motion(animator, skeleton, row.clip, row.speed, row.length)
		for i in moved.size():
			limits[i] = maxf(limits[i], moved[i])
			if moved[i] > peak:
				peak = moved[i]
				peak_clip = "%s at %.3f" % [row.clip, row.speed]
		var asks: float = (float(row.end) - float(row.start)) * PilotAntics.LENGTH * float(row.speed)
		if asks > float(row.length) + 0.001:
			past_end += " %s asks %.2f of %.2f s;" % [row.clip, asks, row.length]
	animator.stop()
	skeleton.reset_bone_poses()
	_t.check("%s never holds a clip past its end:%s" % [id, past_end], past_end == "")
	# _lift tells a flipped sign from a real turn by the sign of the dot product between frames,
	# which is sound for any turn under PI per frame. PI/2 is chosen as half that, for margin.
	_t.check("%s clips turn no bone PI/2 in a frame (%.3f rad, %s)" % [id, peak, peak_clip], peak < PI / 2.0)
	var run := _scan(antic, skeleton, limits, rest)
	_t.check("%s ends the bit at rest (%.3f rad off)" % [id, _step(rest, run.last)], _step(rest, run.last) <= REST_TOLERANCE)
	antic.apply(1.0)
	var after := _rotations(skeleton)
	var seat_over := 0.0
	for i in after.size():
		seat_over = maxf(seat_over, (run.last[i] as Quaternion).angle_to(after[i]) / (limits[i] * SLACK))
	_t.check("%s seat() snaps nothing (%.2f of the per-bone limit)" % [id, seat_over], seat_over <= 1.0)
	_t.check("%s moves no bone faster than its own clips: %s %.3f rad/frame at t %.3f against %.3f (%.2f of limit)" \
		% [id, run.bone, run.step, run.at, run.limit, run.over], run.over <= 1.0)
	# Positive control: the same scan must fire on a 25 degree pop planted on one bone for one
	# frame (Sable's spine mid-bit, Tally's left hand inside the first stamp's fade-in).
	var plant := {}
	if id == "pylon_engineer":
		plant = {"bone": _bone_like(skeleton, "spine"), "frame": int(0.5 * PilotAntics.LENGTH / FRAME)}
	elif id == "tally":
		plant = {"bone": skeleton.find_bone("hand.L"), "frame": int((0.2 * PilotAntics.LENGTH + 0.1) / FRAME)}
	if not plant.is_empty():
		_t.check("%s has the control bone" % id, plant.bone >= 0)
	if not plant.is_empty() and plant.bone >= 0:
		skeleton.reset_bone_poses()
		var pop := _scan(antic, skeleton, limits, rest, plant)
		_t.check("%s pop check fires on a planted 25 degree pop on %s (%.2f of limit %.3f)" \
			% [id, skeleton.get_bone_name(plant.bone), pop.over, limits[plant.bone]], pop.over > 1.0)
		antic.apply(1.0)
	_cost(antic, id)
	animator.stop()
	skeleton.reset_bone_poses()


# Walks the bit at 1/60 s. plant: {bone, frame} twists that bone by POP for that one frame after
# apply(). Returns the worst step as a share of its bone's limit, with where it was.
func _scan(antic, skeleton: Skeleton3D, limits: Array, rest: Array, plant: Dictionary = {}) -> Dictionary:
	var run := {"over": 0.0, "step": 0.0, "at": 0.0, "bone": "", "limit": 0.0, "last": rest}
	var before := rest
	for k in int(floor(PilotAntics.LENGTH / FRAME)) + 1:
		var t := float(k) * FRAME / PilotAntics.LENGTH
		antic.apply(t)
		if not plant.is_empty() and k == plant.frame:
			var b: int = plant.bone
			skeleton.set_bone_pose_rotation(b, skeleton.get_bone_pose_rotation(b) * Quaternion(Vector3.RIGHT, POP))
		var now := _rotations(skeleton)
		for i in now.size():
			var step: float = (before[i] as Quaternion).angle_to(now[i])
			if step / (limits[i] * SLACK) > run.over:
				run.over = step / (limits[i] * SLACK)
				run.step = step
				run.at = t
				run.bone = skeleton.get_bone_name(i)
				run.limit = limits[i]
		before = now
		run.last = now
	return run


func _bone_like(skeleton: Skeleton3D, part: String) -> int:
	for i in skeleton.get_bone_count():
		if String(skeleton.get_bone_name(i)).contains(part):
			return i
	return 0


# Work per apply() at every 1/60 s frame of the bit: the new clip samples it takes (cache misses,
# new entries in the antic's _memo; the one seek that poses a cached plain-path frame is not counted). Counted, not timed: the sketch lint forbids wall-clock reads in tests, and
# headless time on this box says nothing about a player's machine (frame cost is NEEDS: gpu).
func _cost(antic, id: String) -> void:
	var seeks: Array = []
	var at: Array = []
	for k in int(floor(PilotAntics.LENGTH / FRAME)) + 1:
		var t := float(k) * FRAME / PilotAntics.LENGTH
		var before: int = antic._memo.size()
		antic.apply(t)
		seeks.append(antic._memo.size() - before)
		at.append(t)
	var sorted := seeks.duplicate()
	sorted.sort()
	var worst: int = sorted[sorted.size() - 1]
	print("COST %s apply() max %d new clip samples at t %.3f, p95 %d, median %d (%d frames)" % [id, worst,
		at[seeks.find(worst)], sorted[int(sorted.size() * 0.95)], sorted[sorted.size() / 2], sorted.size()])
	_t.check("%s apply() takes at most %d new clip samples a frame (%d)" % [id, SEEK_CAP, worst], worst <= SEEK_CAP)
	antic.apply(1.0)


# Real process frames: the bit's pose must survive the engine running the animator and the scene
# between apply() calls, and survive another clip being played on the animator mid-bit (a card's
# unlock clip ending into its idle loop). Three frames cover both write paths: a plain clip
# drive (0.45), a fade-out to rest (0.1 s before the end) and, where the second segment fades
# in, that fade-in.
func _in_engine(antic, animator: AnimationPlayer, pilot: Node3D, id: String) -> void:
	var skeleton := pilot.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var rows: Array = antic.segments()
	var times := {"drive": 0.45, "fade-out": 1.0 - 0.1 / PilotAntics.LENGTH}
	if PilotAntics._window(id, 1) > 0.05:
		times["fade-in"] = float(rows[1].start) + 0.05 / PilotAntics.LENGTH
	for label in times:
		var t: float = times[label]
		antic.apply(t)
		var posed := _rotations(skeleton)
		await process_frame
		await process_frame
		var kept := _step(posed, _rotations(skeleton))
		_t.check("%s keeps its %s pose through engine frames (%.4f rad)" % [id, label, kept], kept < 0.001)
		var other := "brace" if animator.has_animation("brace") else String(animator.get_animation_list()[0])
		animator.play(other, 0.0)
		await process_frame
		antic.apply(t)
		await process_frame
		var again := _step(posed, _rotations(skeleton))
		_t.check("%s retakes the animator at %s after another clip played (%.4f rad)" % [id, label, again],
			again < 0.001 and not animator.is_playing())
	antic.apply(1.0)


func _clip_motion(animator: AnimationPlayer, skeleton: Skeleton3D, clip: String, speed: float, length: float) -> Array:
	animator.play(clip, 0.0)
	animator.pause()
	var before: Array = []
	var worst: Array = []
	worst.resize(skeleton.get_bone_count())
	worst.fill(0.0)
	var at := 0.0
	while true:
		animator.seek(minf(at, length), true)
		var now := _rotations(skeleton)
		if not before.is_empty():
			for i in now.size():
				worst[i] = maxf(worst[i], (before[i] as Quaternion).angle_to(now[i]))
		before = now
		if at >= length:
			break
		at += FRAME * speed
	return worst


func _rotations(skeleton: Skeleton3D) -> Array:
	var rows: Array = []
	for i in skeleton.get_bone_count():
		rows.append(skeleton.get_bone_pose_rotation(i))
	return rows


func _step(a: Array, b: Array) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, (a[i] as Quaternion).angle_to(b[i]))
	return worst


func _openings(display) -> void:
	for row in TitleIntros.ROWS:
		var kinds: Array = TitleIntros.shots(String(row.id)).map(func(s): return String(s.kind))
		_t.eq(String(row.id) + " has a hop-out only if it is a pilot", kinds.has("antics"), row.kind == "pilot")
	for id in ["sable", "rivet", "kest", "tarn", "tally", "cannon"]:
		if not _t.check(id + " opening starts", display.play_intro(id)):
			continue
		var player = display.intro
		var shots: Array = TitleIntros.shots(id)
		var at := 0.0
		for shot in shots:
			if shot.kind == "antics":
				break
			at += float(shot.bars) * TitleIntros.BAR
		var span := 2.0 * TitleIntros.BAR
		var frames := [0.12, 0.45, 0.8] if _capture != "" else [0.45]
		for f in frames:
			player.advance(at + span * f - player.clock)
			_t.eq(id + " frames the hop-out", player.shot_kind(), "antics")
			_t.check(id + " pilot is out of the ball at %.2f" % f, player._antics != null and player._antics.out)
			if _capture != "":
				await _shot("antics-%s-%02d" % [id, int(f * 100)])
		player.advance(at + span + 0.1 - player.clock)
		_t.check(id + " pilot is back in after the hop-out", player._antics != null and not player._antics.out)
		display.intro.skip()
		await process_frame
	if _t.check("a boss opening starts", display.play_intro("brindle")):
		var player = display.intro
		var at := 0.0
		for shot in TitleIntros.shots("brindle"):
			if shot.kind == "card":
				break
			at += float(shot.bars) * TitleIntros.BAR
		player.advance(at + 0.2 - player.clock)
		var subject: Node3D = player._subject
		var gap: float = display.camera.global_position.distance_to(subject.global_position) / player._subject_size
		_t.check("the boss card frames close (%.2f sizes away)" % gap, gap < 2.8)
		if _capture != "":
			await _shot("boss-card-brindle")
		display.intro.skip()
		await process_frame


func _deck(game, display) -> void:
	var antics: Array = display.deck_antics
	_t.eq("each deck pilot has a move", antics.filter(func(a): return a != null).size(), 3)
	var turn := 1
	# Whoever the gate pilot is, the bow's hero holds the pose on their turn and the crew take theirs.
	for bow in ["pylon_engineer", "runner_gunner"]:
		display.cast_hero(bow)
		var hero: int = antics.find_custom(func(a): return a != null and a.holder == display._hero)
		_t.check("%s stands at the bow" % bow, hero >= 0 and String(display.PILOTS[hero].id) == bow)
		turn = 1 if hero != 1 else 2
		display._clock = display.ANTIC_PERIOD * turn + display.ANTIC_DELAY + PilotAntics.LENGTH * 0.5
		display._step_antics()
		_t.check("with %s at the bow, the crew pilot whose turn it is is out alone" % bow,
			antics[turn].out and range(antics.size()).all(func(i): return i == turn or not antics[i].out))
		display._clock = display.ANTIC_PERIOD * hero + display.ANTIC_DELAY + PilotAntics.LENGTH * 0.5
		display._step_antics()
		_t.check("and %s holds the pose on their own turn" % bow, antics.all(func(a): return not a.out))
	display._clock = display.ANTIC_PERIOD * (turn + 1) + 0.5
	display._step_antics()
	_t.check("and back in after it", not antics[turn].out)
	var mid: float = display.ANTIC_PERIOD * turn + display.ANTIC_DELAY + PilotAntics.LENGTH * 0.5
	display._clock = mid
	display._step_antics()
	_t.check("a crew pilot is out mid-move", antics[turn].out)
	display.active = false
	display._sync_dressing()
	_t.check("a deck stopped mid-move puts its pilot back in", not antics[turn].out)
	display.active = true
	display._sync_dressing()
	HighdraftFx.preferred = true
	display._clock = mid
	display._step_antics()
	_t.check("reduced motion keeps the deck pilots seated", antics.all(func(a): return not a.out))
	HighdraftFx.preferred = false
	display.cast_hero("pylon_engineer")
	var deck_at: Vector3 = display.camera.global_position
	display.look_begin()
	display.look_target = 2
	display.look_drag(Vector2(40.0, 10.0))
	for i in 30:
		display._step_look(1.0 / 30.0)
	display._frame()
	var target: Vector3 = display.stage.get_node(String(display.PILOTS[2].name)).position
	_t.check("look closer moves the camera to the pilot", display.camera.global_position.distance_to(target)
		< deck_at.distance_to(target) * 0.5)
	display.look_zoom(3.0)
	_t.check("the wheel zooms in", float(display._look.dist) < display.LOOK_DIST)
	if _capture != "":
		display._frame()
		await _shot("deck-look-kest")
	for i in 120:
		display._step_look(1.0 / 30.0)
	display._frame()
	_t.check("letting go drifts back to the deck", display.look_weight < 0.01
		and display.camera.global_position.distance_to(deck_at) < 1.5)
	# A gate pilot from off the deck stands at the bow as HeroShell, and look closer orbits them too.
	display.cast_hero("tally")
	var bow: Node3D = display.stage.get_node_or_null("HeroShell")
	_t.check("an off-deck gate pilot stands at the bow", bow != null and bow == display._hero)
	if bow != null:
		display._frame()
		var away: Vector3 = display.camera.global_position
		display.look_begin(display.camera.unproject_position(bow.position) / (Vector2(display.viewport.size) / display.get_viewport().get_visible_rect().size))
		_t.eq("pointing at the bow picks its pilot", display.look_target, display.PILOTS.size())
		display.look_drag(Vector2(40.0, 10.0))
		for i in 30:
			display._step_look(1.0 / 30.0)
		display._frame()
		_t.check("look closer orbits the bow's pilot", display.camera.global_position.distance_to(bow.position)
			< away.distance_to(bow.position) * 0.6, "%.2f from %.2f" % [display.camera.global_position.distance_to(bow.position), away.distance_to(bow.position)])
		for i in 120:
			display._step_look(1.0 / 30.0)
	display.cast_hero("pylon_engineer")
	display._frame()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(800.0, 500.0)
	display._unhandled_input(press)
	_t.check("a right press on the title starts a look", display.looking())
	press.pressed = false
	display._unhandled_input(press)
	game.flow.press_start()
	display._look_idle = display.LOOK_HOLD
	press.pressed = true
	display._unhandled_input(press)
	_t.check("pilot select leaves the deck look to the cards", not display._look_dragging)
	press.pressed = false
	display._unhandled_input(press)
	game.flow.show_title()


func _cards() -> void:
	var def = ClassDef.by_id("tally")
	var preview := ClassPreview.new(def)
	root.add_child(preview)
	await process_frame
	_t.check("a card has its pilot's move", preview.antic != null)
	preview._time = 1.0
	preview._step_antic()
	_t.check("a card stays still in its first period", not preview.antic.out)
	var phase := float(hash(String(def.id)) % 1000) / 1000.0 * preview.ANTIC_PERIOD
	preview._time = 2.0 * preview.ANTIC_PERIOD - phase - PilotAntics.LENGTH * 0.5
	preview._step_antic()
	_t.check("a card's pilot climbs out at rest", preview.antic.out)
	HighdraftFx.preferred = true
	preview._step_antic()
	_t.check("reduced motion seats a card's pilot", not preview.antic.out)
	HighdraftFx.preferred = false
	preview._step_antic()
	preview.antic.calm = true
	preview.antic.apply(0.5)
	_t.check("calm keeps the ball still while the pilot is out", preview.antic.out
		and preview._core.transform.is_equal_approx(preview.antic._core_rest))
	preview.antic.calm = false
	preview.open = 1.0
	preview._step_antic()
	_t.check("and is back in when the card opens", not preview.antic.out)
	preview.open = 0.0
	preview.look_dragging = true
	preview.look_drag(Vector2(30.0, 0.0))
	for i in 20:
		preview._step_look(1.0 / 30.0)
	_t.check("dragging on a card looks closer", preview.look_weight > 0.9)
	preview.look_dragging = false
	for i in 120:
		preview._step_look(1.0 / 30.0)
	_t.check("and lets go", preview.look_weight < 0.01)
	preview.queue_free()
	await process_frame


func _shot(label: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_capture.path_join(label + ".png"))


func _bodies(node: Node) -> int:
	var count := 1 if node is PhysicsBody3D else 0
	for child in node.get_children():
		count += _bodies(child)
	return count
