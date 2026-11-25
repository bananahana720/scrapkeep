extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EnemyClips := preload("res://src/presentation/enemy_clips.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const T := preload("res://tests/support/t.gd")

# The field crew's baked clips (field_motion.py, enemy_clips.gd): every world 1 kind has its six
# clips, its wind-up is its attack's lead within one 30 fps frame and is sampled by the attack's
# own progress, the joints leave the parts and their code poses where they were, a death plays
# its clip and then breaks up, and a headless run seats nothing.

const KINDS := ["chaser", "lobber", "mag_trapper", "plated_brute", "winch_drone", "jolt_layer", "hooker", "ramp_flipper",
	"boom_tender", "netcaster", "bola_thrower", "swatter", "catch_trap", "deflector", "gyro_jammer"]
const FRAME := 1.0 / 30.0
var _game
var _t := T.new("enemy_clips_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _spawn(kind: String, x := -100.0):
	var enemy = _game.combat.spawn_enemy(kind, _game.ctx.terrain.drop_point(x, -90.0, 1.6))
	enemy.hp = 100000.0
	return enemy


func _headless_default() -> void:
	var enemy = _spawn("chaser")
	await _frames(2)
	_t.check("headless seats nothing", enemy._clips == null and enemy.find_child("EnemyClips", true, false) == null,
		"EnemyClips.headless false: no driver, no joints")
	enemy.free()


func _library() -> void:
	for kind in KINDS:
		var lib := EnemyClips.library(kind)
		var names: Array = lib.get("anims", {}).keys()
		names.sort()
		var want: Array = EnemyClips.CLIPS.duplicate()
		want.sort()
		_t.check("%s six clips" % kind, names == want, "%s" % [names])
		var seamless := true
		for loop in ["idle", "move"]:
			var entry: Dictionary = lib.anims.get(loop, {})
			if entry.is_empty():
				seamless = false
				continue
			var anim: Animation = entry.anim
			for track in entry.tracks:
				var i: int = track[2]
				match int(track[1]):
					Animation.TYPE_POSITION_3D:
						seamless = seamless and anim.position_track_interpolate(i, 0.0).is_equal_approx(anim.position_track_interpolate(i, anim.length))
					Animation.TYPE_ROTATION_3D:
						seamless = seamless and anim.rotation_track_interpolate(i, 0.0).is_equal_approx(anim.rotation_track_interpolate(i, anim.length))
					Animation.TYPE_SCALE_3D:
						seamless = seamless and anim.scale_track_interpolate(i, 0.0).is_equal_approx(anim.scale_track_interpolate(i, anim.length))
		_t.check("%s idle and move loop without a seam" % kind, seamless)


func _lead(kind: String, enemy) -> float:
	var spec: Dictionary = WindupRows.ROWS[kind]
	return float(WindupRows.row(kind, enemy, String(spec.attacks.keys()[0])).get("lead_seconds", 0.0))


# Seat, part names, windup length and progress sampling, per kind.
func _per_kind() -> void:
	for kind in KINDS:
		var enemy = _spawn(kind)
		var parts := []
		for bone in EnemyClips.ROWS[kind].parts:
			for part_path in EnemyClips.ROWS[kind].parts[bone]:
				parts.append(enemy.reaction_pivot.get_node_or_null(NodePath(part_path)))
		await _frames(2)
		var driver = enemy._clips
		_t.check("%s seated" % kind, driver != null, "driver under the pivot")
		if driver == null:
			enemy.free()
			continue
		var reachable := true
		for node in parts:
			reachable = reachable and node != null and is_instance_valid(node) and node.is_inside_tree() \
				and String(node.get_parent().name) == EnemyClips.JOINT_PREFIX + String(node.name)
		_t.check("%s parts keep their names under joints" % kind, reachable)
		var lead := _lead(kind, enemy)
		var length := float(driver.lib.anims.windup.length)
		_t.check("%s windup is its lead" % kind, absf(length - lead) <= FRAME + 0.0001, "clip %.4f s, lead %.4f s" % [length, lead])
		enemy.set_physics_process(false)
		var exact := true
		for progress in [0.0, 0.25, 0.5, 1.0]:
			enemy._atk = {"phase": "windup", "progress": progress, "tele": null}
			driver._physics_process(1.0 / 60.0)
			exact = exact and driver.clip == "windup" and absf(driver.clip_time - progress * length) < 0.0001
		_t.check("%s windup follows progress" % kind, exact, "clip time = progress x length at 0, 0.25, 0.5, 1")
		enemy._atk = {"phase": "strike", "progress": 1.0, "tele": null}
		driver._on_attack_phase({"phase": "strike"})
		for i in 90:
			driver._physics_process(1.0 / 60.0)
		var held: bool = driver.clip == "attack" and is_equal_approx(driver.clip_time, float(driver.lib.anims.attack.length))
		_t.check("%s long live phase holds the attack's last pose" % kind, held, "1.5 s into an open strike: %s at %.3f s" % [driver.clip, driver.clip_time])
		enemy._atk = {}
		driver._on_attack_phase({"phase": "strike"})
		driver._physics_process(1.0 / 60.0)
		var struck: bool = driver.clip == "attack" and is_zero_approx(driver.clip_time)
		for i in 60:
			driver._physics_process(1.0 / 60.0)
		_t.check("%s strike plays attack from frame 0, then idles" % kind, struck and driver.clip in ["idle", "move"], "now %s" % driver.clip)
		enemy.free()


# A real chaser lunge: every wind-up tick samples the lane's own progress and the strike tick
# shows attack frame 0; the code pose (the 42 degree rear-up) is untouched under the joint.
func _chaser_cycle() -> void:
	var enemy = _spawn("chaser")
	await _frames(2)
	var driver = enemy._clips
	var length := float(driver.lib.anims.windup.length)
	var matched := true
	var windup_ticks := 0
	var struck_at := -1
	var lunge_at := -1
	var braced := false
	enemy._begin_windup(Vector3.FORWARD)
	for i in 90:
		await physics_frame
		if enemy.state == enemy.State.WINDUP:
			var lane = enemy.telegraph()
			windup_ticks += 1
			matched = matched and driver.clip == "windup" and lane != null and absf(driver.clip_time - lane.progress * length) < 0.0001
		if enemy.state == enemy.State.LUNGE and lunge_at < 0:
			lunge_at = i
			struck_at = i if driver.clip == "attack" and driver.clip_time <= 1.0 / 60.0 + 0.0001 else -1
			var part: Dictionary = enemy._pose_parts["ChaserBody"]
			var relative: Transform3D = part.node.transform * (part.rest as Transform3D).affine_inverse()
			braced = absf(rad_to_deg(relative.basis.get_euler().x) - 42.0) < 0.01
	_t.check("chaser windup tracks the lane", matched and windup_ticks >= 30, "%d wind-up ticks, clip time = lane progress x %.3f s" % [windup_ticks, length])
	_t.check("chaser release frame", lunge_at >= 0 and struck_at == lunge_at and braced, "lunge tick %d, attack frame 0 on it %s, code rear-up kept %s" % [lunge_at, struck_at == lunge_at, braced])
	enemy.free()


# The bola thrower's reticle is held open all wind-up (its telegraph progress stays 0); its body's
# wind-up clip still runs on the wind-up's own clock (W1-87 review).
func _bola_cycle() -> void:
	var enemy = _spawn("bola_thrower")
	enemy.global_position = _game.player.ball_position() + Vector3(10.0, 1.6, 0.0)
	enemy._rest = 0.0
	await _frames(2)
	var driver = enemy._clips
	var length := float(driver.lib.anims.windup.length)
	var matched := true
	var ticks := 0
	var furthest := 0.0
	for i in 900:
		await physics_frame
		if enemy.phase == enemy.Phase.WARN:
			ticks += 1
			matched = matched and driver.clip == "windup" and absf(driver.clip_time - enemy.windup_run() * length) < 0.0001
			furthest = maxf(furthest, driver.clip_time)
		elif ticks > 0:
			break
	_t.check("bola windup runs on its own clock under a held-open reticle", matched and ticks >= 20 and furthest > length * 0.8,
		"%d wind-up ticks, furthest %.2f of %.2f s" % [ticks, furthest, length])
	enemy.free()
	await _frames(2)


# The netcaster's net rides its body's joint; a crew killed while its tool is away (a thrown cup)
# hides the away tool and still plays its baked death clip on the hull before scattering.
func _carried_parts() -> void:
	var net = _spawn("netcaster")
	await _frames(2)
	var hung: Node = net.reaction_pivot.find_child("NetcasterNet", true, false)
	_t.check("the netcaster's net rides its body joint", hung != null and String(hung.get_parent().name).begins_with(EnemyClips.JOINT_PREFIX), str(hung.get_parent().name if hung != null else null))
	net.free()
	var trap = _spawn("catch_trap")
	await _frames(2)
	var parent: Node = trap.get_parent()
	trap._cup.top_level = true
	trap.take_damage(trap.hp + 1.0)
	var holder: Node = parent.get_node_or_null("DeathClip")
	_t.check("a catch trap killed with its cup out hides the away cup and plays its death clip",
		holder != null and not trap._cup.visible and parent.get_node_or_null("DeathScatter") == null)
	await _frames(int(ceil(0.5 * Engine.physics_ticks_per_second)) + 4)
	_t.check("the away-tool death clip scatters and frees its holder",
		parent.get_node_or_null("DeathScatter") != null and not is_instance_valid(holder))
	await _frames(Engine.physics_ticks_per_second)
	var ramp = _spawn("ramp_flipper")
	await _frames(2)
	var ramp_parent: Node = ramp.get_parent()
	ramp._plate.top_level = true
	ramp.take_damage(ramp.hp + 1.0)
	var ramp_holder: Node = ramp_parent.get_node_or_null("DeathClip")
	_t.check("a ramp flipper killed with its plate deployed hides the away plate and plays its death clip",
		ramp_holder != null and not ramp._plate.visible and ramp_parent.get_node_or_null("DeathScatter") == null)
	await _frames(int(ceil(0.5 * Engine.physics_ticks_per_second)) + 4)
	await _frames(Engine.physics_ticks_per_second)


# Death plays its clip on the look, then the usual break-up scatters it and frees the holder.
func _death() -> void:
	for kind in ["chaser", "winch_drone"]:
		var enemy = _spawn(kind)
		await _frames(2)
		var settle := 0
		while kind == "chaser" and not enemy.is_on_floor() and settle < 180:
			await physics_frame
			settle += 1
		var parent: Node = enemy.get_parent()
		var standing: bool = enemy.is_on_floor() and kind != "winch_drone"
		enemy.take_damage(enemy.hp + 1.0)
		var holder: Node = parent.get_node_or_null("DeathClip")
		var pivot: Node3D = enemy.reaction_pivot
		var pose: Transform3D = pivot.global_transform if pivot != null else Transform3D()
		await _frames(1)
		# The dead body's last tick leaves the clip's pivot in the pose it died in (W1-86 review).
		_t.check("%s death clip keeps the pose it died in" % kind, pivot != null and pivot.global_transform.is_equal_approx(pose), str(pivot.global_transform if pivot != null else null))
		var driver = holder.find_child("EnemyClips", true, false) if holder != null else null
		_t.check("%s death clip lands only a standing body" % kind, driver != null and driver._land.is_valid() == standing,
			"standing %s, lands %s" % [standing, driver != null and driver._land.is_valid()])
		await _frames(1)
		var playing: bool = holder != null and holder.find_child("EnemyClips", true, false) != null \
			and holder.find_child("EnemyClips", true, false).clip == "death"
		await _frames(int(ceil(0.5 * Engine.physics_ticks_per_second)) + 2)
		var scattered: bool = parent.get_node_or_null("DeathScatter") != null
		await _frames(2)
		_t.check("%s death clip then scatter" % kind, playing and scattered and not is_instance_valid(holder),
			"holder playing death %s; scatter after the clip %s; holder freed %s" % [playing, scattered, not is_instance_valid(holder)])
		await _frames(Engine.physics_ticks_per_second)


# A hit flinches a body at rest but never a committed wind-up.
func _hits() -> void:
	var enemy = _spawn("plated_brute")
	await _frames(2)
	var driver = enemy._clips
	enemy.react("flinch", Vector3.RIGHT)
	await _frames(1)
	var flinched: bool = driver.clip == "hit"
	enemy.set_physics_process(false)
	enemy._atk = {"phase": "windup", "progress": 0.5, "tele": null}
	driver._physics_process(1.0 / 60.0)
	enemy.react("flinch", Vector3.RIGHT)
	driver._physics_process(1.0 / 60.0)
	enemy._atk = {}
	_t.check("hit flinches a resting body, not a wind-up", flinched and driver.clip == "windup", "after the hit in wind-up: %s" % driver.clip)
	enemy.free()


# Reduced motion drops idle and move: every joint holds identity while idle.
func _reduced_motion() -> void:
	EnemyMotion.motion_scale = 0.0
	var enemy = _spawn("lobber")
	await _frames(20)
	var still := true
	for joint in enemy.reaction_pivot.find_children(EnemyClips.JOINT_PREFIX + "*", "Node3D", true, false):
		still = still and (joint as Node3D).transform.is_equal_approx(Transform3D.IDENTITY)
	_t.check("reduced motion idles still", enemy._clips.clip == "idle" and still)
	EnemyMotion.motion_scale = 1.0
	enemy.free()


func _run() -> void:
	await _boot()
	await _headless_default()
	EnemyClips.headless = true
	_library()
	await _per_kind()
	await _chaser_cycle()
	await _bola_cycle()
	await _carried_parts()
	await _death()
	await _hits()
	await _reduced_motion()
	EnemyClips.headless = false
	quit(_t.verdict())
