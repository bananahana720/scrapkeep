extends SceneTree

# The Warden pulse's body wind-up must read by the tell floor. hero_assets.gd starts each
# kind's charge clip (WardenDress.BODY_CHARGE) with its WardenDress.BODY_BLENDS cross-fade from idle;
# a cross-fade as long as the whole tell holds the pose back, so the stacks or lens are
# still half way when the player must already be moving. At TELL_FLOOR seconds before the
# strike (PULSE_TELEGRAPH - TELL_FLOOR, DECISIONS section 5) the body's displacement from
# idle, blended as the game blends it, must reach READ_SHARE of the clip's own ramp played
# with no blend. Two positive controls must miss, so the checks are shown to fire: the
# reactor blended over the whole tell, and a hard cut from idle. Displacement is the sum
# over every Node3D and bone of position distance plus rotation angle from the idle pose at the same moment (an
# idle-only run), so the idle's own drift under the cross-fade is not counted as wind-up.
# It runs from several idle phases, since the charge can start anywhere in the idle loop.
# The cross-fade must not pop either: no step of the blended charge moves the body more than
# POP_SHARE times the largest step of the unblended clip or of the idle.

const WardenDress := preload("res://src/presentation/warden_dress.gd")
const Warden := preload("res://src/combat/warden.gd")
const ChallengeDials := preload("res://src/core/challenge_dials.gd")
# The Warden recipes key at 30 fps (tools/blender/warden_reactor.py FPS).
const STEP := 1.0 / 30.0
# Idle phases the charge starts from: quarters of the 4.0 s idle loop (reactor.md section 5).
const IDLE_PHASES := [0.0, 1.0, 2.0, 3.0]
# The gate: the game's blend keeps at least 90% of the unblended clip's read. Chosen, not
# measured; the old 2.0 s blends sat near 0.7 of it on stage 20da407b (reactor 0.69, mind
# 0.70 from idle phase 1.0).
const READ_SHARE := 0.9
# A step counts as a pop above this multiple of the largest step the authored clips make on
# their own. Chosen: on 20da407b the 0.5 s blends peak at 1.13 x (reactor) and 1.36 x (mind),
# while a hard cut from idle measures 1.9 x to 8 x.
const POP_SHARE := 1.5

var failures := 0
var checks := 0


func _initialize() -> void:
	var read_at: float = Warden.PULSE_TELEGRAPH - ChallengeDials.TELL_FLOOR
	_check(read_at > 0.0, "the read moment %.2f s lies inside the %.2f s tell" % [read_at, Warden.PULSE_TELEGRAPH])
	for kind in WardenDress.BODY_CHARGE:
		var clip: String = WardenDress.BODY_CHARGE[kind]
		var blend: float = WardenDress.BODY_BLENDS[kind].get(clip, -1.0)
		var path: String = WardenDress.BODIES[kind]["body"]
		for phase in IDLE_PHASES:
			var ref := _share(path, clip, 0.0, read_at, phase)
			var got := _share(path, clip, blend, read_at, phase)
			_check(ref > 0.05, "%s %s from idle %.1f s moves the body by the read moment (unblended %.2f)" % [kind, clip, phase, ref])
			_check(got >= READ_SHARE * ref,
				"%s %s from idle %.1f s with blend %.2f reads %.2f at %.2f s, at least %.2f x the unblended %.2f" % [kind, clip, phase, blend, got, read_at, READ_SHARE, ref])
			var steps := _max_step(path, clip, blend, phase)
			var limit := maxf(_max_step(path, clip, 0.0, phase, true), _max_step(path, "idle", 0.0, phase))
			_check(steps <= POP_SHARE * limit,
				"%s %s from idle %.1f s: the blend's largest step %.4f is within %.1f x the clip's or idle's %.4f" % [kind, clip, phase, steps, POP_SHARE, limit])
	var control_path: String = WardenDress.BODIES["reactor"]["body"]
	var ref_c := _share(control_path, "pulse_warn", 0.0, read_at, IDLE_PHASES[1])
	var slow := _share(control_path, "pulse_warn", Warden.PULSE_TELEGRAPH, read_at, IDLE_PHASES[1])
	_check(slow < READ_SHARE * ref_c,
		"control: a %.1f s blend over the whole tell misses (%.2f against %.2f)" % [Warden.PULSE_TELEGRAPH, slow, READ_SHARE * ref_c])
	var cut := _run_cut(control_path, "pulse_warn", IDLE_PHASES[1])
	var cut_limit := maxf(_max_step(control_path, "pulse_warn", 0.0, IDLE_PHASES[1], true), _max_step(control_path, "idle", 0.0, IDLE_PHASES[1]))
	_check(cut > POP_SHARE * cut_limit,
		"control: a hard cut from idle %.1f s pops (%.4f against %.4f)" % [IDLE_PHASES[1], cut, POP_SHARE * cut_limit])
	print("warden_tell_read_test: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(1 if failures > 0 else 0)


# Displacement from idle at `read_at`, as a share of the unblended clip's displacement at the strike.
func _share(path: String, clip: String, blend: float, read_at: float, phase: float) -> float:
	var at_read := _dist(_run(path, clip, blend, phase, read_at).back(), _run(path, "idle", 0.0, phase, read_at).back())
	var peak := _dist(_run(path, clip, 0.0, phase, Warden.PULSE_TELEGRAPH).back(), _run(path, "idle", 0.0, phase, Warden.PULSE_TELEGRAPH).back())
	return at_read / peak if peak > 1e-6 else 0.0


# The largest pose change in one step over the tell. `skip_first` drops the unblended clip's
# own cut from idle on its first frame, which the game never shows (it always blends).
func _max_step(path: String, clip: String, blend: float, phase: float, skip_first := false) -> float:
	var poses := _run(path, clip, blend, phase, Warden.PULSE_TELEGRAPH)
	var most := 0.0
	for i in range(2 if skip_first else 1, poses.size()):
		most = maxf(most, _dist(poses[i - 1], poses[i]))
	return most


# Poses from the charge start (index 0, idle at `phase`) to `until` seconds, one per STEP.
func _run(path: String, clip: String, blend: float, phase: float, until: float) -> Array:
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("idle")
	player.advance(phase)
	var poses := [_pose(scene)]
	if clip != "idle":
		player.play(clip, blend)
	player.advance(0.0)
	var t := 0.0
	while t + STEP <= until + 1e-6:
		player.advance(STEP)
		t += STEP
		poses.append(_pose(scene))
	scene.free()
	return poses


func _run_cut(path: String, clip: String, phase: float) -> float:
	var poses := _run(path, clip, 0.0, phase, STEP)
	return _dist(poses[0], poses[1])


func _dist(a: Array, b: Array) -> float:
	var sum := 0.0
	for i in a.size():
		sum += (a[i][0] - b[i][0]).length() + (a[i][1] as Quaternion).angle_to(b[i][1])
	return sum


func _pose(scene: Node) -> Array:
	var out := []
	for n in scene.find_children("*", "Node3D", true, false):
		out.append([(n as Node3D).position, (n as Node3D).quaternion])
		if n is Skeleton3D:
			var sk := n as Skeleton3D
			for b in sk.get_bone_count():
				out.append([sk.get_bone_pose_position(b), sk.get_bone_pose_rotation(b)])
	return out


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])
