extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")

# The stage exit. Sealed, a Warden clamps it: the charge shown is how much of the Warden
# is broken, and sitting in the ring adds nothing. Unsealed, charging starts the moment
# the ball rolls into the ring, with no key and no need to stop: circling inside charges
# it, leaving pauses it. One state and one number, so a test can step it without a clock.

enum { IDLE, CHARGING, READY }

const MAST_HEIGHT := 18.0
# The authored lantern beacon (tools/blender/lantern_beacon.py): the frame carries steel and enamel,
# the lens carries glass at the frame's socket_lens. The ring and cap are the steel shader's state key,
# so each frame wears the beacon's state through its state_tint. The frame's socket_clamp is the Warden's
# seat, which the recipe keeps clear of every family's weak point. Without the GLBs or either socket the
# beacon builds the copper mast and bulb.
const FRAME_PATH := "res://assets/models/lantern_beacon_frame.glb"
const LENS_PATH := "res://assets/models/lantern_beacon_lens.glb"
# Inside the 1.08 m glass even at full charge (scale 1.6).
const LANTERN_BULB_RADIUS := 0.6

var phase := IDLE
var progress := 0.0
var duration := 25.0
var radius := 30.0
# Sealed until the beacon opens: a Warden clamps it. The ring, the bulb and the edge marker
# read this one fact through state_id(), so none of them wears the live colour.
var sealed := true

var _ring_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _ring: MeshInstance3D
var _core: MeshInstance3D
var _state_views: Array[MeshInstance3D] = []
var _lens_centre := Vector3.ZERO
var _clamp_seat: Node3D


func setup() -> void:
	var tint := tint_color()
	var lantern := _lantern()
	if not lantern:
		var mast := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 1.1
		cyl.height = MAST_HEIGHT
		mast.mesh = cyl
		mast.material_override = Palette.solid(Palette.COPPER)
		mast.position = Vector3.UP * MAST_HEIGHT * 0.5
		add_child(mast)

	_core_material = Palette.solid(tint, 0.5)
	_core = MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = LANTERN_BULB_RADIUS if lantern else 2.0
	bulb.height = bulb.radius * 2.0
	_core.mesh = bulb
	_core.material_override = _core_material
	_core.position = _lens_centre if lantern else Vector3.UP * (MAST_HEIGHT + 1.5)
	add_child(_core)
	_paint_state(tint)

	_ring_material = Palette.unshaded(Color(tint, 0.55))
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.96
	torus.outer_radius = 1.0
	torus.rings = 96
	_ring.mesh = torus
	_ring.material_override = _ring_material
	add_child(_ring)


# The frame and its lens from the authored GLBs, each surface in its material slot; false when
# either GLB, the lens socket or the clamp seat is missing, and nothing is added.
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
			if not path.is_empty() and ResourceLoader.exists(path):
				view.material_override = load(path)
			if slot == "steel":
				_state_views.append(view)
			if root == lens:
				_lens_centre = lens.transform * _relative(view, lens) * view.mesh.get_aabb().get_center()
	return true


# The Warden's seat on the lantern frame (socket_clamp); null on the copper mast.
func clamp_seat() -> Node3D:
	return _clamp_seat


static func _model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed != null else null


static func _relative(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


# The frame's ring and cap are the steel state key; each one wears the beacon's state row.
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
	_ring.scale = Vector3(radius, 30.0, radius)
	_ring.position = Vector3.UP * 0.6
	_refresh()


# The beacon's state row in EventKinds: sealed is "not yet", open is "the world is offering".
func state_id() -> String:
	return "beacon_sealed" if sealed else "beacon_open"


func tint_color() -> Color:
	return EventKinds.state_color(state_id())


func in_ring(ball: Vector3) -> bool:
	return Vector2(ball.x - global_position.x, ball.z - global_position.z).length() <= radius


func fraction() -> float:
	return clampf(progress / maxf(0.01, duration), 0.0, 1.0)


# Returns true on the tick the charge completes. Sealed, ring entry still marks the
# beacon engaged but only breaking the Warden moves the charge.
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


# Sealed charge follows the Warden's damage, set by flow every tick.
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
	_core_material.albedo_color = tint
	_core_material.emission = tint
	_paint_state(tint)
	_ring_material.albedo_color = Color(tint, _ring_material.albedo_color.a)
	_core_material.emission_energy_multiplier = 0.5 + f * 6.0
	_core.scale = Vector3.ONE * (1.0 + f * 0.6)
	_ring_material.albedo_color.a = 0.35 + f * 0.6
