extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Roster := preload("res://src/combat/roster.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

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
const BADGE_MAX_SCALE := 3.2
const MARKER_SIZE := 1.9
const MARKER_FADE_FAR := 20.0
const MARKER_FADE_NEAR := 12.0
const BADGE_PRIORITY := 30
const TURN_RATE := 3.0
const SEAM_STROKES := [
	[[-0.5, 1.4, 0.7], [0.1, 0.9, -0.5], [0.55, 0.3, 0.6]],
	[[0.6, -0.4, -0.8], [0.0, -1.0, 0.4], [-0.55, -1.6, -0.6]],
	[[-0.7, 0.2, 0.2], [-0.2, -0.1, -1.0], [0.4, 1.9, 0.9]],
]
const SEAM_WIDTH := 0.1
const SEAM_LENGTH := 0.9
const SEAM_STEP := 25.0
const POSTURE_SEAM_GLOW_MIN := 1.0
const POSTURE_SEAM_GLOW_MAX := 2.6
const JAW_OPEN_DEGREES := 14.0
const JAW_OPEN_RATE := 9.0
const JAW_CLOSE_RATE := 4.0
const OPEN_CORE_GLOW := 2.6

# Godot frees a shader when its last material is freed; hold a session reference.
static var _seam_shader: Material
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
var _seam_material: StandardMaterial3D
var _seams: Array = []
var _jaw_plates: Array = []
var _jaw_bottom := Vector3.ZERO
var _open := 0.0
var _outline: MeshInstance3D


func build(owner_warden, half_height: float) -> void:
	warden = owner_warden
	name = "WardenLook"
	_ground = -half_height
	body_material = Palette.solid(Palette.CHARCOAL)
	body_material.metallic = 0.5
	body_material.roughness = 0.5
	plate_material = warden._plate_material(Enemy.rim_frame_mask())
	_build_collar()
	_build_jaws()
	_build_core()
	_build_badge()


func posture_fight() -> bool:
	return warden != null and warden.has_method("fight") and warden.fight() == "posture"


func jaw_open() -> float:
	return _open


func core_material() -> StandardMaterial3D:
	return _core_material


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
	var band := TorusMesh.new()
	band.inner_radius = JAW_RADIUS - 0.35
	band.outer_radius = JAW_RADIUS + 0.35
	_mesh(band, body_material, Vector3.UP * (_ground + JAW_BOTTOM + 0.3))


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
		jaw.rotation = Vector3(JAW_TILT, PI * 0.5, 0.0)
		_jaw_plates.append(jaw)
		_jaw_bottom = jaw.position - jaw.basis * Vector3(0.0, JAW_SIZE.y * 0.5, 0.0)
		_build_seams(jaw)
		var lip := BoxMesh.new()
		lip.size = Vector3(1.4, 0.6, JAW_SIZE.x + 0.3)
		_mesh(lip, body_material, Vector3(JAW_RADIUS - 0.2, _ground + JAW_BOTTOM + JAW_SIZE.y + 0.1, 0.0), pivot)


func _build_seams(jaw: Node3D) -> void:
	if _seam_material == null:
		_seam_material = _glow(EventKinds.role_color("neutral"), POSTURE_SEAM_GLOW_MIN)
		if _seam_shader == null:
			_seam_shader = _seam_material.duplicate()
			_seam_shader.get_rid()
		for i in SEAM_STROKES.size():
			_seams.append([])
	for level in SEAM_STROKES.size():
		for stroke in SEAM_STROKES[level]:
			var box := BoxMesh.new()
			box.size = Vector3(SEAM_WIDTH, SEAM_LENGTH, 0.05)
			var seam := _mesh(box, _seam_material, Vector3(stroke[0], stroke[1], JAW_SIZE.z * 0.5 + 0.03), jaw)
			seam.rotation.z = stroke[2]
			seam.visible = false
			_seams[level].append(seam)


func _rest_core_color() -> Color:
	return EventKinds.role_color("neutral") if posture_fight() else EventKinds.color("beacon_charge_changed")


func _build_core() -> void:
	_core_material = _glow(_rest_core_color(), 1.2)
	var sphere := SphereMesh.new()
	sphere.radius = CORE_RADIUS
	sphere.height = CORE_RADIUS * 2.0
	_mesh(sphere, _core_material, Vector3.UP * (_ground + CORE_HEIGHT))


func _build_badge() -> void:
	_badge = Node3D.new()
	_badge.name = "Badge"
	_badge.position = Vector3.UP * (_ground + BADGE_HEIGHT)
	add_child(_badge)
	var tint := _rest_core_color()
	_lit_material = _badge_material(tint, 1.0)
	_dim_material = _badge_material(Palette.CHARCOAL, 0.7)
	for i in BADGE_SEGMENTS:
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
	_outline = ring
	_marker_material = _badge_material(tint, 0.95)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * MARKER_SIZE
	var marker := _mesh(quad, _marker_material, Vector3.ZERO, _badge)
	marker.rotation.z = PI * 0.25
	if posture_fight():
		for segment in _segments:
			(segment as MeshInstance3D).visible = false
		_outline.visible = false


func _badge_material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := _flat(color, alpha)
	mat.no_depth_test = true
	mat.render_priority = BADGE_PRIORITY
	return mat


func update(delta: float) -> void:
	if warden == null:
		return
	_turn_jaws(delta)
	_update_open(delta)
	_update_core()
	_update_badge()
	_update_seams()
	_update_body_glow()


func _turn_jaws(delta: float) -> void:
	var facing: Vector3 = warden.flat_to_ball()
	if facing.length() < 0.5:
		return
	var want := -atan2(facing.z, facing.x)
	_jaws.rotation.y = lerp_angle(_jaws.rotation.y, want, 1.0 - exp(-TURN_RATE * delta))


func _update_core() -> void:
	var energy: float = FlashGuard.spike(1.2, 1.2 + 2.0 * warden.charge_fraction())
	if posture_fight():
		var live := EventKinds.state_color("open")
		var shown := live if warden.staggered() else _rest_core_color()
		_core_material.albedo_color = shown
		_core_material.emission = shown
		energy = FlashGuard.spike(1.2, OPEN_CORE_GLOW) if warden.staggered() else 1.2
	_core_material.emission_energy_multiplier = energy


func _update_open(delta: float) -> void:
	if not posture_fight():
		return
	var want := 1.0 if warden.staggered() else 0.0
	_open = move_toward(_open, want, (JAW_OPEN_RATE if want > _open else JAW_CLOSE_RATE) * delta)
	var tilt := JAW_TILT + deg_to_rad(JAW_OPEN_DEGREES) * _open
	for jaw in _jaw_plates:
		(jaw as Node3D).rotation = Vector3(tilt, PI * 0.5, 0.0)
		(jaw as Node3D).position = _jaw_bottom + (jaw as Node3D).basis * Vector3(0.0, JAW_SIZE.y * 0.5, 0.0)


func _update_body_glow() -> void:
	if posture_fight():
		body_material.emission = EventKinds.role_color("neutral")


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


func _update_seams() -> void:
	_update_guard_seams()


func _update_guard_seams() -> void:
	var guard: float = warden.posture()
	for level in _seams.size():
		var lit := guard >= SEAM_STEP * (level + 1)
		for seam in _seams[level]:
			(seam as MeshInstance3D).visible = lit
	_seam_material.emission_energy_multiplier = lerpf(POSTURE_SEAM_GLOW_MIN, POSTURE_SEAM_GLOW_MAX, clampf(guard / BossPosture.FULL, 0.0, 1.0))
