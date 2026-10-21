extends SceneTree
# Loop seam check for every looped enemy, Warden and boss clip (AMBITION-BRIEF "keep loops
# seamless"; coordinator ruling on GitHub #149). For each looped clip and each position,
# rotation and scale track, the value at time 0 must meet the value at `length`
# (location 1 mm, rotation 0.5 degrees, scale 0.001), and the wrap from the last step
# (length - dt -> length) to the first (0 -> dt) must be no harsher than the clip already is:
# the seam's velocity change may not exceed SEAM_HARSHER times the largest frame-to-frame
# velocity change inside the clip, unless it stays under a floor nobody sees at 30 fps
# (5 mm, 0.5 degrees or 0.01 scale per frame). So a stepped track (a clock hand that ticks on
# the beat grid, kill_first_rig.py) or a footfall that reverses mid-clip may reverse at the
# seam too, while a smooth clip that arrives moving and leaves reversed fails.
# Looped clips come from special_rig.gd CLIPS, linker.gd:48, mind_hand.gd:263, the
# hero_assets.gd idle replay and BossModel.loop_clip (boss_model.gd:72, LOOP_LINEAR): Brindle's
# idle_roll (requisition.gd:253) and the scooter's chase (requisition.gd:321), and the Mind
# kit's attention (mind_dress.gd:93). The Waking's `sleeping` is not here: waking_dress.gd
# never plays it (it opens on `wake`, :97) and never sets a loop mode on it, so it is a
# held 3 s base pose, not a loop (waking.py:56 gives it zero key-pose seconds). Mirrors tools/blender/rig_pose_audit.py section 5.
# Real seam failures are findings. A failure that exists on the shipped clips today is listed in
# KNOWN below with its cause; the test then requires it to still fail, so fixing the clip while
# leaving its row fails the test as stale (the table ratchets down). Anything else that fails
# is red.

const T := preload("res://tests/support/t.gd")
const M := "res://assets/models/"
const DT := 1.0 / 30.0
const LOC_M := 0.001
const ROT_DEG := 0.5
const SCALE_TOL := 0.001
const SEAM_HARSHER := 1.5
const VEL_FLOOR := {Animation.TYPE_POSITION_3D: 0.005, Animation.TYPE_ROTATION_3D: 0.5, Animation.TYPE_SCALE_3D: 0.01}

const LOOPS := [
	[M + "world_one/enemy_foreman.glb", "idle"],
	[M + "world_one/enemy_dispatcher.glb", "idle"],
	[M + "world_one/enemy_splitter.glb", "crawl"],
	[M + "world_one/enemy_splitter_piece.glb", "scurry"],
	[M + "world_one/enemy_linker.glb", "idle"],
	[M + "world_one/enemy_linker.glb", "braced"],
	[M + "warden_reactor.glb", "idle"],
	[M + "warden_swarm.glb", "idle"],
	[M + "warden_swarm_kit_drones.glb", "idle"],
	[M + "warden_mind.glb", "idle"],
	[M + "bosses/mind_hand.glb", "still_track"],
	[M + "bosses/boss_brindle.glb", "idle_roll"],
	[M + "bosses/boss_brindle_scooter.glb", "chase"],
	[M + "bosses/boss_mind_kit.glb", "attention"],
]

# label -> measured cause (2026-10-21, base 20da407). Owner of both rows: A5 Brindle drum loops,
# which deletes them. Both are a rolling drum keyed as one straight spin that is not a whole
# number of turns.
const KNOWN := {
	"boss_brindle idle_roll": "A5 Brindle drum loops: Drum{L,R}{0..3} pitch -4/.75*1.2 = -6.4 rad = 366.69 deg, 6.69 deg past a full turn (brindle_animation.py:113-114)",
	"boss_brindle_scooter chase": "A5 Brindle drum loops: Drums pitch -11/.22 = -50 rad = 7.96 turns, 15.21 deg short of 8 (brindle_animation.py:211-213)",
}

var t := T.new("rig_loop_seam_test")
var _known_seen := {}


func _initialize() -> void:
	_run.call_deferred()


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


