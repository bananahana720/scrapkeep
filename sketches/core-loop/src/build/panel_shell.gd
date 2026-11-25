extends Node3D

const Panels := preload("res://src/build/panels.gd")
const Accretion := preload("res://src/build/accretion.gd")


const SOCKETS := 32
const DRAW_BUDGET := 128
const COURSE_RADIUS := [1.03, 1.11]
const PLATE_COURSE_FROM := 1.19
const PLATE_COURSE_STEP := 0.07
const PLATE_HEIGHT := 0.3
const MAX_OVERHANG := 0.6
const PLATE_FACE := 1.5
const PLATE_GLB := "res://assets/models/item_panels/panel_%s.glb"
const PATINA := 0.14
const POP_SCALE := 1.8
const POP_RATE := 12.0

var _seed := 0
var _shown: Array = []
var _order: Array = []
var _twist: Array = []
var _multimeshes := {}
var _pop := {}
static var _meshes := {}
static var _sockets: Array[Vector3] = []


func _init() -> void:
	name = "PanelShell"


static func sockets() -> Array[Vector3]:
	if _sockets.is_empty():
		for hub in Accretion.lattice_layout()["hubs"]:
			_sockets.append(hub)
	return _sockets


static func course_radius(course: int) -> float:
	if course < COURSE_RADIUS.size():
		return COURSE_RADIUS[course]
	return PLATE_COURSE_FROM + PLATE_COURSE_STEP * (course - COURSE_RADIUS.size())


static func drawn_count(held: int) -> int:
	var cap := 0
	while cap < DRAW_BUDGET and course_radius(cap / SOCKETS) + PLATE_HEIGHT <= 1.0 + MAX_OVERHANG:
		cap += 1
	return mini(held, cap)


static func extent(held: int) -> float:
	var n := drawn_count(held)
	if n == 0:
		return 0.0
	return course_radius((n - 1) / SOCKETS) + PLATE_HEIGHT


func show_panels(held: Array, run_seed: int) -> void:
	if run_seed != _seed or _order.is_empty():
		_reseed(run_seed)
	var list := Array(held).duplicate()
	if list == _shown:
		return
	var grew: bool = list.size() == _shown.size() + 1 and list.slice(0, _shown.size()) == _shown
	_shown = list
	var by_silhouette := {}
	var n := drawn_count(held.size())
	for i in n:
		var id: String = held[i]
		var silhouette: String = Panels.ROWS[id]["silhouette"] if Panels.ROWS.has(id) else "tile"
		by_silhouette.get_or_add(silhouette, []).append(i)
	for silhouette in _multimeshes.keys():
		if not by_silhouette.has(silhouette):
			(_multimeshes[silhouette] as MultiMeshInstance3D).multimesh.instance_count = 0
	for silhouette in by_silhouette:
		var view := _view(silhouette)
		var indices: Array = by_silhouette[silhouette]
		view.multimesh.instance_count = indices.size()
		for k in indices.size():
			view.multimesh.set_instance_transform(k, seat(indices[k]))
			view.multimesh.set_instance_color(k, _patina(indices[k]))
	_pop.clear()
	if grew and n == held.size():
		var silhouette: String = Panels.ROWS[held.back()]["silhouette"]
		_pop = {"silhouette": silhouette, "k": (by_silhouette[silhouette] as Array).size() - 1, "index": n - 1, "scale": POP_SCALE}


func shown_count() -> int:
	var total := 0
	for silhouette in _multimeshes:
		total += (_multimeshes[silhouette] as MultiMeshInstance3D).multimesh.instance_count
	return total


func draw_calls() -> int:
	var calls := 0
	for silhouette in _multimeshes:
		if (_multimeshes[silhouette] as MultiMeshInstance3D).multimesh.instance_count > 0:
			calls += 1
	return calls


