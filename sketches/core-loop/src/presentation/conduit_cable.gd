extends Node3D

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

# Command cables (design-v3/WAYFINDING.md section 3, ruling ek, unit E1-15): the Warden's gate pips drawn large on the
# ground. A park's `cable_rows` (park_schema.gd) each run from a socket at the clamp, along the row's `via` points, to a
# casting beside a crew home. One cable per pack the gate asks for, in pip order: while pip k is dark, cable k is a closed
# charcoal tube with uranium-green beads (Palette.ANCIENT, an old-works mechanism; never the live mint) running along it
# toward the clamp, so riding with the beads finds the Warden and against them finds a crew. When pip k lights, cable k
# goes quiet: severed near the clamp into two capped ends, charcoal, no bead, no motion, no light, and it is marked
# visited on the site markers. The count is read from one public call, StageLocks.pips_lit(), each frame; this node keeps
# no count of its own, so pip and cable never disagree (the camp or the 75 s clock lights every pip, and every cable dies).
#
# Shape: a tube of RADIUS and SIDES sides laid along the ground every STEP_M, both ends diving SINK_M into their casting so
# no end floats; a crew-end casting and a clamp socket in the old works' cast iron. One mesh and one material per cable:
# one draw a cable, no shadow. The beads are a shader on the tube's arc length (UV.x, metres from the crew end) and stand
# still under reduced motion. Nothing collides. Built on stage entry (retry included), dropped when the stage's content
# is cleared; no static state.

const RADIUS := 0.12
const SIDES := 8
const STEP_M := 2.0
# The tube rests on the ground, its centre this far over it.
const LIFT_M := RADIUS + 0.04
# Each end dives this far under the ground, inside its casting.
const SINK_M := 0.45
# The crew-end casting and the clamp socket (width, height, depth), set this far into the ground.
const CASTING := Vector3(1.5, 1.1, 1.5)
const SOCKET := Vector3(1.1, 0.8, 1.1)
const CAST_BURY_M := 0.3
# Clamp sockets stand in a row across the beacon, this far apart, in pip order.
const FAN_M := 2.6
# A dead cable's break: this far along from the clamp, this long.
const BREAK_FROM_CLAMP_M := 14.0
const BREAK_M := 1.8
# The beads: one every BEAD_SPACING_M, running BEAD_SPEED m/s toward the clamp.
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
# [{id, pip, view, points, dead}] in pip order, for the stage on show.
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


# The stage's cables, read-only: [{id, pip, dead, view}] in pip order.
func cables() -> Array:
	var out := []
	for c: Dictionary in _cables:
		out.append({"id": c["id"], "pip": c["pip"], "dead": c["dead"], "view": c["view"]})
	return out


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	_drop()
	_build.call_deferred()


func _on_cleared(_reason: String) -> void:
	_drop()


func _drop() -> void:
	for c: Dictionary in _cables:
		var view: MeshInstance3D = c["view"]
		if is_instance_valid(view):
			view.queue_free()
	_cables.clear()


# Builds the stage's cables from its park file (its cable_rows, the landmark's beacon and the ground), all alive.
func _build() -> void:
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


# The cable's ground line, clamp end first: the clamp socket for its pip across beacon, its via points, nothing else.
# Each point is [x, z]; heights are the ground's (cable_mesh lays the tube on it).
static func route(row: Dictionary, beacon: Vector2, count: int, _ground: Callable) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(clamp_socket(int(row["pip"]), count, beacon))
	for p in row.get("via", []):
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


# Where pip's socket stands: a row across the beacon, FAN_M apart, pip 1 on the left.
static func clamp_socket(pip: int, count: int, beacon: Vector2) -> Vector2:
	return beacon + Vector2((float(pip) - (count + 1) * 0.5) * FAN_M, 0.0)


# Swaps each cable to its state for the pips lit now: cable k (pip order) is dead once pip k is lit. Public so a
# headless test can drive it; runs each frame while cables stand.
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


# The cable's mesh along line (clamp end first, [x, z] points), laid on ground (x, z) -> height. break_at < 0 draws it
# whole and alive; otherwise it is severed break_at metres along from the clamp, BREAK_M long, both cut ends capped, and
# coloured dead. Either way both far ends dive into their casting and the clamp socket and the casting are drawn.
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


# The tube's centre line: line resampled every STEP_M and set LIFT_M over the ground, each end extended down SINK_M
# under the ground at its anchor.
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


# The part of path from from_m to to_m metres along it (clamp end first).
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


# A closed tube along path: SIDES-sided rings framed by parallel transport (no twist on a cliff), capped at both ends.
# UV.x is metres from the crew end (total - arc length from the clamp, from_m being where path starts); UV.y the way
# round, 0.25 on top. Caps carry UV.y -1 (no bead).
static func _tube(st: SurfaceTool, path: PackedVector3Array, total: float, from_m: float, color: Color) -> void:
	if path.size() < 2:
		return
	var rings := []
	var run := from_m
	var tangent := (path[1] - path[0]).normalized()
	# The first frame's normal is level and square to the first level run, so its binormal is up wherever the tube
	# first runs level, even when it starts on the dive out of its socket.
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
			# The first frame's binormal is up, so side SIDES/4 (UV.y 0.25) is the top while the tube runs level.
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


# The flat way a cable leaves its anchor, for turning the casting square to it.
static func _toward(line: PackedVector2Array, clamp_end: bool) -> Vector2:
	var a := line[0] if clamp_end else line[line.size() - 1]
	var b := line[mini(1, line.size() - 1)] if clamp_end else line[maxi(line.size() - 2, 0)]
	var d := b - a
	return d.normalized() if d.length() > 0.01 else Vector2(0.0, 1.0)


# A squared old-works casting at foot (on the ground), size (w, h, d), its face turned along dir: a body set CAST_BURY_M
# into the ground, a stepped cap, all closed boxes. UV.y -1: no bead.
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
