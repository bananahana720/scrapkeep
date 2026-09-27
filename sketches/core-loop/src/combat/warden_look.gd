extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The Warden's body as a landmark, visual only: nothing here collides, and every
# number the fight uses stays in warden.gd. It has to answer "what do I break?" from
# the 14 m entry drop, 150 m out, so it is a Furnace Fleet clamp about 7 m tall and
# 8 m across, wrapped round the beacon mast's base.
#
# - Four heavy jaw plates carry the plating tint, large and lit: amber means your
#   punch breaks through, slate means not yet (enemy.gd _paint_plate).
# - A glowing core sits in the clamp's mouth, visible through the gaps. It brightens
#   as the pulse charges and flickers while the magnet has the plating off.
# - Above it floats one badge, turned to face the camera: an integrity ring that
#   fills with the beacon charge (the share of the Warden broken), and inside it the
#   objective's diamond. Both wear beacon_charge_changed's colour from event_kinds,
#   the row the objective line reads once the fight starts, so the line and the world
#   agree. The badge keeps a readable size out to the drop; the diamond fades out
#   inside 20 m, where the Warden itself fills the view.
# - Stage 2's vent caps are three glowing domes on the deck with heat plumes rising
#   above the jaws; stage 3's magnet is a lit arm and head that burn amber while the
#   tug is on, the moment a shot on them counts.
#
# A rolling ball never reaches above 2 m, and below 2 m nothing here extends past the
# collider's 2.8 m radius, so the body the player sees is the body the ball meets.

const JAW_COUNT := 4
const JAW_RADIUS := 3.1
const JAW_SIZE := Vector3(2.6, 5.2, 0.7)
const JAW_BOTTOM := 2.0
const JAW_TILT := 0.14
const COLLAR_RADIUS := 2.75
const COLLAR_HEIGHT := 2.2
const DECK_HEIGHT := 3.2
const CORE_HEIGHT := 4.7
const CORE_RADIUS := 1.5
const BADGE_HEIGHT := 12.0
const BADGE_RADIUS := 2.2
const BADGE_SEGMENTS := 24
const BADGE_NEAR := 50.0
const BADGE_MAX_SCALE := 2.4
const MARKER_SIZE := 1.9
const MARKER_FADE_FAR := 20.0
const MARKER_FADE_NEAR := 12.0
const BADGE_PRIORITY := 30
const PLUME_HEIGHT := 4.2
const TURN_RATE := 3.0

var warden
var body_material: StandardMaterial3D
var plate_material: StandardMaterial3D

var _ground := 0.0
var _jaws: Node3D
var _core_material: StandardMaterial3D
var _badge: Node3D
var _segments: Array = []
var _lit_material: StandardMaterial3D
var _dim_material: StandardMaterial3D
var _marker_material: StandardMaterial3D
var _cap_material: StandardMaterial3D
var _plume_material: StandardMaterial3D
var _arm: MeshInstance3D
var _head: Node3D
var _magnet_material: StandardMaterial3D


func build(owner_warden, half_height: float) -> void:
	warden = owner_warden
	name = "WardenLook"
	_ground = -half_height
	body_material = Palette.solid(Palette.CHARCOAL)
	body_material.metallic = 0.5
	body_material.roughness = 0.5
	plate_material = warden._plate_material()
	_build_collar()
	_build_jaws()
	_build_core()
	_build_badge()
	if warden.lesson == "caps":
		_build_caps()
	if warden.lesson == "magnet":
		_build_magnet()


func cap_material() -> StandardMaterial3D:
	return _cap_material