func seat(index: int, scale_by := 1.0) -> Transform3D:
	var course := index / SOCKETS
	var slot: int = _order[index % SOCKETS]
	var dir: Vector3 = (_twist[course % _twist.size()] as Basis) * sockets()[slot] if course > 0 else sockets()[slot]
	var basis := _facing(dir) * Basis(Vector3.UP, float(slot) * 0.7)
	return Transform3D(basis * Basis.from_scale(Vector3(PLATE_FACE * scale_by, 1.0, PLATE_FACE * scale_by)), dir * course_radius(course))


func centroid(panel_id: String) -> Vector3:
	var sum := Vector3.ZERO
	for i in drawn_count(_shown.size()):
		if _shown[i] == panel_id:
			sum += seat(i).origin
	return sum.normalized() if sum.length() > 0.001 else Vector3.ZERO


func _reseed(run_seed: int) -> void:
	_seed = run_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "panel_shell"])
	var socket_dirs := sockets()
	_order = [rng.randi_range(0, SOCKETS - 1)]
	var near := []
	for s in SOCKETS:
		near.append(socket_dirs[s].distance_to(socket_dirs[_order[0]]))
	while _order.size() < SOCKETS:
		var best := -1
		var best_gap := -1.0
		for s in SOCKETS:
			if s in _order:
				continue
			var gap: float = near[s] + rng.randf() * 0.001
			if gap > best_gap:
				best_gap = gap
				best = s
		_order.append(best)
		for s in SOCKETS:
			near[s] = minf(near[s], socket_dirs[s].distance_to(socket_dirs[best]))
	_twist.clear()
	for c in 8:
		var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		_twist.append(Basis(axis.normalized() if axis.length() > 0.01 else Vector3.UP, rng.randf_range(0.18, 0.32)))
	_shown = []


func _patina(index: int) -> Color:
	var v := float(hash([_seed, index, "patina"]) % 1000) / 999.0
	var shade := clampf(1.0 - PATINA + v * PATINA, 0.0, 1.0)
	return Color(shade, shade, shade)


func _view(silhouette: String) -> MultiMeshInstance3D:
	if _multimeshes.has(silhouette):
		return _multimeshes[silhouette]
	var view := MultiMeshInstance3D.new()
	view.name = "Panels_" + silhouette
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = plate_mesh(silhouette)
	view.multimesh = mm
	add_child(view)
	_multimeshes[silhouette] = view
	return view


static func _facing(dir: Vector3) -> Basis:
	var up := dir.normalized()
	var side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	side = (side - up * side.dot(up)).normalized()
	return Basis(side, up, side.cross(up))


static func plate_mesh(silhouette: String) -> Mesh:
	if _meshes.has(silhouette):
		return _meshes[silhouette]
	var path := PLATE_GLB % silhouette
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed == null:
		push_error("panel_shell: kit plate %s does not load" % path)
		return null
	var scene := packed.instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	var mesh: ArrayMesh = (found[0] as MeshInstance3D).mesh.duplicate() if found.size() == 1 else null
	scene.free()
	if mesh == null:
		push_error("panel_shell: %s holds %d meshes, want one" % [path, found.size()])
		return null
	for surface in mesh.get_surface_count():
		var hardware := String(mesh.surface_get_material(surface).resource_name) == "panel_hardware"
		mesh.surface_set_material(surface, _plate_material(0.7 if hardware else 0.0, 0.42 if hardware else 0.72))
	_meshes[silhouette] = mesh
	return mesh


static func _plate_material(metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _process(delta: float) -> void:
	if _pop.is_empty():
		return
	_pop["scale"] = lerpf(float(_pop["scale"]), 1.0, minf(1.0, POP_RATE * delta))
	var view: MultiMeshInstance3D = _multimeshes.get(_pop["silhouette"])
	if view == null or int(_pop["k"]) >= view.multimesh.instance_count:
		_pop.clear()
		return
	view.multimesh.set_instance_transform(int(_pop["k"]), seat(int(_pop["index"]), float(_pop["scale"])))
	if float(_pop["scale"]) < 1.001:
		_pop.clear()
