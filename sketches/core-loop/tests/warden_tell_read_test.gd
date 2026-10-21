extends SceneTree

# The Warden pulse's body wind-up must read by the tell floor. hero_assets.gd starts each
# kind's charge clip (WARDEN_BODY_CHARGE) with its WARDEN_BODY_BLENDS cross-fade from idle;
# a cross-fade as long as the whole tell holds the pose back, so the stacks or lens are
# still half way when the player must already be moving. At TELL_FLOOR seconds before the
# strike (PULSE_TELEGRAPH - TELL_FLOOR, DECISIONS section 5) the body's displacement from
# idle, blended as the game blends it, must reach READ_SHARE of the clip's own ramp played
# with no blend. A positive control plays the reactor with a blend as long as the tell and
# must miss, so the check is shown to fire. Displacement is the sum over every Node3D and
# bone of position distance plus rotation angle from the idle pose.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Warden := preload("res://src/combat/warden.gd")
const ChallengeDials := preload("res://src/core/challenge_dials.gd")
const STEP := 0.05
const IDLE_SETTLE := 1.3
# Measured 21 Oct on stage 20da407b: with the old 2.0 s blend the reactor read 54% of its
# unblended 78% at 1.4 s (a share of 0.69); the mind read 91% against 82% (1.11).
const READ_SHARE := 0.9

var failures := 0
var checks := 0


func _initialize() -> void:
	var read_at: float = Warden.PULSE_TELEGRAPH - ChallengeDials.TELL_FLOOR
	_check(read_at > 0.0, "the read moment %.2f s lies inside the %.2f s tell" % [read_at, Warden.PULSE_TELEGRAPH])
	for kind in HeroAssets.WARDEN_BODY_CHARGE:
		var clip: String = HeroAssets.WARDEN_BODY_CHARGE[kind]
		var blend: float = HeroAssets.WARDEN_BODY_BLENDS[kind].get(clip, -1.0)
		var path: String = HeroAssets.WARDEN_BODIES[kind]["body"]
		var ref := _share(path, clip, 0.0, read_at)
		var got := _share(path, clip, blend, read_at)
		_check(ref > 0.05, "%s %s moves the body by the read moment (unblended %.2f)" % [kind, clip, ref])
		_check(got >= READ_SHARE * ref,
			"%s %s with blend %.2f reads %.2f at %.2f s, at least %.2f x the unblended %.2f" % [kind, clip, blend, got, read_at, READ_SHARE, ref])
	var control_path: String = HeroAssets.WARDEN_BODIES["reactor"]["body"]
	var ref_c := _share(control_path, "pulse_warn", 0.0, read_at)
	var slow := _share(control_path, "pulse_warn", Warden.PULSE_TELEGRAPH, read_at)
	_check(slow < READ_SHARE * ref_c,
		"control: a %.1f s blend over the whole tell misses (%.2f against %.2f)" % [Warden.PULSE_TELEGRAPH, slow, READ_SHARE * ref_c])
	print("warden_tell_read_test: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(1 if failures > 0 else 0)


# Displacement from idle at `read_at`, as a share of the unblended clip's displacement at the strike.
func _share(path: String, clip: String, blend: float, read_at: float) -> float:
	var at_read := _displacement(path, clip, blend, read_at)
	var peak := _displacement(path, clip, 0.0, Warden.PULSE_TELEGRAPH)
	return at_read / peak if peak > 1e-6 else 0.0


func _displacement(path: String, clip: String, blend: float, at: float) -> float:
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("idle")
	player.advance(IDLE_SETTLE)
	var idle := _pose(scene)
	player.play(clip, blend)
	player.advance(0.0)
	var t := 0.0
	while t + STEP <= at + 1e-6:
		player.advance(STEP)
		t += STEP
	var pose := _pose(scene)
	scene.free()
	var sum := 0.0
	for i in idle.size():
		sum += (idle[i][0] - pose[i][0]).length() + (idle[i][1] as Quaternion).angle_to(pose[i][1])
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
