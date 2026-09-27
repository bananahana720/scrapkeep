extends Node3D

const Palette := preload("res://src/core/palette.gd")

# One committed attack area: a crane's sector, a slag ring or a charge lane. It is laid
# once, when the attack commits, and the drawing and every hit test read the same
# numbers, so what the player sees is what can hit them (TADR-008). WARN lasts at
# least 1.0 s; a hit is possible only while LIVE and only where contains() is true.

enum Shape { SECTOR, ANNULUS, LANE }
enum { WARN, LIVE, DONE }

const MIN_WARN := 1.0
const DRAW_LIFT := 0.08
const MOLTEN := Color("ff7a2e")

var attack_id := ""
var shape := Shape.ANNULUS
var state := WARN
var age := 0.0
var warn_seconds := MIN_WARN
var live_seconds := 1.0
# SECTOR and ANNULUS: the floor centre. LANE: where the lane starts.
var centre := Vector3.ZERO
var r_in := 0.0
var r_out := 0.0
# SECTOR: the sweep runs from a_from to a_to (radians about +y, atan2(z, x)).
var a_from := 0.0
var a_to := 0.0
# LANE: flat unit heading, how far it reaches behind the start, its length and half width.
var heading := Vector3.FORWARD
var back := 0.0
var length := 0.0
var half_width := 0.0
# How high above the ground under the ball the area reaches; a jump can clear it.
var reach := 3.0
# (point) -> float: the ground height under a point.
var ground := Callable()
# ANNULUS: (point) -> bool, true where the ring is quenched and safe.
var excluded := Callable()
var color := Palette.HAZARD
# live_fraction() before the latest step, so a sweep can test only what it just crossed.
var prev_fraction := 0.0

var _mat: StandardMaterial3D
var _mesh: MeshInstance3D
# ANNULUS: which of its drawn segments are open (quenched) right now.
var _open: Array[bool] = []

const RING_SEGMENTS := 72


func commit_sector(id: String, at: Vector3, band: Vector2, from_angle: float, to_angle: float, height: float, warn: float, live: float) -> void:
	shape = Shape.SECTOR
	attack_id = id
	centre = at
	r_in = band.x
	r_out = band.y
	a_from = from_angle
	a_to = to_angle
	reach = height
	_times(warn, live)


func commit_annulus(id: String, at: Vector3, band: Vector2, height: float, warn: float, live: float) -> void:
	shape = Shape.ANNULUS
	attack_id = id
	centre = at
	r_in = band.x
	r_out = band.y
	reach = height
	_times(warn, live)


func commit_lane(id: String, from: Vector3, dir: Vector3, behind: float, ahead: float, half: float, height: float, warn: float, live: float) -> void:
	shape = Shape.LANE
	attack_id = id
	centre = from
	heading = Vector3(dir.x, 0.0, dir.z).normalized()
	back = behind
	length = ahead
	half_width = half
	reach = height
	_times(warn, live)


func _times(warn: float, live: float) -> void:
	warn_seconds = maxf(MIN_WARN, warn)
	live_seconds = live
	name = "Hazard_%s" % attack_id


func _ready() -> void:
	_build_mesh()


func step(delta: float) -> void:
	prev_fraction = live_fraction()
	age += delta
	if state == WARN and age >= warn_seconds:
		state = LIVE
	if state == LIVE and age >= warn_seconds + live_seconds:
		state = DONE
	if shape == Shape.ANNULUS and is_inside_tree() and _open_segments() != _open:
		_build_mesh()
	_restyle()


# ANNULUS: whether the drawing covers a point. A quenched span is left undrawn, so the
# crust under it shows through and no telegraph has to be painted over.
func draws(point: Vector3) -> bool:
	var r := _flat(point - centre).length()
	if shape != Shape.ANNULUS or r < r_in or r > r_out:
		return contains(point)
	var d := _flat(point - centre)
	var i := int(floor(wrapf(atan2(d.z, d.x), 0.0, TAU) / TAU * RING_SEGMENTS)) % RING_SEGMENTS
	return _open.size() != RING_SEGMENTS or not _open[i]


func _open_segments() -> Array[bool]:
	var open: Array[bool] = []
	var mid := (r_in + r_out) * 0.5
	for i in RING_SEGMENTS:
		var a := TAU * (i + 0.5) / RING_SEGMENTS
		open.append(excluded.is_valid() and excluded.call(centre + Vector3(cos(a), 0.0, sin(a)) * mid))
	return open


