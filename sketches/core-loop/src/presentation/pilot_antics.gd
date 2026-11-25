extends RefCounted

const LENGTH := 2.0 * 240.0 / 129.0
const TOP := 0.98
const GROUND := -0.98
const FEET := 0.54
const SEAT := Vector3.ZERO
const FALLBACK := "big_cheer"
const BLEND := 0.25
const OUT_BLEND := 0.25
const FRAME_RATE := 60.0

const MOVES := {
	"pylon_engineer": {"word": "TA-DA!", "line": "Balances on it. Mostly.",
		"clips": [[0.0, "drop_land", 1.0], [0.3, "big_cheer", 0.8], [0.86, "drop_land", 1.0]]},
	"runner_gunner": {"word": "...HUH?", "line": "Leans on the ball. Faces the wrong way.",
		"clips": [[0.0, "drop_land", 1.0], [0.22, "brace", 0.0, 0.5], [0.6, "wince", 0.0], [0.86, "drop_land", 1.0]]},
	"demolitions_caster": {"word": "BOOM!", "line": "Hovers. Hovers. Commits.",
		"clips": [[0.0, "heave", 1.0], [0.16, "phew", 0.35], [0.74, "smash", 0.0], [0.9, "drop_land", 1.0]]},
	"tarn": {"word": "grrr", "line": "Sits on top. The machine growls for both of them.",
		"clips": [[0.0, "drop_land", 1.0], [0.2, "slump", 0.6], [0.58, "big_cheer", 0.5, 0.5], [0.86, "drop_land", 1.0, 0.52]]},
	"tally": {"word": "ZAP!", "line": "Taps the ball. Rewires the relay.",
		"clips": [[0.0, "drop_land", 1.0], [0.2, "cast_line", 0.0], [0.42, "cast_line", 0.0, 0.0], [0.64, "cast_line", 0.0, 0.0], [0.88, "drop_land", 1.0]]},
	"remembered_cannon": {"word": "...hello.", "line": "Rises out very slowly. Waves once.",
		"out": 0.5, "clips": [[0.0, "heave", 0.0], [0.78, "big_cheer", 0.6, 0.0]]},
}

static var reduced_motion := false

var holder: Node3D
var core: Node3D
var pod: Node3D
var pilot: Node3D
var animator: AnimationPlayer
var class_id := ""
var out := false
var calm := false

var _seat := Transform3D.IDENTITY
var _scale := Vector3.ONE
var _core_rest := Transform3D.IDENTITY
var _clip := ""
var _rows: Array = []
var _skeleton_list: Array = []
var _memo := {}
var _composed := {}


func _init(rec: Dictionary, id: String) -> void:
	holder = rec.get("holder")
	core = rec.get("core")
	pod = rec.get("pod")
	pilot = rec.get("pilot")
	animator = rec.get("animator")
	class_id = id


static func has_move(id: String) -> bool:
	return MOVES.has(id)


static func word(id: String) -> String:
	return String(MOVES.get(id, {}).get("word", ""))


static func line(id: String) -> String:
	return String(MOVES.get(id, {}).get("line", ""))


func ready() -> bool:
	return holder != null and pod != null and pilot != null and is_instance_valid(pilot) and MOVES.has(class_id)


func apply(t: float) -> void:
	if not ready():
		return
	if t < 0.0 or t >= 1.0:
		seat()
		return
	if not out:
		_climb_out()
	var pose := pose_at(class_id, t)
	if calm:
		pose.spin = 0.0
		pose.squash = 1.0
		pose.shake = Vector3.ZERO
	var basis := Basis.from_euler(Vector3(pose.pitch, pose.yaw, pose.roll)).scaled(_scale)
	pilot.transform = Transform3D(basis, pose.at)
	if core != null:
		var squash: float = pose.squash
		var spun := Basis(Vector3.RIGHT, pose.spin) * _core_rest.basis
		core.transform = Transform3D(spun.scaled(Vector3(1.0 + (1.0 - squash) * 0.5, squash, 1.0 + (1.0 - squash) * 0.5)),
			_core_rest.origin + pose.shake)
	_play(t)


