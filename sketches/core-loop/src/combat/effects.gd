extends Node3D

# Combat's own short-lived marks: chain arcs, blast rings, impact sparks and straight beams. They show
# where a committed hit landed, for a fraction of a second, drawn as thin lines at
# PRIORITY, below every enemy telegraph (principle 4: our effects never hide a threat).
# Presentation (writer C) owns the rest of the juice; these are the minimum a greybox
# needs to read what the weapons did. Jitter has its own stream, independent of the
# run's seeded stream and engine consumers of global randomness.

const PRIORITY := 1
const ARC_LIFE := 0.16
const RING_LIFE := 0.24
const SPARK_LIFE := 0.12
const ARC_SEGMENTS := 7
const RING_SEGMENTS := 40

var _arcs: Array = []
var _rings: Array = []
var _sparks: Array = []
var _beams: Array = []
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
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = PRIORITY
	view.material_override = mat
	view.top_level = true
	add_child(view)


func arc(from: Vector3, to: Vector3, color: Color) -> void:
	_arcs.append({"from": from, "to": to, "color": color, "life": ARC_LIFE})


func ring(at: Vector3, radius: float, color: Color) -> void:
	_rings.append({"at": at, "radius": radius, "color": color, "life": RING_LIFE})


func spark(at: Vector3, color: Color) -> void:
	_sparks.append({"at": at, "color": color, "life": SPARK_LIFE})


# A straight line that fades over `life` seconds: a lance's committed path, drawn once.
func beam(from: Vector3, to: Vector3, color: Color, life: float) -> void:
	_beams.append({"from": from, "to": to, "color": color, "life": life, "span": life})


func clear() -> void:
	_beams.clear()
	_arcs.clear()
	_rings.clear()
	_sparks.clear()
	_mesh.clear_surfaces()


func _process(delta: float) -> void:
	_mesh.clear_surfaces()
	_arcs = _age(_arcs, delta)
	_rings = _age(_rings, delta)
	_sparks = _age(_sparks, delta)
	_beams = _age(_beams, delta)
	if _arcs.is_empty() and _rings.is_empty() and _sparks.is_empty() and _beams.is_empty():
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
	_mesh.surface_end()


# The alpha each mark draws at now. Every mark scales by its colour's own alpha, so a caller
# that dims a colour (Reduce flashes, a fading trail) dims what is drawn.
static func arc_alpha(entry: Dictionary) -> float:
	return entry["color"].a * clampf(entry["life"] / ARC_LIFE, 0.0, 1.0)


static func ring_alpha(entry: Dictionary) -> float:
	return entry["color"].a * 0.7 * clampf(entry["life"] / RING_LIFE, 0.0, 1.0)


static func spark_alpha(entry: Dictionary) -> float:
	return entry["color"].a * 0.9


static func beam_alpha(entry: Dictionary) -> float:
	return entry["color"].a * clampf(entry["life"] / entry["span"], 0.0, 1.0)


# The brightest alpha any live mark draws at now.
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


# A jagged bolt of lightning, re-jittered every frame so it crackles while it lasts.
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


# A blast ring that grows to its committed radius as it fades.
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
