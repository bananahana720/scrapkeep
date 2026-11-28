extends Node3D

const Bolts := preload("res://src/combat/bolts.gd")
const Density := preload("res://src/presentation/density.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const Palette := preload("res://src/core/palette.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")

const PRIORITY := 1
const ARC_LIFE := 0.16
const RING_LIFE := 0.24
const SPARK_LIFE := 0.12
const ARC_SEGMENTS := 7
const RING_SEGMENTS := 40
const BIT_LIFE := 0.16
const PAYOFF_LIFE := 0.3
const BIT_CAP := 12
const PAYOFF_CAP := 8
const FLAIR_CLASS := "P5"
const BIT_ALPHA := 1.0
const PAYOFF_ALPHA := 0.7
const BIT_REACH := 1.4
const FROST_POINTS := 6
const FROST_REACH := 0.8
const QUAKE_SEGMENTS := 32
const PRESS_POP := 0.4

var _arcs: Array = []
var _rings: Array = []
var _sparks: Array = []
var _beams: Array = []
var _flair: Array = []
var _mesh: ImmediateMesh
var _arc_rng := RandomNumberGenerator.new()


func _init() -> void:
	_arc_rng.seed = 0xA7C


func setup() -> void:
	name = "CombatEffects"
	_mesh = ImmediateMesh.new()
	var view := MeshInstance3D.new()
	view.mesh = _mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = PRIORITY
	view.material_override = mat
	view.top_level = true
	add_child(view)
	set_process(false)


func arc(from: Vector3, to: Vector3, color: Color) -> void:
	_arcs.append({"from": from, "to": to, "color": color, "life": ARC_LIFE})
	set_process(true)


func ring(at: Vector3, radius: float, color: Color) -> void:
	_rings.append({"at": at, "radius": radius, "color": color, "life": RING_LIFE})
	set_process(true)


func spark(at: Vector3, color: Color) -> void:
	_sparks.append({"at": at, "color": color, "life": SPARK_LIFE})
	set_process(true)


func beam(from: Vector3, to: Vector3, color: Color, life: float) -> void:
	_beams.append({"from": from, "to": to, "color": color, "life": life, "span": life})
	set_process(true)


func bit_hit(bit_name: String, point: Vector3, dir: Vector3, aim := Vector3.ZERO, fork_deg := Bolts.SPLIT_ANGLE_DEG) -> void:
	if not ShotBits.TABLE.has(bit_name) or (bit_name == "pull" and _flat(aim).length_squared() < 0.0001):
		return
	_add_flair({"kind": bit_name, "at": point, "dir": dir, "aim": aim, "fork_deg": fork_deg,
		"color": ShotBits.TABLE[bit_name]["color"]}, BIT_ALPHA, BIT_LIFE, BIT_CAP)


func frost_flash(at: Vector3) -> void:
	_add_flair({"kind": "frost", "at": at, "color": Palette.ICE}, PAYOFF_ALPHA, PAYOFF_LIFE, PAYOFF_CAP)


func shockwave(at: Vector3, radius: float, color: Color) -> void:
	_add_flair({"kind": "quake", "at": at, "radius": radius, "color": color}, PAYOFF_ALPHA, PAYOFF_LIFE, PAYOFF_CAP)


static func is_bit_mark(entry: Dictionary) -> bool:
	return String(entry["kind"]) in ShotBits.NAMES


static func cap_group(entry: Dictionary) -> String:
	return "bit" if is_bit_mark(entry) else String(entry["kind"])


func _add_flair(entry: Dictionary, alpha: float, life: float, cap: int) -> void:
	var governed: Vector3 = Density.live().apply(FLAIR_CLASS, alpha, 1.0, life)
	entry["shade"] = governed.x
	entry["size"] = governed.y
	entry["life"] = governed.z
	entry["span"] = governed.z
	var group := cap_group(entry)
	var same: Array = _flair.filter(func(e): return cap_group(e) == group)
	for i in maxi(0, same.size() - cap + 1):
		_flair.erase(same[i])
	_flair.append(entry)
	set_process(true)


func clear() -> void:
	_beams.clear()
	_flair.clear()
	_arcs.clear()
	_rings.clear()
	_sparks.clear()
	_mesh.clear_surfaces()
	set_process(false)


func live_mark_count() -> int:
	return _arcs.size() + _rings.size() + _sparks.size() + _beams.size() + _flair.size()


func _process(delta: float) -> void:
	_mesh.clear_surfaces()
	if not _arcs.is_empty():
		_arcs = _age(_arcs, delta)
	if not _rings.is_empty():
		_rings = _age(_rings, delta)
	if not _sparks.is_empty():
		_sparks = _age(_sparks, delta)
	if not _beams.is_empty():
		_beams = _age(_beams, delta)
	if not _flair.is_empty():
		_flair = _age(_flair, delta)
	if _arcs.is_empty() and _rings.is_empty() and _sparks.is_empty() and _beams.is_empty() and _flair.is_empty():
		set_process(false)
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for entry in _arcs:
		_draw_arc(entry)
	for entry in _rings:
		_draw_ring(entry)
	for entry in _sparks:
		_draw_spark(entry)
	for entry in _beams:
		_line(entry["from"], entry["to"], Color(entry["color"], beam_alpha(entry)))
	for entry in _flair:
		var alpha := flair_alpha(entry)
		for seg in flair_lines(entry):
			_line(seg[0], seg[1], Color(seg[2], alpha))
	_mesh.surface_end()


static func arc_alpha(entry: Dictionary) -> float:
	return entry["color"].a * clampf(entry["life"] / ARC_LIFE, 0.0, 1.0)


static func ring_alpha(entry: Dictionary) -> float:
	return entry["color"].a * 0.7 * clampf(entry["life"] / RING_LIFE, 0.0, 1.0)


static func spark_alpha(entry: Dictionary) -> float:
	return entry["color"].a * 0.9


static func beam_alpha(entry: Dictionary) -> float:
	return entry["color"].a * clampf(entry["life"] / entry["span"], 0.0, 1.0)


static func flair_alpha(entry: Dictionary) -> float:
	return FlashGuard.info(entry["color"].a * float(entry["shade"]) * clampf(entry["life"] / entry["span"], 0.0, 1.0))


func brightest() -> float:
	var best := 0.0
	for entry in _arcs:
		best = maxf(best, arc_alpha(entry))
	for entry in _rings:
		best = maxf(best, ring_alpha(entry))
	for entry in _sparks:
		best = maxf(best, spark_alpha(entry))
	for entry in _beams:
		best = maxf(best, beam_alpha(entry))
	for entry in _flair:
		best = maxf(best, flair_alpha(entry))
	return best


static func _age(list: Array, delta: float) -> Array:
	var kept: Array = []
	for entry in list:
		entry["life"] -= delta
		if entry["life"] > 0.0:
			kept.append(entry)
	return kept


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)


