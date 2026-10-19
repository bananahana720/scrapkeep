extends RefCounted

# A pilot climbs out of their ball for one bar pair and does their signature bit, then hops back
# in (TONE-BIBLE.md cast table; Andrew, 2026-10-17: "hop out of their ball... act goofy on top
# of it or around it"). One move per pilot, the same move everywhere it plays: the title
# openings, the title deck and the pilot select cards.
#
# The move is a pure function of t (0 to 1 over LENGTH seconds), so a frame can be sampled
# anywhere and tests and stills are exact. Positions are the pilot's origin in the shell holder's
# space: the ball's centre and the seated pilot are both at the origin, the ball's radius is about
# one (top y 1, ground y -1) and a pilot's feet are FEET below its origin.
# Clips are the pilot GLB's own (pilot_<name>_anim.glb); a clip a pilot lacks falls back to
# big_cheer, then to the rest pose.

const LENGTH := 2.0 * 240.0 / 129.0
const TOP := 0.98
const GROUND := -0.98
const FEET := 0.54
const SEAT := Vector3.ZERO
const FALLBACK := "big_cheer"

# word: the drawn sound word a title opening stamps over the move.
# clips: [start t, clip, speed]; the last entry at or before t plays.
const MOVES := {
	"pylon_engineer": {"word": "TA-DA!", "line": "Balances on it. Mostly.",
		"clips": [[0.0, "drop_land", 1.0], [0.3, "big_cheer", 0.8], [0.86, "drop_land", 1.0]]},
	"runner_gunner": {"word": "...HUH?", "line": "Leans on the ball. Faces the wrong way.",
		"clips": [[0.0, "drop_land", 1.0], [0.22, "brace", 0.5], [0.6, "wince", 0.9], [0.86, "drop_land", 1.0]]},
	"demolitions_caster": {"word": "BOOM!", "line": "Hovers. Hovers. Commits.",
		"clips": [[0.0, "heave", 1.0], [0.16, "phew", 0.35], [0.74, "smash", 1.4], [0.9, "drop_land", 1.0]]},
	"tarn": {"word": "grrr", "line": "Sits on top. The machine growls for both of them.",
		"clips": [[0.0, "drop_land", 1.0], [0.2, "slump", 0.6], [0.58, "big_cheer", 0.5], [0.88, "drop_land", 1.0]]},
	"tally": {"word": "PAID!", "line": "Stamps the ball. Itemises it.",
		"clips": [[0.0, "drop_land", 1.0], [0.2, "cast_line", 1.6], [0.42, "cast_line", 1.6], [0.64, "cast_line", 1.6], [0.88, "drop_land", 1.0]]},
	"remembered_cannon": {"word": "...hello.", "line": "Rises out very slowly. Waves once.",
		"clips": [[0.0, "heave", 0.3], [0.78, "big_cheer", 0.6]]},
}

# Reduced motion (Game.set_reduced_motion keeps it current): the growl shake stops.
static var reduced_motion := false

var holder: Node3D
var core: Node3D
var pod: Node3D
var pilot: Node3D
var animator: AnimationPlayer
var class_id := ""
var out := false
# Reduced motion: the pilot still climbs out, but the ball neither spins, squashes nor shakes.
var calm := false

var _seat := Transform3D.IDENTITY
var _scale := Vector3.ONE
var _core_rest := Transform3D.IDENTITY
var _clip := ""


# rec: the shell's holder (stays put), core (the cage that rolls), pod (the upright cradle the
# pilot sits in), pilot and animator, as hero_assets.gd fits them.
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


# Poses the move at t. Outside 0 to 1 the pilot is back in the pod.
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


# Puts the pilot back in the pod as it was and the core where it was. Safe to call twice.
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


func _climb_out() -> void:
	out = true
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
	var pick: Array = []
	for entry in MOVES[class_id].clips:
		if float(entry[0]) <= t:
			pick = entry
	if pick.is_empty():
		return
	var clip := clip_for(animator, String(pick[1]))
	if clip == "":
		return
	if _clip != clip or animator.current_animation != clip:
		animator.play(clip, 0.0)
		_clip = clip
	var length := animator.get_animation(clip).length
	var at := (t - float(pick[0])) * LENGTH * float(pick[2])
	animator.seek(minf(at, length), true)


static func clip_for(player: AnimationPlayer, wanted: String) -> String:
	if player.has_animation(wanted):
		return wanted
	return FALLBACK if player.has_animation(FALLBACK) else ""


# The pose at t: {at, yaw, pitch, roll} for the pilot; {spin, squash, shake} for the core.
# yaw 0 faces the camera side (+z).
static func pose_at(id: String, t: float) -> Dictionary:
	var pose := {"at": SEAT, "yaw": 0.0, "pitch": 0.0, "roll": 0.0,
		"spin": 0.0, "squash": 1.0, "shake": Vector3.ZERO}
	var leave := _span(t, 0.0, 0.16)
	var back := _span(t, 0.86, 1.0)
	match id:
		"pylon_engineer":
			# Pops onto the top and balances while the ball keeps rolling under her.
			var top := Vector3(0.0, TOP + FEET, 0.0)
			pose.at = _hop(SEAT, top, leave, 0.7).lerp(SEAT, _ease_in(back))
			var balance := _span(t, 0.16, 0.86)
			pose.spin = balance * TAU * 1.5
			pose.roll = sin(t * 34.0) * 0.28 * balance
			pose.at.x += sin(t * 17.0) * 0.08 * balance
		"runner_gunner":
			# Steps off to the side, leans on the ball facing away, then turns round, surprised.
			var side := Vector3(1.2, GROUND + FEET, 0.35)
			pose.at = _hop(SEAT, side, leave, 0.9).lerp(SEAT, _ease_in(back))
			var turn := _span(t, 0.6, 0.7)
			pose.yaw = lerpf(PI * 0.82, -0.25, _ease_out(turn))
			pose.roll = -0.22 * (1.0 - turn) * _span(t, 0.16, 0.24)
		"demolitions_caster":
			# Rises high, hovers through a far too long dramatic pause, then drops on the top: BOOM.
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
			# Climbs on top and sits; the machine growls and shakes for both of them; a gentle wave.
			var perch := Vector3(0.0, TOP + 0.12, 0.0)
			pose.at = _hop(SEAT, perch, leave, 0.4).lerp(SEAT, _ease_in(back))
			var growl := _span(t, 0.22, 0.56) * (1.0 - _span(t, 0.56, 0.6))
			pose.shake = Vector3(sin(t * 160.0), sin(t * 210.0) * 0.5, cos(t * 140.0)) * 0.035 * growl * (0.0 if reduced_motion else 1.0)
			pose.yaw = 0.15
		"tally":
			# Steps off to the other side and stamps the ball three times.
			var side := Vector3(-1.35, GROUND + FEET, 0.3)
			pose.at = _hop(SEAT, side, leave, 0.8).lerp(SEAT, _ease_in(back))
			pose.yaw = PI * 0.5 - 0.35
			for stamp in [0.2, 0.42, 0.64]:
				var hit := _span(t, stamp + 0.08, stamp + 0.14)
				if hit > 0.0 and hit < 1.0:
					pose.squash = 1.0 - 0.06 * sin(hit * PI)
		"remembered_cannon":
			# Rises out of the top very slowly, as if remembering how; waves once.
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
