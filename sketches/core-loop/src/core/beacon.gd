extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const Dispatcher := preload("res://src/combat/dispatcher.gd")
const ROSTER_DIG_PATH := "res://src/combat/roster_dig.gd"


enum { IDLE, CHARGING, READY }

const MAST_HEIGHT := 18.0
const FRAME_PATH := "res://assets/models/lantern_beacon_frame.glb"
const LENS_PATH := "res://assets/models/lantern_beacon_lens.glb"
const LANTERN_BULB_RADIUS := 0.6
const DIG_DRAIN_BUDGET_USEC := 8000

static var _packed_models: Dictionary = {}
static var _slot_materials: Dictionary = {}
static var _shared_mast_cyl: CylinderMesh
static var _shared_mast_mat: StandardMaterial3D
static var _shared_lantern_bulb: SphereMesh
static var _shared_mast_bulb: SphereMesh
static var _shared_torus: TorusMesh
static var _roster_dig = null


static func _dig_roster():
	if _roster_dig == null and ResourceLoader.exists(ROSTER_DIG_PATH):
		_roster_dig = load(ROSTER_DIG_PATH)
	return _roster_dig

var phase := IDLE
var progress := 0.0
var duration := 25.0
var radius := 30.0
var sealed := true
var authored := true

var _ring_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _ring: MeshInstance3D
var _core: MeshInstance3D
var _state_views: Array[MeshInstance3D] = []
var _lens_centre := Vector3.ZERO
var _clamp_seat: Node3D
var _last_tint := Color(-1.0, -1.0, -1.0, -1.0)
var _last_f := -1.0
var _dig_drain_pending := false
var _dispatcher_warmed := false


func setup() -> void:
	_last_tint = Color(-1.0, -1.0, -1.0, -1.0)
	_last_f = -1.0
	var tint := tint_color()
	var lantern := authored and _lantern()
	if not lantern:
		var mast := MeshInstance3D.new()
		mast.mesh = _mast_mesh()
		mast.material_override = _mast_material()
		mast.position = Vector3.UP * MAST_HEIGHT * 0.5
		add_child(mast)

	_core_material = Palette.solid(tint, 0.5)
	_core = MeshInstance3D.new()
	_core.mesh = _bulb_mesh(lantern)
	_core.material_override = _core_material
	_core.position = _lens_centre if lantern else Vector3.UP * (MAST_HEIGHT + 1.5)
	add_child(_core)
	_paint_state(tint)

	_ring_material = Palette.unshaded(Color(tint, 0.55))
	_ring = MeshInstance3D.new()
	_ring.mesh = _torus_mesh()
	_ring.material_override = _ring_material
	add_child(_ring)


static func _mast_mesh() -> CylinderMesh:
	if _shared_mast_cyl == null:
		_shared_mast_cyl = CylinderMesh.new()
		_shared_mast_cyl.top_radius = 0.5
		_shared_mast_cyl.bottom_radius = 1.1
		_shared_mast_cyl.height = MAST_HEIGHT
	return _shared_mast_cyl


static func _mast_material() -> StandardMaterial3D:
	if _shared_mast_mat == null:
		_shared_mast_mat = Palette.solid(Palette.COPPER)
	return _shared_mast_mat


static func _bulb_mesh(lantern: bool) -> SphereMesh:
	if lantern:
		if _shared_lantern_bulb == null:
			_shared_lantern_bulb = SphereMesh.new()
			_shared_lantern_bulb.radius = LANTERN_BULB_RADIUS
			_shared_lantern_bulb.height = LANTERN_BULB_RADIUS * 2.0
		return _shared_lantern_bulb
	if _shared_mast_bulb == null:
		_shared_mast_bulb = SphereMesh.new()
		_shared_mast_bulb.radius = 2.0
		_shared_mast_bulb.height = 4.0
	return _shared_mast_bulb


static func _torus_mesh() -> TorusMesh:
	if _shared_torus == null:
		_shared_torus = TorusMesh.new()
		_shared_torus.inner_radius = 0.96
		_shared_torus.outer_radius = 1.0
		_shared_torus.rings = 48
	return _shared_torus


func _process(_delta: float) -> void:
	if not _dig_drain_pending:
		return
	if drain_dig_burst(DIG_DRAIN_BUDGET_USEC):
		_dig_drain_pending = false


func begin_dig_drain() -> void:
	var dig = _dig_roster()
	_dig_drain_pending = not (_dispatcher_warmed and (dig == null or dig.drain_complete()))


