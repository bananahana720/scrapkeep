extends Node3D

const BossPlate := preload("res://src/ui/boss_plate.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const WardenBody := preload("res://src/combat/warden.gd")


const ARCS := BossPosture.CHUNKS
const GAP_DEGREES := 20.0
const START_DEGREES := 0.0
const CLEARANCE := 0.6
const BAND := 1.0
const BACKING := 0.5
const LIFT := 0.12
const STEPS := 14
const CRACK_REACH := 0.55
const CRACK_SWING := 0.45
const CRACK_BACKING := 0.5
const CRACK_MARK := 0.2
const OUTLINE := 0.2
const CRACK_AT := [0.08, 0.5, 0.92]
const PRIORITY := -3
const REBUILD_FRAMES := 6
const REBUILD_M := 0.5
const FIRST_FIT_FRAMES := 2

var _warden: Node3D
var _arc_meshes: Array[MeshInstance3D] = []
var _edge_meshes: Array[MeshInstance3D] = []
var _backing_meshes: Array[MeshInstance3D] = []
var _backing_material: StandardMaterial3D
var _arc_materials: Array[StandardMaterial3D] = []
var _crack_back: MeshInstance3D
var _crack_mark: MeshInstance3D
var _back_material: StandardMaterial3D
var _mark_material: StandardMaterial3D
var _built_at := Vector3.INF
var _crack_index := -1
var _points := {}
var _since_build := 0
var _fit_wait := 0


func bind(warden: Node3D) -> void:
	_warden = warden
	name = "WardenRing"
	top_level = true
	_backing_material = _material()
	_backing_material.render_priority = PRIORITY - 1
	for i in ARCS:
		var backing := MeshInstance3D.new()
		backing.name = "Backing%d" % i
		backing.material_override = _backing_material
		add_child(backing)
		_backing_meshes.append(backing)
		var mesh := MeshInstance3D.new()
		mesh.name = "Arc%d" % i
		var material := _material()
		mesh.material_override = material
		add_child(mesh)
		_arc_meshes.append(mesh)
		_arc_materials.append(material)
		var edge := MeshInstance3D.new()
		edge.name = "Edge%d" % i
		edge.material_override = material
		add_child(edge)
		_edge_meshes.append(edge)
	_back_material = _material()
	_back_material.render_priority = PRIORITY + 1
	_mark_material = _material()
	_crack_back = MeshInstance3D.new()
	_crack_back.name = "CrackBacking"
	_crack_back.material_override = _back_material
	add_child(_crack_back)
	_crack_mark = MeshInstance3D.new()
	_crack_mark.name = "CrackMark"
	_crack_mark.material_override = _mark_material
	_mark_material.render_priority = PRIORITY + 2
	add_child(_crack_mark)
	for mark: MeshInstance3D in find_children("*", "MeshInstance3D", false, false):
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fit_wait = FIRST_FIT_FRAMES
	visible = false


func active() -> bool:
	return is_instance_valid(_warden) and _warden.has_method("fight") and _warden.fight() == "posture" and not _warden.is_dead()


func lit(i: int) -> bool:
	return active() and i < _warden.chunks_left()


func lit_count() -> int:
	var count := 0
	for i in ARCS:
		if lit(i):
			count += 1
	return count


func cracked_arc() -> int:
	if active() and _warden.chunk_cracked() and _warden.chunks_left() > 0:
		return _warden.chunks_left() - 1
	return -1


func open_now() -> bool:
	return active() and _warden.staggered()


func arc_color(i: int) -> Color:
	if lit(i):
		return BossPlate.bar_color_for(open_now()) if open_now() else BossPlate.pip_color(true)
	return BossPlate.pip_color(false)


func crack_color() -> Color:
	return BossPlate.crack_color_for(open_now())


func crack_backing() -> Color:
	return BossPlate.crack_backing()


func shown_arc_color(i: int) -> Color:
	return _arc_materials[i].albedo_color


func shown_crack_color() -> Color:
	return _mark_material.albedo_color


func shown_backing_color() -> Color:
	return _back_material.albedo_color


func crack_visible() -> bool:
	return _crack_mark.visible and _crack_back.visible


func _process(_delta: float) -> void:
	if _fit_wait > 0:
		_fit_wait -= 1
		return
	_sync()


func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = PRIORITY
	return material


func _sync() -> void:
	if not is_instance_valid(_warden):
		return
	visible = active()
	if not visible:
		return
	var foot := _centre()
	_since_build += 1
	if _built_at.distance_to(foot) > REBUILD_M or (_since_build >= REBUILD_FRAMES and _built_at.distance_to(foot) > 0.05):
		_build(foot)
	elif global_position != foot:
		global_position = foot
	_backing_material.albedo_color = crack_backing()
	for i in ARCS:
		_arc_materials[i].albedo_color = arc_color(i)
		_arc_meshes[i].visible = lit(i)
		_edge_meshes[i].visible = not lit(i)
	var cracked := cracked_arc()
	if cracked != _crack_index:
		_crack_index = cracked
		_build_crack()
	_crack_back.visible = cracked >= 0
	_crack_mark.visible = cracked >= 0
	_back_material.albedo_color = crack_backing()
	_mark_material.albedo_color = crack_color()


func _centre() -> Vector3:
	var at: Vector3 = _warden.global_position
	if _warden.get("boss") != null and _warden.get_parent() is Node3D:
		at = (_warden.get_parent() as Node3D).global_position
	return Vector3(at.x, 0.0, at.z)


func _radius() -> float:
	return _reach() + CLEARANCE + BACKING * 0.5 + BAND * 0.5


func _reach() -> float:
	if _warden.get("boss") == null:
		return float(WardenBody.CORE_RADIUS)
	for child in _warden.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var size: Vector3 = child.shape.size
			return Vector2(size.x, size.z).length() * 0.5
	return float(_warden.get("radius"))


func _ground(x: float, z: float) -> float:
	var boss = _warden.get("boss")
	if boss != null and boss.has_method("ground_height_at"):
		return boss.ground_height_at(Vector3(x, 0.0, z))
	var terrain = _warden.get("terrain")
	if terrain == null:
		return _warden.global_position.y - _warden.HALF_HEIGHT
	if terrain.has_method("height_at"):
		return terrain.height_at(Vector3(x, 0.0, z))
	return terrain.height(x, z)


func _point(foot: Vector3, angle: float, radius: float) -> Vector3:
	var key := Vector2(angle, radius)
	if _points.has(key):
		return _points[key]
	var x := foot.x + cos(angle) * radius
	var z := foot.z + sin(angle) * radius
	var point := Vector3(x - foot.x, _ground(x, z) + LIFT, z - foot.z)
	_points[key] = point
	return point


func _span(i: int) -> Vector2:
	var quarter := TAU / ARCS
	var gap := deg_to_rad(GAP_DEGREES) * 0.5
	var from := deg_to_rad(START_DEGREES) + quarter * i
	return Vector2(from + gap, from + quarter - gap)


func _build(foot: Vector3) -> void:
	_built_at = foot
	_since_build = 0
	_points.clear()
	global_position = foot
	var mid := _radius()
	for i in ARCS:
		var span := _span(i)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for s in STEPS:
			var a0: float = lerpf(span.x, span.y, float(s) / STEPS)
			var a1: float = lerpf(span.x, span.y, float(s + 1) / STEPS)
			var p0 := _point(foot, a0, mid - BAND * 0.5)
			var p1 := _point(foot, a0, mid + BAND * 0.5)
			var q0 := _point(foot, a1, mid - BAND * 0.5)
			var q1 := _point(foot, a1, mid + BAND * 0.5)
			for v in [p0, p1, q1, p0, q1, q0]:
				tool.add_vertex(v)
		_arc_meshes[i].mesh = tool.commit()
		_backing_meshes[i].mesh = _backing(foot, span, mid)
		_edge_meshes[i].mesh = _edge(foot, span, mid)
	_crack_index = -2


func _backing(foot: Vector3, span: Vector2, mid: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pad := BACKING * 0.5
	var turn := pad / mid
	var from := span.x - turn
	var to := span.y + turn
	for s in STEPS:
		var a0: float = lerpf(from, to, float(s) / STEPS)
		var a1: float = lerpf(from, to, float(s + 1) / STEPS)
		var p0 := _point(foot, a0, mid - BAND * 0.5 - pad)
		var p1 := _point(foot, a0, mid + BAND * 0.5 + pad)
		var q0 := _point(foot, a1, mid - BAND * 0.5 - pad)
		var q1 := _point(foot, a1, mid + BAND * 0.5 + pad)
		for v in [p0, p1, q1, p0, q1, q0]:
			tool.add_vertex(v)
	return tool.commit()


func _edge(foot: Vector3, span: Vector2, mid: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := BAND * 0.5
	for side in [-1.0, 1.0]:
		var inner: float = mid + side * half
		var lo: float = inner - OUTLINE * 0.5
		var hi: float = inner + OUTLINE * 0.5
		for s in STEPS * 2:
			var a0: float = lerpf(span.x, span.y, float(s) / (STEPS * 2))
			var a1: float = lerpf(span.x, span.y, float(s + 1) / (STEPS * 2))
			for v in [_point(foot, a0, lo), _point(foot, a0, hi), _point(foot, a1, hi), _point(foot, a0, lo), _point(foot, a1, hi), _point(foot, a1, lo)]:
				tool.add_vertex(v)
	for angle in [span.x, span.y]:
		var o := OUTLINE * 0.5 / mid
		var a0: float = angle - o
		var a1: float = angle + o
		for v in [_point(foot, a0, mid - half), _point(foot, a0, mid + half), _point(foot, a1, mid + half), _point(foot, a0, mid - half), _point(foot, a1, mid + half), _point(foot, a1, mid - half)]:
			tool.add_vertex(v)
	return tool.commit()


func _build_crack() -> void:
	if _crack_index < 0:
		return
	var foot := _built_at
	var span := _span(_crack_index)
	var mid := _radius()
	var step := 1.0 / mid
	var lines: Array = []
	for at in CRACK_AT:
		var centre: float = lerpf(span.x, span.y, at)
		var pts: Array[Vector3] = []
		var marks := [[-CRACK_REACH, -CRACK_SWING], [-CRACK_REACH * 0.3, CRACK_SWING * 0.6], [CRACK_REACH * 0.3, -CRACK_SWING * 0.6], [CRACK_REACH, CRACK_SWING]]
		for mark in marks:
			pts.append(_point(foot, centre + mark[1] * step, mid + mark[0]))
		lines.append(pts)
	_crack_back.mesh = _strips(lines, CRACK_BACKING, 0.0)
	_crack_mark.mesh = _strips(lines, CRACK_MARK, 0.04)


func _strips(lines: Array, width: float, lift: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pts in lines:
		for i in pts.size() - 1:
			var a: Vector3 = pts[i] + Vector3.UP * lift
			var b: Vector3 = pts[i + 1] + Vector3.UP * lift
			var along := b - a
			var side := Vector3(-along.z, 0.0, along.x).normalized() * width * 0.5
			for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
				tool.add_vertex(v)
	return tool.commit()
