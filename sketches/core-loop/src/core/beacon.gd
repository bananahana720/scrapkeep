extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The stage exit. Sealed, a Warden clamps it: the charge shown is how much of the Warden
# is broken, and sitting in the ring adds nothing. Unsealed, charging starts the moment
# the ball rolls into the ring, with no key and no need to stop: circling inside charges
# it, leaving pauses it. One state and one number, so a test can step it without a clock.

enum { IDLE, CHARGING, READY }

const MAST_HEIGHT := 18.0

var phase := IDLE
var progress := 0.0
var duration := 25.0
var radius := 30.0

var _ring_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _ring: MeshInstance3D
var _core: MeshInstance3D


func setup() -> void:
	var tint := EventKinds.color("beacon_charge_changed")
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
	bulb.radius = 2.0
	bulb.height = 4.0
	_core.mesh = bulb
	_core.material_override = _core_material
	_core.position = Vector3.UP * (MAST_HEIGHT + 1.5)
	add_child(_core)

	_ring_material = Palette.unshaded(Color(tint, 0.55))
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.96
	torus.outer_radius = 1.0
	torus.rings = 96
	_ring.mesh = torus
	_ring.material_override = _ring_material
	add_child(_ring)


func place(at: Vector3, seconds: float, ring_radius: float) -> void:
	global_position = at
	duration = seconds
	radius = ring_radius
	phase = IDLE
	progress = 0.0
	_ring.scale = Vector3(radius, 30.0, radius)
	_ring.position = Vector3.UP * 0.6
	_refresh()


func in_ring(ball: Vector3) -> bool:
	return Vector2(ball.x - global_position.x, ball.z - global_position.z).length() <= radius


func fraction() -> float:
	return clampf(progress / maxf(0.01, duration), 0.0, 1.0)


# Returns true on the tick the charge completes. Sealed, ring entry still marks the
# beacon engaged but only breaking the Warden moves the charge.
func advance(delta: float, ball: Vector3, sealed := false) -> bool:
	if phase == READY:
		return false
	if not in_ring(ball):
		return false
	phase = CHARGING
	if sealed:
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
	show_progress(duration)


func _refresh() -> void:
	if _core_material == null:
		return
	var f := fraction()
	_core_material.emission_energy_multiplier = 0.5 + f * 6.0
	_core.scale = Vector3.ONE * (1.0 + f * 0.6)
	_ring_material.albedo_color.a = 0.35 + f * 0.6
