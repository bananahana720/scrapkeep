extends Node3D

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")


const RADIUS := 0.12
const SIDES := 8
const STEP_M := 2.0
const LIFT_M := RADIUS + 0.04
const SINK_M := 0.45
const CASTING := Vector3(1.5, 1.1, 1.5)
const SOCKET := Vector3(1.1, 0.8, 1.1)
const CAST_BURY_M := 0.3
const FAN_M := 2.6
const BREAK_FROM_CLAMP_M := 14.0
const BREAK_M := 1.8
const BEAD_SPACING_M := 5.0
const BEAD_SPEED := 3.5
const BEAD_GLOW := 2.6
const CAST_COLOR := Color("3b4643")

const SHADER := """
shader_type spatial;
render_mode cull_back, shadows_disabled;
uniform vec3 bead : source_color;
uniform float speed = 3.5;
uniform float spacing = 5.0;
uniform float glow = 2.6;
void fragment() {
	// UV.x: metres from the crew end, growing toward the clamp; UV.y: the way round the tube, 0.25 on top; a casting
	// carries UV.y below 0 and never beads. Vertex colours are sRGB (Palette's), so they are made linear here.
	float phase = fract((UV.x - TIME * speed) / spacing);
	float dot_along = 1.0 - smoothstep(0.16, 0.3, abs(phase - 0.5) * spacing);
	float dot_round = 1.0 - smoothstep(0.1, 0.2, abs(UV.y - 0.25));
	float on = step(0.0, UV.y) * dot_along * dot_round;
	ALBEDO = mix(pow(COLOR.rgb, vec3(2.2)), bead, on * 0.6);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	EMISSION = bead * on * glow;
}
"""

var ctx
var _markers
var _cables: Array = []
var _live: ShaderMaterial
var _dead: StandardMaterial3D
var _still := false


func setup(ctx_ref, markers = null) -> void:
	ctx = ctx_ref
	_markers = markers
	name = "ConduitCable"
	_live = ShaderMaterial.new()
	_live.shader = Shader.new()
	_live.shader.code = SHADER
	_live.set_shader_parameter("bead", Palette.ANCIENT)
	_live.set_shader_parameter("spacing", BEAD_SPACING_M)
	_live.set_shader_parameter("glow", BEAD_GLOW)
	_dead = StandardMaterial3D.new()
	_dead.vertex_color_use_as_albedo = true
	_dead.vertex_color_is_srgb = true
	_dead.roughness = 0.85
	_still = not UiTokens.reduced_motion
	_hold_still(UiTokens.reduced_motion)
	var events = ctx.get("events") if ctx != null else null
	if events != null:
		events.stage_entered.connect(_on_stage_entered)
		events.stage_content_cleared.connect(_on_cleared)


func cables() -> Array:
	var out := []
	for c: Dictionary in _cables:
		out.append({"id": c["id"], "pip": c["pip"], "dead": c["dead"], "view": c["view"]})
	return out


var _gen := 0


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	_drop()
	_build.call_deferred(_gen)


func _on_cleared(_reason: String) -> void:
	_drop()


func _drop() -> void:
	_gen += 1
	for c: Dictionary in _cables:
		var view: MeshInstance3D = c["view"]
		if is_instance_valid(view):
			view.queue_free()
	_cables.clear()


func _build(gen: int = -1) -> void:
	if gen >= 0 and gen != _gen:
		return
	_drop()
	var terrain = ctx.get("terrain") if ctx != null else null
	var map = terrain.map() if terrain != null and terrain.has_method("map") else null
	if map == null or not "park" in map or not map.park is Dictionary:
		return
	var rows: Array = map.park.get("cable_rows", [])
	if rows.is_empty():
		return
	var ground := func(x: float, z: float) -> float: return float(terrain.height(x, z))
	var ordered := rows.duplicate()
	ordered.sort_custom(func(a, b): return int(a["pip"]) < int(b["pip"]))
	for row: Dictionary in ordered:
		var points := route(row, map.beacon, ordered.size(), ground)
		var view := MeshInstance3D.new()
		view.name = "Cable_" + String(row["id"])
		view.top_level = true
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.mesh = cable_mesh(points, ground, -1.0)
		view.material_override = _live
		add_child(view)
		view.global_transform = Transform3D.IDENTITY
		_cables.append({"id": String(row["id"]), "pip": int(row["pip"]), "view": view, "points": points, "dead": false})
	refresh()