# Step of one track between two times as a vector: metres, local rotation vector in
# degrees, or scale delta.
func _value(anim: Animation, i: int, time: float):
	match anim.track_get_type(i):
		Animation.TYPE_POSITION_3D:
			return anim.position_track_interpolate(i, time)
		Animation.TYPE_ROTATION_3D:
			return anim.rotation_track_interpolate(i, time)
		_:
			return anim.scale_track_interpolate(i, time)


func _step(kind: int, a, b) -> Vector3:
	if kind == Animation.TYPE_ROTATION_3D:
		var d: Quaternion = (a as Quaternion).inverse() * (b as Quaternion)
		if d.w < 0.0:
			d = Quaternion(-d.x, -d.y, -d.z, -d.w)
		var ang := 2.0 * acos(clampf(d.w, -1.0, 1.0))
		var s := sqrt(maxf(1.0 - d.w * d.w, 0.0))
		if s < 1e-9:
			return Vector3.ZERO
		return Vector3(d.x, d.y, d.z) / s * rad_to_deg(ang)
	return (b as Vector3) - (a as Vector3)


func _is_transform(anim: Animation, i: int) -> bool:
	var ty := anim.track_get_type(i)
	return ty == Animation.TYPE_POSITION_3D or ty == Animation.TYPE_ROTATION_3D or ty == Animation.TYPE_SCALE_3D


# Returns {"tracks": n, "failures": [strings]}.
func compare(anim: Animation) -> Dictionary:
	var failures: Array = []
	var tracks := 0
	var length := anim.length
	var frames := int(round(length / DT))
	for i in anim.get_track_count():
		if not _is_transform(anim, i):
			continue
		tracks += 1
		var kind := anim.track_get_type(i)
		var path := String(anim.track_get_path(i))
		var first = _value(anim, i, 0.0)
		var last = _value(anim, i, length)
		var gap := _step(kind, first, last).length()
		var limit := LOC_M
		var unit := "m"
		if kind == Animation.TYPE_ROTATION_3D:
			limit = ROT_DEG
			unit = "deg"
		elif kind == Animation.TYPE_SCALE_3D:
			limit = SCALE_TOL
			unit = "scale"
		if gap > limit:
			failures.append("%s seam %.5f %s > %s" % [path, gap, unit, limit])
		# The largest frame-to-frame velocity change inside the clip (no wrap).
		var steps: Array[Vector3] = []
		var prev = first
		for f in range(1, frames + 1):
			var cur = _value(anim, i, minf(f * DT, length))
			steps.append(_step(kind, prev, cur))
			prev = cur
		var inside := 0.0
		for f in range(1, steps.size()):
			inside = maxf(inside, (steps[f] - steps[f - 1]).length())
		var jump := (steps[0] - steps[steps.size() - 1]).length() if not steps.is_empty() else 0.0
		if jump > maxf(SEAM_HARSHER * inside, VEL_FLOOR[kind]):
			failures.append("%s velocity jump %.5f %s/frame > %.1f x the clip's own %.5f (floor %s)" % [path, jump, unit,
				SEAM_HARSHER, inside, VEL_FLOOR[kind]])
	return {"tracks": tracks, "failures": failures}