func _draw_arc(entry: Dictionary) -> void:
	var from: Vector3 = entry["from"]
	var to: Vector3 = entry["to"]
	var color := Color(entry["color"], arc_alpha(entry))
	var span := to - from
	var jitter := minf(1.2, span.length() * 0.08)
	var previous := from
	for i in range(1, ARC_SEGMENTS + 1):
		var t := float(i) / ARC_SEGMENTS
		var point := from + span * t
		if i < ARC_SEGMENTS:
			point += Vector3(_arc_rng.randf_range(-1.0, 1.0), _arc_rng.randf_range(-1.0, 1.0), _arc_rng.randf_range(-1.0, 1.0)) * jitter
		_line(previous, point, color)
		previous = point


func _draw_ring(entry: Dictionary) -> void:
	var life := clampf(entry["life"] / RING_LIFE, 0.0, 1.0)
	var radius: float = entry["radius"] * lerpf(1.0, 0.55, life)
	var color := Color(entry["color"], ring_alpha(entry))
	var at: Vector3 = entry["at"] + Vector3.UP * 0.4
	var previous := at + Vector3(radius, 0.0, 0.0)
	for i in range(1, RING_SEGMENTS + 1):
		var angle := TAU * i / RING_SEGMENTS
		var point := at + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_line(previous, point, color)
		previous = point


func _draw_spark(entry: Dictionary) -> void:
	var at: Vector3 = entry["at"]
	var size := 0.5 * clampf(entry["life"] / SPARK_LIFE, 0.0, 1.0) + 0.15
	var color := Color(entry["color"], spark_alpha(entry))
	_line(at - Vector3.RIGHT * size, at + Vector3.RIGHT * size, color)
	_line(at - Vector3.UP * size, at + Vector3.UP * size, color)
	_line(at - Vector3.BACK * size, at + Vector3.BACK * size, color)