func drain_dig_burst(budget_usec: int = DIG_DRAIN_BUDGET_USEC) -> bool:
	var start := Time.get_ticks_usec()
	var dig = _dig_roster()
	if not _dispatcher_warmed:
		Dispatcher.warm_shared()
		_dispatcher_warmed = true
		if Time.get_ticks_usec() - start >= budget_usec:
			return dig == null or dig.drain_complete()
	if dig == null:
		return true
	var remaining := maxi(budget_usec - (Time.get_ticks_usec() - start), 500)
	var step: Dictionary = dig.tile_drain_step(remaining)
	return bool(step.get("done", dig.drain_complete()))


func _lantern() -> bool:
	var frame := _model(FRAME_PATH)
	var lens := _model(LENS_PATH)
	var socket: Node3D = frame.find_child("socket_lens", true, false) as Node3D if frame != null else null
	var seat: Node3D = frame.find_child("socket_clamp", true, false) as Node3D if frame != null else null
	if frame == null or lens == null or socket == null or seat == null:
		for node in [frame, lens]:
			if node != null:
				node.free()
		push_warning("beacon: lantern GLB, socket_lens or socket_clamp missing, the beacon builds its mast")
		return false
	_clamp_seat = seat
	frame.name = "LanternFrame"
	lens.name = "LanternLens"
	add_child(frame)
	lens.transform = _relative(socket, frame)
	add_child(lens)
	for root: Node3D in [frame, lens]:
		for view: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if view.mesh == null or view.mesh.get_surface_count() == 0:
				continue
			var source := view.mesh.surface_get_material(0)
			var slot := String(source.resource_name) if source != null else ""
			var path := String(MaterialSlots.row(slot).get("path", ""))
			if not path.is_empty():
				if not _slot_materials.has(path):
					_slot_materials[path] = load(path) if ResourceLoader.exists(path) else null
				if _slot_materials[path] != null:
					view.material_override = _slot_materials[path]
			if slot == "steel":
				_state_views.append(view)
			if root == lens:
				_lens_centre = lens.transform * _relative(view, lens) * view.mesh.get_aabb().get_center()
	for shell in RecipeProps.shells("lantern_beacon", self, Transform3D.IDENTITY):
		var view := shell as MeshInstance3D
		if view.get_surface_override_material(0) == RecipeProps.slot_material("steel"):
			_state_views.append(view)
	return true


func clamp_seat() -> Node3D:
	return _clamp_seat


static func _model(path: String) -> Node3D:
	if not _packed_models.has(path):
		_packed_models[path] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	var packed: PackedScene = _packed_models[path]
	return packed.instantiate() as Node3D if packed != null else null


static func _relative(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


func _paint_state(tint: Color) -> void:
	for view in _state_views:
		view.set_instance_shader_parameter("state_tint", tint)


func place(at: Vector3, seconds: float, ring_radius: float) -> void:
	global_position = at
	duration = seconds
	radius = ring_radius
	phase = IDLE
	progress = 0.0
	sealed = true
	_last_tint = Color(-1.0, -1.0, -1.0, -1.0)
	_last_f = -1.0
	_ring.scale = Vector3(radius, 30.0, radius)
	_ring.position = Vector3.UP * 0.6
	begin_dig_drain()
	_refresh()


func state_id() -> String:
	return "beacon_sealed" if sealed else "beacon_open"


func tint_color() -> Color:
	return EventKinds.state_color(state_id())


func in_ring(ball: Vector3) -> bool:
	return Vector2(ball.x - global_position.x, ball.z - global_position.z).length() <= radius


func fraction() -> float:
	return clampf(progress / maxf(0.01, duration), 0.0, 1.0)


func advance(delta: float, ball: Vector3, is_sealed := false) -> bool:
	if phase == READY:
		return false
	var was_sealed := sealed
	sealed = is_sealed
	if was_sealed != sealed:
		_refresh()
	if not in_ring(ball):
		return false
	phase = CHARGING
	if is_sealed:
		return false
	progress = minf(duration, progress + delta)
	_refresh()
	if progress >= duration:
		phase = READY
		return true
	return false


func show_progress(value: float) -> void:
	progress = clampf(value, 0.0, duration)
	_refresh()


func open() -> void:
	phase = READY
	sealed = false
	show_progress(duration)


func _refresh() -> void:
	if _core_material == null:
		return
	var f := fraction()
	var tint := tint_color()
	var tint_changed := tint != _last_tint
	var f_changed := not is_equal_approx(f, _last_f)
	if not tint_changed and not f_changed:
		return
	if tint_changed:
		_last_tint = tint
		_core_material.albedo_color = tint
		_core_material.emission = tint
		_paint_state(tint)
		_ring_material.albedo_color = Color(tint, 0.35 + f * 0.6)
	if f_changed:
		_last_f = f
		_core_material.emission_energy_multiplier = 0.5 + f * 6.0
		_core.scale = Vector3.ONE * (1.0 + f * 0.6)
		_ring_material.albedo_color.a = 0.35 + f * 0.6