static func route(row: Dictionary, beacon: Vector2, count: int, _ground: Callable) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(clamp_socket(int(row["pip"]), count, beacon))
	for p in row.get("via", []):
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


static func clamp_socket(pip: int, count: int, beacon: Vector2) -> Vector2:
	return beacon + Vector2((float(pip) - (count + 1) * 0.5) * FAN_M, 0.0)


func refresh() -> void:
	var lit := _pips_lit()
	var terrain = ctx.get("terrain") if ctx != null else null
	for c: Dictionary in _cables:
		var dead: bool = int(c["pip"]) <= lit
		if dead == bool(c["dead"]):
			continue
		c["dead"] = dead
		var view: MeshInstance3D = c["view"]
		if dead:
			var ground := func(x: float, z: float) -> float: return float(terrain.height(x, z))
			view.mesh = cable_mesh(c["points"], ground, BREAK_FROM_CLAMP_M)
			view.material_override = _dead
			var points: PackedVector2Array = c["points"]
			var home := points[points.size() - 1]
			if _markers != null and _markers.has_method("mark_visited"):
				_markers.mark_visited("cable:" + String(c["id"]), "cable", Vector3(home.x, float(ground.call(home.x, home.y)), home.y))
		else:
			var ground := func(x: float, z: float) -> float: return float(terrain.height(x, z))
			view.mesh = cable_mesh(c["points"], ground, -1.0)
			view.material_override = _live


func _pips_lit() -> int:
	var flow = ctx.get("flow") if ctx != null else null
	var gate = flow.get("gate") if flow != null else null
	return int(gate.pips_lit()) if gate != null and gate.has_method("pips_lit") else 0


func _hold_still(still: bool) -> void:
	if still == _still:
		return
	_still = still
	_live.set_shader_parameter("speed", 0.0 if still else BEAD_SPEED)


func _process(_delta: float) -> void:
	_hold_still(UiTokens.reduced_motion)
	if not _cables.is_empty():
		refresh()


static func cable_mesh(line: PackedVector2Array, ground: Callable, break_at := -1.0) -> ArrayMesh:
	var path := lay(line, ground)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var dead := break_at >= 0.0
	var jacket := Palette.CHARCOAL.lightened(0.04) if dead else Palette.CHARCOAL
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if dead:
		var cut := clampf(break_at, 2.0, maxf(2.0, total - BREAK_M - 2.0))
		_tube(st, _slice(path, 0.0, cut), total, 0.0, jacket)
		_tube(st, _slice(path, cut + BREAK_M, total), total, cut + BREAK_M, jacket)
	else:
		_tube(st, path, total, 0.0, jacket)
	var a := line[0]
	var b := line[line.size() - 1]
	_casting(st, Vector3(a.x, float(ground.call(a.x, a.y)), a.y), SOCKET, _toward(line, true))
	_casting(st, Vector3(b.x, float(ground.call(b.x, b.y)), b.y), CASTING, _toward(line, false))
	st.generate_normals()
	return st.commit()


static func lay(line: PackedVector2Array, ground: Callable) -> PackedVector3Array:
	var flat := PackedVector2Array()
	for i in range(line.size()):
		if i == 0:
			flat.append(line[0])
			continue
		var a := line[i - 1]
		var b := line[i]
		var n := maxi(1, ceili(a.distance_to(b) / STEP_M))
		for k in range(1, n + 1):
			flat.append(a.lerp(b, float(k) / n))
	var out := PackedVector3Array()
	var first := flat[0]
	out.append(Vector3(first.x, float(ground.call(first.x, first.y)) - SINK_M, first.y))
	for p in flat:
		out.append(Vector3(p.x, float(ground.call(p.x, p.y)) + LIFT_M, p.y))
	var last := flat[flat.size() - 1]
	out.append(Vector3(last.x, float(ground.call(last.x, last.y)) - SINK_M, last.y))
	return out