func _mesh(mesh: Mesh, material: Material, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := Palette.solid(color, energy)
	return mat


static func _flat(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := Palette.unshaded(Color(color, alpha))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _build_collar() -> void:
	var collar := CylinderMesh.new()
	collar.top_radius = COLLAR_RADIUS - 0.25
	collar.bottom_radius = COLLAR_RADIUS
	collar.height = COLLAR_HEIGHT
	_mesh(collar, body_material, Vector3.UP * (_ground + COLLAR_HEIGHT * 0.5))
	var deck := CylinderMesh.new()
	deck.top_radius = COLLAR_RADIUS - 0.2
	deck.bottom_radius = COLLAR_RADIUS - 0.2
	deck.height = DECK_HEIGHT - COLLAR_HEIGHT
	_mesh(deck, body_material, Vector3.UP * (_ground + (COLLAR_HEIGHT + DECK_HEIGHT) * 0.5))
	# A riveted band where the jaws bite, above anything a rolling ball can touch.
	var band := TorusMesh.new()
	band.inner_radius = JAW_RADIUS - 0.35
	band.outer_radius = JAW_RADIUS + 0.35
	_mesh(band, body_material, Vector3.UP * (_ground + JAW_BOTTOM + 0.3))


# The jaws turn as one, so a gap (and the core behind it) faces you, and the magnet
# arm swings out through a gap rather than through a plate.
func _build_jaws() -> void:
	_jaws = Node3D.new()
	_jaws.name = "Jaws"
	add_child(_jaws)
	for i in JAW_COUNT:
		var angle := TAU * (i + 0.5) / JAW_COUNT
		var pivot := Node3D.new()
		pivot.rotation.y = -angle
		_jaws.add_child(pivot)
		var plate := BoxMesh.new()
		plate.size = JAW_SIZE
		var jaw := _mesh(plate, plate_material, Vector3(JAW_RADIUS, _ground + JAW_BOTTOM + JAW_SIZE.y * 0.5, 0.0), pivot)
		# Width runs round the mast, thickness out from it; the top leans outward.
		jaw.rotation = Vector3(JAW_TILT, PI * 0.5, 0.0)
		# A heavy lip on top of each jaw, reaching inward like a clamp's teeth.
		var lip := BoxMesh.new()
		lip.size = Vector3(1.4, 0.6, JAW_SIZE.x + 0.3)
		_mesh(lip, body_material, Vector3(JAW_RADIUS - 0.2, _ground + JAW_BOTTOM + JAW_SIZE.y + 0.1, 0.0), pivot)


func _build_core() -> void:
	_core_material = _glow(EventKinds.color("beacon_charge_changed"), 3.0)
	var sphere := SphereMesh.new()
	sphere.radius = CORE_RADIUS
	sphere.height = CORE_RADIUS * 2.0
	_mesh(sphere, _core_material, Vector3.UP * (_ground + CORE_HEIGHT))


# The badge: an integrity ring of segments and the objective diamond, in one node that
# turns to face the camera every frame.
func _build_badge() -> void:
	_badge = Node3D.new()
	_badge.name = "Badge"
	_badge.position = Vector3.UP * (_ground + BADGE_HEIGHT)
	add_child(_badge)
	var tint := EventKinds.color("beacon_charge_changed")
	_lit_material = _badge_material(tint, 1.0)
	_dim_material = _badge_material(Palette.CHARCOAL, 0.7)
	for i in BADGE_SEGMENTS:
		# Clockwise from the top, like a dial filling.
		var angle := PI * 0.5 - TAU * (i + 0.5) / BADGE_SEGMENTS
		var box := BoxMesh.new()
		box.size = Vector3(0.36, TAU * BADGE_RADIUS / BADGE_SEGMENTS * 0.78, 0.12)
		var segment := _mesh(box, _dim_material, Vector3(cos(angle), sin(angle), 0.0) * BADGE_RADIUS, _badge)
		segment.rotation.z = angle
		_segments.append(segment)
	var outline := TorusMesh.new()
	outline.inner_radius = BADGE_RADIUS + 0.25
	outline.outer_radius = BADGE_RADIUS + 0.4
	var ring := _mesh(outline, _badge_material(tint, 0.85), Vector3.ZERO, _badge)
	ring.rotation.x = PI * 0.5
	_marker_material = _badge_material(tint, 0.95)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * MARKER_SIZE
	var marker := _mesh(quad, _marker_material, Vector3.ZERO, _badge)
	marker.rotation.z = PI * 0.25


func _badge_material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := _flat(color, alpha)
	mat.no_depth_test = true
	mat.render_priority = BADGE_PRIORITY
	return mat


func _build_caps() -> void:
	_cap_material = _glow(Palette.AMBER, 3.0)
	_plume_material = _flat(Palette.AMBER, 0.28)
	for cap in warden.cap_points():
		var local: Vector3 = cap - warden.global_position
		var dome := SphereMesh.new()
		dome.radius = 1.05
		dome.height = 1.05
		dome.is_hemisphere = true
		_mesh(dome, _cap_material, Vector3(local.x, _ground + DECK_HEIGHT, local.z))
		var plume := CylinderMesh.new()
		plume.top_radius = 0.15
		plume.bottom_radius = 0.75
		plume.height = PLUME_HEIGHT
		_mesh(plume, _plume_material, Vector3(local.x, _ground + DECK_HEIGHT + 1.0 + PLUME_HEIGHT * 0.5, local.z))


func _build_magnet() -> void:
	_magnet_material = _glow(Palette.SAND, 0.4)
	_arm = MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(0.6, 0.6, 1.0)
	_arm.mesh = beam
	_arm.material_override = body_material
	add_child(_arm)
	_head = Node3D.new()
	add_child(_head)
	var disc := CylinderMesh.new()
	disc.top_radius = warden.MAGNET_RADIUS
	disc.bottom_radius = warden.MAGNET_RADIUS
	disc.height = 0.9
	var face := _mesh(disc, _magnet_material, Vector3.ZERO, _head)
	face.rotation.x = PI * 0.5
	var horn := TorusMesh.new()
	horn.inner_radius = warden.MAGNET_RADIUS * 0.55
	horn.outer_radius = warden.MAGNET_RADIUS * 1.05
	var ring := _mesh(horn, _magnet_material, Vector3.ZERO, _head)
	ring.rotation.x = PI * 0.5


func update(delta: float) -> void:
	if warden == null:
		return
	_turn_jaws(delta)
	_update_core()
	_update_badge()
	_update_caps(delta)
	_update_magnet()


func _turn_jaws(delta: float) -> void:
	var facing: Vector3 = warden.magnet_dir() if warden.magnet_out() > 0.0 else warden.flat_to_ball()
	if facing.length() < 0.5:
		return
	# Gaps sit at angle 0 in the jaw frame; turn that gap toward the facing.
	var want := -atan2(facing.z, facing.x)
	_jaws.rotation.y = lerp_angle(_jaws.rotation.y, want, 1.0 - exp(-TURN_RATE * delta))


func _update_core() -> void:
	var energy: float = 3.0 + 5.0 * warden.charge_fraction()
	if warden.unplated_by_magnet():
		energy = 1.0 + 6.0 * absf(sin(Time.get_ticks_msec() * 0.02))
	_core_material.emission_energy_multiplier = energy


func _update_badge() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var at := _badge.global_position
	var distance := eye.distance_to(at)
	if distance > 0.01:
		_badge.global_basis = Basis.looking_at(at - eye, Vector3.UP)
	var grow := clampf(distance / BADGE_NEAR, 1.0, BADGE_MAX_SCALE)
	_badge.scale = Vector3.ONE * grow
	var broken: float = 1.0 - warden.integrity()
	var lit := int(round(broken * BADGE_SEGMENTS))
	for i in _segments.size():
		(_segments[i] as MeshInstance3D).material_override = _lit_material if i < lit else _dim_material
	var fade := clampf((distance - MARKER_FADE_NEAR) / (MARKER_FADE_FAR - MARKER_FADE_NEAR), 0.0, 1.0)
	_marker_material.albedo_color.a = 0.95 * fade


func _update_caps(delta: float) -> void:
	if _cap_material == null:
		return
	_cap_material.emission_energy_multiplier = move_toward(_cap_material.emission_energy_multiplier, 3.0, delta * 8.0)
	_plume_material.albedo_color.a = 0.22 + 0.1 * sin(Time.get_ticks_msec() * 0.006)


func _update_magnet() -> void:
	if _head == null:
		return
	var out: float = warden.magnet_out()
	var base := Vector3.UP * (_ground + JAW_BOTTOM + JAW_SIZE.y - 0.4)
	var tip: Vector3 = warden.magnet_point() - warden.global_position if out > 0.0 else base + Vector3.UP * 0.8
	_head.position = tip
	var dir: Vector3 = warden.magnet_dir()
	_head.basis = Basis.looking_at(dir, Vector3.UP) if dir.length() > 0.1 else Basis.IDENTITY
	var span := tip - base
	_arm.visible = span.length() > 0.3
	if _arm.visible:
		_arm.position = base + span * 0.5
		_arm.basis = Basis.looking_at(span.normalized(), Vector3.UP if absf(span.normalized().y) < 0.95 else Vector3.FORWARD)
		_arm.scale = Vector3(1.0, 1.0, span.length())
	# Amber while the tug is on: the one moment a shot on the magnet counts.
	var tugging: bool = warden.state_name() == "tug"
	_magnet_material.albedo_color = Palette.AMBER if tugging else Palette.SAND
	_magnet_material.emission = Palette.AMBER if tugging else Palette.SAND
	_magnet_material.emission_energy_multiplier = 5.0 if tugging else 0.4 + 2.0 * out