func _planted() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	# Clean: a full sine cycle on position, rotation and scale.
	var p := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(p, NodePath("Skel:clean_pos"))
	var r := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(r, NodePath("Skel:clean_rot"))
	var s := a.add_track(Animation.TYPE_SCALE_3D)
	a.track_set_path(s, NodePath("Skel:clean_scale"))
	for f in 31:
		var u := float(f) / 30.0
		a.position_track_insert_key(p, u, Vector3(0.1 * sin(TAU * u), 0, 0))
		a.rotation_track_insert_key(r, u, Quaternion(Vector3.UP, 0.3 * sin(TAU * u)))
		a.scale_track_insert_key(s, u, Vector3.ONE * (1.0 + 0.1 * sin(TAU * u)))
	# Planted position seam: ends 5 mm off.
	var q := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(q, NodePath("Skel:seam_pos"))
	a.position_track_insert_key(q, 0.0, Vector3.ZERO)
	a.position_track_insert_key(q, 0.5, Vector3(0.1, 0, 0))
	a.position_track_insert_key(q, 1.0, Vector3(0.005, 0, 0))
	# Planted rotation seam: ends 2 degrees off.
	var w := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(w, NodePath("Skel:seam_rot"))
	a.rotation_track_insert_key(w, 0.0, Quaternion.IDENTITY)
	a.rotation_track_insert_key(w, 0.5, Quaternion(Vector3.UP, 0.5))
	a.rotation_track_insert_key(w, 1.0, Quaternion(Vector3.UP, deg_to_rad(2.0)))
	# Planted velocity jump: a smooth arch whose ends meet, so the clip arrives moving down and
	# leaves moving up (about 2 cm per frame), harsher than anything inside it.
	var v := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(v, NodePath("Skel:kink_pos"))
	for f in 31:
		var u := float(f) / 30.0
		a.position_track_insert_key(v, u, Vector3(0, 0.2 * sin(PI * u), 0))
	# Clean stepped track: a clock hand that holds, then snaps 72 degrees in one frame, five times,
	# and comes round to where it started. The clip's last frame is a snap and its first a hold, so
	# the seam jumps the full 72 degrees per frame, exactly as every tick inside the clip does.
	var k := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(k, NodePath("Skel:clean_tick"))
	a.rotation_track_insert_key(k, 0.0, Quaternion.IDENTITY)
	for f in range(1, 6):
		a.rotation_track_insert_key(k, f * 0.2 - DT, Quaternion(Vector3.FORWARD, deg_to_rad(72.0 * (f - 1))))
		a.rotation_track_insert_key(k, f * 0.2, Quaternion(Vector3.FORWARD, deg_to_rad(72.0 * f)))
	return a


func _run() -> void:
	# Positive control: the comparison must flag the planted seams and pass the clean tracks.
	var control := compare(_planted())
	var text := "\n".join(PackedStringArray(control["failures"]))
	t.check("control sees 7 transform tracks", control["tracks"] == 7, str(control["tracks"]))
	t.check("control flags the planted position seam", text.contains("seam_pos seam"), text)
	t.check("control flags the planted rotation seam", text.contains("seam_rot seam"), text)
	t.check("control flags the planted velocity jump", text.contains("kink_pos velocity"), text)
	t.check("control passes the clean tracks, the stepped one included", not text.contains("clean_"), text)

	for row in LOOPS:
		var path: String = row[0]
		var clip: String = row[1]
		var label := path.get_file().get_basename() + " " + clip
		var res := load(path)
		if not t.check(label + " loads", res is PackedScene, path):
			continue
		var inst: Node = (res as PackedScene).instantiate()
		root.add_child(inst)
		var player := _find_player(inst)
		if not t.check(label + " has an AnimationPlayer", player != null):
			inst.queue_free()
			continue
		if not t.check(label + " has the clip", player.has_animation(clip), str(player.get_animation_list())):
			inst.queue_free()
			continue
		var anim := player.get_animation(clip)
		t.check(label + " length > 0", anim.length > 0.0, str(anim.length))
		var out := compare(anim)
		t.check(label + " has transform tracks", out["tracks"] > 0, str(out["tracks"]))
		var fails: Array = out["failures"]
		var detail := "%d tracks, %.3f s" % [out["tracks"], anim.length]
		if not fails.is_empty():
			detail += "; %d failing: %s" % [fails.size(), " | ".join(PackedStringArray(fails.slice(0, 12)))]
		if KNOWN.has(label):
			_known_seen[label] = true
			t.check(label + " still has its KNOWN seam failure (remove the KNOWN row once fixed)", not fails.is_empty(),
				"known cause: " + String(KNOWN[label]))
		else:
			t.check(label + " loops seamlessly", fails.is_empty(), detail)
		inst.queue_free()
	for label in KNOWN:
		t.check("KNOWN row was visited: " + label, _known_seen.has(label), "a KNOWN label no LOOPS entry produced is stale")
	quit(t.verdict())