func is_live() -> bool:
	return state == LIVE


func is_done() -> bool:
	return state == DONE


func seconds_until_live() -> float:
	return maxf(0.0, warn_seconds - age)


# 0 at the start of LIVE, 1 at its end.
func live_fraction() -> float:
	return clampf((age - warn_seconds) / maxf(0.001, live_seconds), 0.0, 1.0)


func finish() -> void:
	state = DONE


func ground_at(point: Vector3) -> float:
	return ground.call(point) if ground.is_valid() else centre.y


# The committed geometry. Every hit this area makes is inside it.
func contains(point: Vector3) -> bool:
	var above := point.y - ground_at(point)
	if above > reach or above < -2.0:
		return false
	match shape:
		Shape.SECTOR:
			var r := _flat(point - centre).length()
			if r < r_in or r > r_out:
				return false
			var u := sweep_offset(point)
			return u >= -_angle_margin(r) and u <= absf(a_to - a_from) + _angle_margin(r)
		Shape.ANNULUS:
			var r := _flat(point - centre).length()
			if r < r_in or r > r_out:
				return false
			return not (excluded.is_valid() and excluded.call(point))
		Shape.LANE:
			var local := _flat(point - centre)
			var along := local.dot(heading)
			return along >= -back and along <= length and absf(local.dot(side())) <= half_width
	return false


# SECTOR: how far along the sweep a point sits, in radians from a_from.
func sweep_offset(point: Vector3) -> float:
	var d := _flat(point - centre)
	var angle := atan2(d.z, d.x)
	var dir := signf(a_to - a_from) if a_to != a_from else 1.0
	return wrapf((angle - a_from) * dir, -PI, PI)


# A ball of radius 1 m touches the sector a little before its centre enters it.
func _angle_margin(r: float) -> float:
	return 1.0 / maxf(r, 1.0)


# LANE: the flat axis across the lane.
func side() -> Vector3:
	return Vector3.UP.cross(heading).normalized()


func lane_along(point: Vector3) -> float:
	return _flat(point - centre).dot(heading)


func lane_lateral(point: Vector3) -> float:
	return _flat(point - centre).dot(side())


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _restyle() -> void:
	if _mat == null:
		return
	var tone := color
	var alpha := 0.2 + 0.25 * (0.5 + 0.5 * sin(age * TAU * 3.0))
	if state == LIVE:
		tone = color.lerp(MOLTEN, 0.5) if shape == Shape.ANNULUS else color
		alpha = 0.8
	elif state == DONE:
		alpha = 0.0
	_mat.albedo_color = Color(tone.r, tone.g, tone.b, alpha)


func _point(at: Vector3) -> Vector3:
	return Vector3(at.x, ground_at(at) + DRAW_LIFT, at.z)


func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match shape:
		Shape.SECTOR:
			_add_arc(st, a_from, a_to, 16)
		Shape.ANNULUS:
			_open = _open_segments()
			for i in RING_SEGMENTS:
				if not _open[i]:
					_add_arc(st, TAU * i / RING_SEGMENTS, TAU * (i + 1) / RING_SEGMENTS, 1)
		Shape.LANE:
			var steps := maxi(1, int(ceil((length + back) / 2.0)))
			var s := side() * half_width
			for i in steps:
				var t0 := -back + (length + back) * float(i) / steps
				var t1 := -back + (length + back) * float(i + 1) / steps
				_quad(st, _point(centre + heading * t0 - s), _point(centre + heading * t0 + s),
					_point(centre + heading * t1 + s), _point(centre + heading * t1 - s))
	if is_instance_valid(_mesh):
		_mesh.queue_free()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = st.commit()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mat == null:
		_mat = Palette.unshaded(Color(color.r, color.g, color.b, 0.3))
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.no_depth_test = true
		_mat.render_priority = 40
	_mesh.material_override = _mat
	add_child(_mesh)
	_restyle()


func _add_arc(st: SurfaceTool, from_angle: float, to_angle: float, segments: int) -> void:
	for i in segments:
		var a0 := lerpf(from_angle, to_angle, float(i) / segments)
		var a1 := lerpf(from_angle, to_angle, float(i + 1) / segments)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		_quad(st, _point(centre + d0 * r_in), _point(centre + d0 * r_out),
			_point(centre + d1 * r_out), _point(centre + d1 * r_in))


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p in [a, b, c, a, c, d]:
		st.add_vertex(to_local(p) if is_inside_tree() else p)