func seat() -> void:
	if not out:
		return
	out = false
	if is_instance_valid(pilot) and is_instance_valid(pod):
		pilot.get_parent().remove_child(pilot)
		pod.add_child(pilot)
		pilot.transform = _seat
	if is_instance_valid(core):
		core.transform = _core_rest
	if animator != null and is_instance_valid(animator):
		animator.stop()
		for skeleton in pilot.find_children("*", "Skeleton3D", true, false):
			skeleton.reset_bone_poses()
	_clip = ""
	_rows = []
	_skeleton_list = []
	_memo = {}
	_composed = {}


func _climb_out() -> void:
	out = true
	_rows = []
	_skeleton_list = []
	_memo = {}
	_composed = {}
	_seat = pilot.transform
	_core_rest = core.transform if core != null else Transform3D.IDENTITY
	var relative := holder.global_transform.affine_inverse() * pilot.global_transform if holder.is_inside_tree() \
		else _path_to(holder, pilot)
	_scale = relative.basis.get_scale()
	pilot.get_parent().remove_child(pilot)
	holder.add_child(pilot)


func _path_to(root: Node, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != root:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


func _play(t: float) -> void:
	if animator == null or not is_instance_valid(animator):
		return
	if animator.is_playing():
		animator.pause()
	if _rows.is_empty():
		_rows = segments()
		_skeleton_list = _skeletons()
	var rows := _rows
	var at := -1
	for i in rows.size():
		if float(rows[i].start) <= t:
			at = i
	if at < 0:
		return
	var row: Dictionary = rows[at]
	var fade_in := _fades_in(row, at, t)
	var out_blend := float(MOVES[class_id].get("out", OUT_BLEND))
	var fade_out := (1.0 - t) * LENGTH < out_blend
	var skeletons := _skeleton_list
	if not fade_in and not fade_out:
		_drive(row, t, skeletons)
		return
	var pose := _compose(rows, t, skeletons)
	if fade_out:
		var rest := _rest_pose(skeletons)
		var sample := func(at: float) -> Array: return _compose(rows, at, skeletons)
		var lifted := _lift(sample, 1.0 - out_blend / LENGTH, t, rest)
		pose = _mix(rest, lifted.pose, smoothstep(0.0, 1.0, (1.0 - t) * LENGTH / out_blend), lifted.signs)
	_write(pose, skeletons)


func _fades_in(row: Dictionary, index: int, t: float) -> bool:
	var window := _window(class_id, index)
	return window > 0.0 and (t - float(row.start)) * LENGTH < window


func _compose(rows: Array, t: float, skeletons: Array) -> Array:
	if _composed.has(t):
		return _composed[t]
	var pose := _compose_fresh(rows, t, skeletons)
	_composed[t] = pose
	return pose


func _compose_fresh(rows: Array, t: float, skeletons: Array) -> Array:
	var at := 0
	for i in rows.size():
		if float(rows[i].start) <= t:
			at = i
	var row: Dictionary = rows[at]
	if not _fades_in(row, at, t):
		return _grab(row, t, skeletons)
	var from := _rest_pose(skeletons) if at == 0 else _grab(rows[at - 1], float(row.start), skeletons)
	var sample := func(when: float) -> Array: return _grab(row, when, skeletons)
	var lifted := _lift(sample, float(row.start), t, from)
	var f := smoothstep(0.0, 1.0, (t - float(row.start)) * LENGTH / _window(class_id, at))
	return _mix(from, lifted.pose, f, lifted.signs)


func _lift(sample: Callable, t0: float, t: float, from: Array) -> Dictionary:
	var prev: Array = sample.call(t0)
	var signs := _signs(from, prev)
	var grid := 1.0 / (LENGTH * FRAME_RATE)
	var points: Array = []
	for k in range(1, int((t - t0) / grid) + 1):
		points.append(t0 + float(k) * grid)
	if points.is_empty() or t - float(points[-1]) > 0.000001:
		points.append(t)
	for when in points:
		var cur: Array = sample.call(when)
		for s in cur.size():
			for i in (cur[s] as Array).size():
				if (prev[s][i][1] as Quaternion).dot(cur[s][i][1]) < 0.0:
					signs[s][i] = -float(signs[s][i])
		prev = cur
	return {"pose": prev, "signs": signs}


static func _window(id: String, index: int) -> float:
	var entry: Array = MOVES[id].clips[index]
	return float(entry[3]) if entry.size() > 3 else BLEND


func _skeletons() -> Array:
	return pilot.find_children("*", "Skeleton3D", true, false)


func _drive(row: Dictionary, t: float, skeletons: Array) -> void:
	for skeleton in skeletons:
		skeleton.reset_bone_poses()
	var clip: String = row.clip
	if clip == "":
		return
	if _clip != clip or animator.assigned_animation != clip or animator.is_playing():
		animator.play(clip, 0.0)
		animator.pause()
		_clip = clip
	var at := (t - float(row.start)) * LENGTH * float(row.speed)
	animator.seek(clampf(at, 0.0, float(row.length)), true)


func _grab(row: Dictionary, t: float, skeletons: Array) -> Array:
	var key := Vector3(float(row.start), t, float(String(row.clip).hash() % 100000))
	if _memo.has(key):
		return _memo[key]
	_drive(row, t, skeletons)
	var pose: Array = []
	for skeleton in skeletons:
		var bones: Array = []
		for i in skeleton.get_bone_count():
			bones.append([skeleton.get_bone_pose_position(i), skeleton.get_bone_pose_rotation(i), skeleton.get_bone_pose_scale(i)])
		pose.append(bones)
	_memo[key] = pose
	return pose


static func _rest_pose(skeletons: Array) -> Array:
	var pose: Array = []
	for skeleton in skeletons:
		var bones: Array = []
		for i in skeleton.get_bone_count():
			var rest: Transform3D = skeleton.get_bone_rest(i)
			bones.append([rest.origin, rest.basis.get_rotation_quaternion(), rest.basis.get_scale()])
		pose.append(bones)
	return pose


static func _signs(from: Array, anchor: Array) -> Array:
	var signs: Array = []
	for s in anchor.size():
		var bones: Array = []
		for i in (anchor[s] as Array).size():
			bones.append(-1.0 if (from[s][i][1] as Quaternion).dot(anchor[s][i][1]) < 0.0 else 1.0)
		signs.append(bones)
	return signs


static func _mix(from: Array, to: Array, f: float, signs: Array) -> Array:
	var pose: Array = []
	for s in to.size():
		var bones: Array = []
		for i in (to[s] as Array).size():
			var a: Array = from[s][i]
			var b: Array = to[s][i]
			bones.append([(a[0] as Vector3).lerp(b[0], f), _slerp(a[1], (b[1] as Quaternion) * float(signs[s][i]), f),
				(a[2] as Vector3).lerp(b[2], f)])
		pose.append(bones)
	return pose


static func _slerp(a: Quaternion, b: Quaternion, f: float) -> Quaternion:
	var cosine := clampf(a.dot(b), -1.0, 1.0)
	var angle := acos(cosine)
	var sine := sin(angle)
	if sine < 0.001:
		return (a * (1.0 - f) + b * f).normalized()
	return (a * (sin((1.0 - f) * angle) / sine) + b * (sin(f * angle) / sine)).normalized()


static func _write(pose: Array, skeletons: Array) -> void:
	for s in skeletons.size():
		for i in (pose[s] as Array).size():
			var bone: Array = pose[s][i]
			skeletons[s].set_bone_pose_position(i, bone[0])
			skeletons[s].set_bone_pose_rotation(i, bone[1])
			skeletons[s].set_bone_pose_scale(i, bone[2])


func segments() -> Array:
	var rows: Array = []
	if animator == null or not MOVES.has(class_id):
		return rows
	var clips: Array = MOVES[class_id].clips
	for i in clips.size():
		var entry: Array = clips[i]
		var start := float(entry[0])
		var finish := float(clips[i + 1][0]) if i + 1 < clips.size() else 1.0
		var clip := clip_for(animator, String(entry[1]))
		var length := animator.get_animation(clip).length if clip != "" else 0.0
		var speed := float(entry[2])
		if speed <= 0.0 and length > 0.0:
			speed = length / ((finish - start) * LENGTH)
		rows.append({"start": start, "end": finish, "clip": clip, "speed": speed, "length": length})
	return rows


static func clip_for(player: AnimationPlayer, wanted: String) -> String:
	if player.has_animation(wanted):
		return wanted
	return FALLBACK if player.has_animation(FALLBACK) else ""


static func pose_at(id: String, t: float) -> Dictionary:
	var pose := {"at": SEAT, "yaw": 0.0, "pitch": 0.0, "roll": 0.0,
		"spin": 0.0, "squash": 1.0, "shake": Vector3.ZERO}
	var leave := _span(t, 0.0, 0.16)
	var back := _span(t, 0.86, 1.0)
	match id:
		"pylon_engineer":
			var top := Vector3(0.0, TOP + FEET, 0.0)
			pose.at = _hop(SEAT, top, leave, 0.7).lerp(SEAT, _ease_in(back))
			var balance := _span(t, 0.16, 0.86)
			pose.spin = balance * TAU * 1.5
			pose.roll = sin(t * 34.0) * 0.28 * balance
			pose.at.x += sin(t * 17.0) * 0.08 * balance
		"runner_gunner":
			var side := Vector3(1.2, GROUND + FEET, 0.35)
			pose.at = _hop(SEAT, side, leave, 0.9).lerp(SEAT, _ease_in(back))
			var turn := _span(t, 0.6, 0.7)
			pose.yaw = lerpf(PI * 0.82, -0.25, _ease_out(turn))
			pose.roll = -0.22 * (1.0 - turn) * _span(t, 0.16, 0.24)
		"demolitions_caster":
			var high := Vector3(0.0, TOP + FEET + 0.6, 0.15)
			var hover := _span(t, 0.16, 0.74)
			pose.at = SEAT.lerp(high, _ease_out(leave))
			pose.at.y += sin(t * 18.0) * 0.06 * hover
			pose.yaw = hover * 0.6 - 0.3
			var drop := _span(t, 0.74, 0.8)
			if drop > 0.0:
				pose.at = high.lerp(Vector3(0.0, TOP + FEET, 0.15), _ease_in(drop))
			var impact := _span(t, 0.8, 0.9)
			if impact > 0.0 and impact < 1.0:
				pose.squash = 1.0 - 0.18 * sin(impact * PI)
			pose.at = pose.at.lerp(SEAT, _ease_in(back))
		"tarn":
			var perch := Vector3(0.0, TOP + 0.12, 0.0)
			pose.at = _hop(SEAT, perch, leave, 0.4).lerp(SEAT, _ease_in(back))
			var growl := _span(t, 0.22, 0.56) * (1.0 - _span(t, 0.56, 0.6))
			pose.shake = Vector3(sin(t * 160.0), sin(t * 210.0) * 0.5, cos(t * 140.0)) * 0.035 * growl * (0.0 if reduced_motion else 1.0)
			pose.yaw = 0.15
		"tally":
			var side := Vector3(-1.35, GROUND + FEET, 0.3)
			pose.at = _hop(SEAT, side, leave, 0.8).lerp(SEAT, _ease_in(back))
			pose.yaw = PI * 0.5 - 0.35
			for stamp in [0.2, 0.42, 0.64]:
				var hit := _span(t, stamp + 0.08, stamp + 0.14)
				if hit > 0.0 and hit < 1.0:
					pose.squash = 1.0 - 0.06 * sin(hit * PI)
		"remembered_cannon":
			var rise := _ease_out(_span(t, 0.0, 0.78))
			pose.at = SEAT.lerp(Vector3(0.0, TOP + 0.4, 0.0), rise)
			pose.at = pose.at.lerp(SEAT, _ease_in(_span(t, 0.92, 1.0)))
			pose.yaw = 0.1 * sin(t * 3.0)
	return pose


static func _hop(from: Vector3, to: Vector3, f: float, height: float) -> Vector3:
	var p := from.lerp(to, _ease_out(f))
	p.y += sin(f * PI) * height
	return p


static func _span(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func _ease_out(f: float) -> float:
	return 1.0 - (1.0 - f) * (1.0 - f)


static func _ease_in(f: float) -> float:
	return f * f