static func flair_lines(entry: Dictionary) -> Array:
	var grown := 1.0 - clampf(entry["life"] / entry["span"], 0.0, 1.0)
	var at: Vector3 = entry["at"]
	var color: Color = entry["color"]
	var reach := BIT_REACH * float(entry["size"])
	var out: Array = []
	match String(entry["kind"]):
		"pierce":
			var dir := _unit(entry["dir"], Vector3.FORWARD)
			var side := _side(dir)
			var tip := at + dir * reach * lerpf(0.7, 1.15, grown)
			out.append([at - dir * reach * 0.3, tip, color])
			out.append([tip, tip - dir * reach * 0.35 + side * reach * 0.25, color])
			out.append([tip, tip - dir * reach * 0.35 - side * reach * 0.25, color])
		"bounce":
			var leave := _unit(entry["dir"], Vector3.FORWARD)
			var came := _unit(entry["aim"], -leave.rotated(Vector3.UP, deg_to_rad(70.0)))
			out.append([at, at + came * reach * 0.8, color])
			out.append([at, at + leave * reach * lerpf(0.8, 1.1, grown), color])
			_cross(out, at, reach * 0.12, color)
		"split":
			var dir := _unit(entry["dir"], Vector3.FORWARD)
			var up := _side(dir).cross(dir).normalized()
			var fork := deg_to_rad(float(entry["fork_deg"]))
			out.append([at - dir * reach * 0.25, at, color])
			for side_sign in [-1.0, 1.0]:
				out.append([at, at + dir.rotated(up, fork * side_sign) * reach * lerpf(0.8, 1.15, grown), color])
			if float(entry["fork_deg"]) < Bolts.SPLIT_ANGLE_DEG - 0.01:
				var pop := color.lightened(FlashGuard.whiten(PRESS_POP))
				for i in 8:
					var ray := dir.rotated(up, TAU * i / 8.0)
					out.append([at + ray * reach * 0.12, at + ray * reach * lerpf(0.3, 0.45, grown), pop])
		"pull":
			var toward := _unit(_flat(entry["aim"]), Vector3.BACK)
			var side := _side(toward)
			var head := at + toward * reach * lerpf(0.8, 1.2, grown)
			out.append([at, head, color])
			out.append([head, head - toward * reach * 0.3 + side * reach * 0.22, color])
			out.append([head, head - toward * reach * 0.3 - side * reach * 0.22, color])
		"heat":
			for i in 6:
				var a := TAU * i / 6.0
				var ray := Vector3(cos(a), 1.4, sin(a)).normalized()
				out.append([at + ray * reach * 0.15, at + ray * reach * lerpf(0.45, 0.7, grown), color])
		"frost":
			var arm := FROST_REACH * lerpf(0.8, 1.0, grown)
			var centre := at
			for i in FROST_POINTS:
				var a := TAU * i / FROST_POINTS
				var out_dir := Vector3(cos(a), 0.0, sin(a))
				var tip := centre + out_dir * arm
				var knot := centre + out_dir * arm * 0.6
				out.append([centre, tip, color])
				for barb in [-1.0, 1.0]:
					out.append([knot, knot + out_dir.rotated(Vector3.UP, deg_to_rad(45.0) * barb) * arm * 0.3, color])
		"quake":
			var radius := float(entry["radius"])
			var eased := 1.0 - pow(1.0 - grown, 2.0)
			_circle(out, at, radius * lerpf(0.3, 0.92, eased), color)
			_circle(out, at, radius, color.darkened(0.25))
	return out


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _unit(v: Vector3, fallback: Vector3) -> Vector3:
	return v.normalized() if v.length_squared() > 0.0001 else fallback


static func _side(dir: Vector3) -> Vector3:
	var up_hint := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	return dir.cross(up_hint).normalized()


static func _cross(out: Array, at: Vector3, size: float, color: Color) -> void:
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		out.append([at - axis * size, at + axis * size, color])


static func _circle(out: Array, at: Vector3, radius: float, color: Color) -> void:
	var centre := at + Vector3.UP * 0.4
	var previous := centre + Vector3(radius, 0.0, 0.0)
	for i in range(1, QUAKE_SEGMENTS + 1):
		var angle := TAU * i / QUAKE_SEGMENTS
		var point := centre + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		out.append([previous, point, color])
		previous = point