static func _slice(path: PackedVector3Array, from_m: float, to_m: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var run := 0.0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var len_ab := a.distance_to(b)
		if len_ab <= 0.0:
			continue
		var s0 := run
		var s1 := run + len_ab
		if s1 >= from_m and s0 <= to_m:
			if out.is_empty():
				out.append(a.lerp(b, clampf((from_m - s0) / len_ab, 0.0, 1.0)))
			if s1 <= to_m:
				out.append(b)
			else:
				out.append(a.lerp(b, (to_m - s0) / len_ab))
				break
		run = s1
	return out


static func _tube(st: SurfaceTool, path: PackedVector3Array, total: float, from_m: float, color: Color) -> void:
	if path.size() < 2:
		return
	var rings := []
	var run := from_m
	var tangent := (path[1] - path[0]).normalized()
	var level := Vector3.ZERO
	for i in range(1, path.size()):
		var d := path[i] - path[i - 1]
		d.y = 0.0
		if d.length() > 0.01:
			level = d.normalized()
			break
	var normal := Vector3.UP.cross(level) if level != Vector3.ZERO else Vector3.RIGHT.cross(tangent)
	normal = (normal - tangent * normal.dot(tangent)).normalized()
	for i in path.size():
		if i > 0:
			run += path[i - 1].distance_to(path[i])
		var next := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		if next.length() > 0.5:
			var axis := tangent.cross(next)
			if axis.length() > 1e-5:
				normal = normal.rotated(axis.normalized(), tangent.angle_to(next))
			tangent = next
		normal = (normal - tangent * normal.dot(tangent)).normalized()
		var binormal := tangent.cross(normal).normalized()
		var ring := []
		for k in SIDES + 1:
			var a := TAU * float(k) / SIDES
			var out_dir := normal * cos(a) + binormal * sin(a)
			ring.append([path[i] + out_dir * RADIUS, Vector2(total - run, float(k) / SIDES)])
		rings.append(ring)
	st.set_color(color)
	for i in range(rings.size() - 1):
		for k in SIDES:
			var a: Array = rings[i][k]
			var b: Array = rings[i][k + 1]
			var c: Array = rings[i + 1][k + 1]
			var d: Array = rings[i + 1][k]
			for v: Array in [a, d, c, a, c, b]:
				st.set_uv(v[1])
				st.add_vertex(v[0])
	for end in [0, rings.size() - 1]:
		var centre: Vector3 = path[end]
		for k in SIDES:
			var p0: Vector3 = rings[end][k][0]
			var p1: Vector3 = rings[end][k + 1][0]
			var tri := [centre, p1, p0] if end == 0 else [centre, p0, p1]
			for v: Vector3 in tri:
				st.set_uv(Vector2(0.0, -1.0))
				st.add_vertex(v)


static func _toward(line: PackedVector2Array, clamp_end: bool) -> Vector2:
	var a := line[0] if clamp_end else line[line.size() - 1]
	var b := line[mini(1, line.size() - 1)] if clamp_end else line[maxi(line.size() - 2, 0)]
	var d := b - a
	return d.normalized() if d.length() > 0.01 else Vector2(0.0, 1.0)


static func _casting(st: SurfaceTool, foot: Vector3, size: Vector3, dir: Vector2) -> void:
	var yaw := atan2(dir.x, dir.y)
	var basis := Basis(Vector3.UP, yaw)
	var body_y := foot.y - CAST_BURY_M + (size.y + CAST_BURY_M) * 0.5
	_box(st, foot + Vector3(0.0, body_y - foot.y, 0.0), Vector3(size.x, size.y + CAST_BURY_M, size.z), basis, CAST_COLOR)
	_box(st, foot + Vector3(0.0, size.y + 0.08, 0.0), Vector3(size.x * 0.8, 0.16, size.z * 0.8), basis, CAST_COLOR.darkened(0.25))


static func _box(st: SurfaceTool, centre: Vector3, size: Vector3, basis: Basis, color: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	st.set_color(color)
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var corners := []
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			corners.append(centre + basis * ((n + u * s.x + v * s.y) * h))
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_uv(Vector2(0.0, -1.0))
			st.add_vertex(corners[idx])
