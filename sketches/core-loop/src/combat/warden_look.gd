extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Roster := preload("res://src/combat/roster.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")

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
# - Shred shows as glowing seams cracked across the jaw plates: none below SEAM_SHOW of
#   the plating stripped, then more of them and brighter as the strip deepens, in the
#   amber the plates turn once your punch beats what is left.
# - On the posture rule the look changes: the cracks are the guard, in the neutral colour,
#   the jaws lean open and the core goes live while staggered, and the ring is hidden.
# - Stage 2's brood cells have hexagonal rims and amber membranes, with matching
#   hex markers above the jaws; stage 3's magnet is a lit arm and head that burn amber while the
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
const BADGE_MAX_SCALE := 3.2
const MARKER_SIZE := 1.9
const MARKER_FADE_FAR := 20.0
const MARKER_FADE_NEAR := 12.0
const BADGE_PRIORITY := 30
const BROOD_MARKER_HEIGHT := 8.1
const TURN_RATE := 3.0
const SEAM_SHOW := 0.25
# Each seam is a zigzag of strokes across a jaw's outer face: [x, y, tilt] in the
# plate's frame, the plate's centre at 0. A seam lights once the strip passes its
# threshold, from SEAM_SHOW to fully stripped.
const SEAM_STROKES := [
	[[-0.5, 1.4, 0.7], [0.1, 0.9, -0.5], [0.55, 0.3, 0.6]],
	[[0.6, -0.4, -0.8], [0.0, -1.0, 0.4], [-0.55, -1.6, -0.6]],
	[[-0.7, 0.2, 0.2], [-0.2, -0.1, -1.0], [0.4, 1.9, 0.9]],
]
const SEAM_WIDTH := 0.1
const SEAM_LENGTH := 0.9
const SEAM_GLOW_MIN := 1.4
const SEAM_GLOW_MAX := 4.5
# On the posture rule the seams are the guard: level n lights at SEAM_STEP times n and
# seals again as the guard drains below it, in the neutral role colour.
const SEAM_STEP := 25.0
const POSTURE_SEAM_GLOW_MIN := 1.0
const POSTURE_SEAM_GLOW_MAX := 2.6
# A staggered posture Warden's jaws each lean this far further out from their bottom edge,
# so two opposite jaws stand 2 x JAW_OPEN_DEGREES further apart. The opening springs fast
# and closes slower.
const JAW_OPEN_DEGREES := 14.0
const JAW_OPEN_RATE := 9.0
const JAW_CLOSE_RATE := 4.0
const OPEN_CORE_GLOW := 2.6

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
var _arm: MeshInstance3D
var _head: Node3D
var _magnet_material: StandardMaterial3D
var _seam_material: StandardMaterial3D
# Per seam level, the stroke nodes on every jaw.
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
	if warden.lesson == "caps":
		_build_caps()
	if warden.lesson == "magnet":
		_build_magnet()


func cap_material() -> StandardMaterial3D:
	return _cap_material


# True when this Warden fights on the posture rule (the plate carries its health).
func posture_fight() -> bool:
	return warden != null and warden.has_method("fight") and warden.fight() == "posture"


# How far the jaws stand open, 0 at rest to 1 fully sprung.
func jaw_open() -> float:
	return _open


# How many seam levels are lit now.
func lit_levels() -> int:
	var count := 0
	for level in _seams.size():
		if not _seams[level].is_empty() and (_seams[level][0] as MeshInstance3D).visible:
			count += 1
	return count


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
		_jaw_plates.append(jaw)
		_jaw_bottom = jaw.position - jaw.basis * Vector3(0.0, JAW_SIZE.y * 0.5, 0.0)
		_build_seams(jaw)
		# A heavy lip on top of each jaw, reaching inward like a clamp's teeth.
		var lip := BoxMesh.new()
		lip.size = Vector3(1.4, 0.6, JAW_SIZE.x + 0.3)
		_mesh(lip, body_material, Vector3(JAW_RADIUS - 0.2, _ground + JAW_BOTTOM + JAW_SIZE.y + 0.1, 0.0), pivot)


# The plate's +z is its outer face; strokes sit just proud of it, so they never clip.
func _build_seams(jaw: Node3D) -> void:
	if _seam_material == null:
		_seam_material = _glow(EventKinds.role_color("neutral") if posture_fight() else Palette.AMBER, SEAM_GLOW_MIN)
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


# The core's colour at rest: the beacon row's, except on the posture rule, where the live
# colour belongs to an open core alone.
func _rest_core_color() -> Color:
	return EventKinds.role_color("neutral") if posture_fight() else EventKinds.color("beacon_charge_changed")


func _build_core() -> void:
	_core_material = _glow(_rest_core_color(), 1.2)
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
	var tint := _rest_core_color()
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
	_outline = ring
	_marker_material = _badge_material(tint, 0.95)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * MARKER_SIZE
	var marker := _mesh(quad, _marker_material, Vector3.ZERO, _badge)
	marker.rotation.z = PI * 0.25
	# The plate carries a posture Warden's health, so the ring is not drawn.
	if posture_fight():
		for segment in _segments:
			(segment as MeshInstance3D).visible = false
		_outline.visible = false


func _badge_material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := _flat(color, alpha)
	mat.no_depth_test = true
	mat.render_priority = BADGE_PRIORITY
	return mat


func _build_caps() -> void:
	_cap_material = _glow(Palette.AMBER, 2.2)
	var enamel := Palette.solid(Roster.ANCIENT_ENAMEL)
	enamel.roughness = 0.8
	var brood := Node3D.new()
	brood.name = "BroodCells"
	add_child(brood)
	var index := 0
	for cap in warden.cap_points():
		var local: Vector3 = cap - warden.global_position
		var cell := Node3D.new()
		cell.name = "BroodCap_%d" % index
		cell.position = local
		brood.add_child(cell)
		var membrane := CylinderMesh.new()
		membrane.radial_segments = 6
		membrane.top_radius = 0.72
		membrane.bottom_radius = warden.CAP_RADIUS
		membrane.height = 0.28
		_mesh(membrane, _cap_material, Vector3.ZERO, cell).name = "Membrane"
		_hex_rim(cell, 0.92, 0.14, enamel, false)
		# The deck is hidden from a ground approach. An open hex glyph marks each
		# cell's x/z without drawing a solid heat column through the family kit.
		var marker := Node3D.new()
		marker.name = "BroodMarker_%d" % index
		marker.position = Vector3(local.x, _ground + BROOD_MARKER_HEIGHT, local.z)
		brood.add_child(marker)
		_hex_rim(marker, 0.45, 0.075, _cap_material, true)
		index += 1


func _hex_rim(parent: Node3D, radius: float, width: float, mat: Material, upright: bool) -> void:
	for side in 6:
		var a := TAU * float(side) / 6.0
		var b := TAU * float(side + 1) / 6.0
		var from := Vector3(cos(a), sin(a), 0.0) * radius if upright else Vector3(cos(a), 0.0, sin(a)) * radius
		var to := Vector3(cos(b), sin(b), 0.0) * radius if upright else Vector3(cos(b), 0.0, sin(b)) * radius
		var edge := BoxMesh.new()
		edge.size = Vector3(width, width, from.distance_to(to))
		var node := _mesh(edge, mat, (from + to) * 0.5, parent)
		node.basis = Basis.looking_at(to - from, Vector3.FORWARD if upright else Vector3.UP)


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
	_update_open(delta)
	_update_core()
	_update_badge()
	_update_caps(delta)
	_update_magnet()
	_update_seams()
	_update_body_glow()


func _turn_jaws(delta: float) -> void:
	var facing: Vector3 = warden.magnet_dir() if warden.magnet_out() > 0.0 else warden.flat_to_ball()
	if facing.length() < 0.5:
		return
	# Gaps sit at angle 0 in the jaw frame; turn that gap toward the facing.
	var want := -atan2(facing.z, facing.x)
	_jaws.rotation.y = lerp_angle(_jaws.rotation.y, want, 1.0 - exp(-TURN_RATE * delta))


func _update_core() -> void:
	# Kept low enough that the core keeps its colour instead of blowing out to white.
	var energy: float = 1.2 + 2.0 * warden.charge_fraction()
	if warden.unplated_by_magnet():
		energy = 0.4 + 2.6 * absf(sin(Time.get_ticks_msec() * 0.02))
	if posture_fight():
		var live := EventKinds.state_color("open")
		var shown := live if warden.staggered() else _rest_core_color()
		_core_material.albedo_color = shown
		_core_material.emission = shown
		energy = OPEN_CORE_GLOW if warden.staggered() else 1.2
	_core_material.emission_energy_multiplier = energy


# The jaws lean out while the core is open and close after it, from their bottom edge so
# nothing dips under the 2 m line.
func _update_open(delta: float) -> void:
	if not posture_fight():
		return
	var want := 1.0 if warden.staggered() else 0.0
	_open = move_toward(_open, want, (JAW_OPEN_RATE if want > _open else JAW_CLOSE_RATE) * delta)
	var tilt := JAW_TILT + deg_to_rad(JAW_OPEN_DEGREES) * _open
	for jaw in _jaw_plates:
		(jaw as Node3D).rotation = Vector3(tilt, PI * 0.5, 0.0)
		(jaw as Node3D).position = _jaw_bottom + (jaw as Node3D).basis * Vector3(0.0, JAW_SIZE.y * 0.5, 0.0)


# Combat's hit flash lights the body amber; a posture Warden shows no amber, so its flash
# keeps its size and loses the colour.
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


func _update_caps(delta: float) -> void:
	if _cap_material == null:
		return
	_cap_material.emission_energy_multiplier = move_toward(_cap_material.emission_energy_multiplier, 2.2, delta * 8.0)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		for marker in get_node("BroodCells").get_children():
			if String(marker.name).begins_with("BroodMarker_"):
				var facing: Vector3 = camera.global_position - marker.global_position
				facing.y = 0.0
				if facing.length_squared() > 0.001:
					marker.basis = Basis.looking_at(-facing, Vector3.UP)


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
	_magnet_material.emission_energy_multiplier = 2.4 if tugging else 0.4 + 1.2 * out


func _update_seams() -> void:
	if posture_fight():
		_update_guard_seams()
		return
	var strip: float = warden.shred_fraction()
	var depth := clampf((strip - SEAM_SHOW) / (1.0 - SEAM_SHOW), 0.0, 1.0)
	for level in _seams.size():
		var lit: bool = strip > SEAM_SHOW and depth >= float(level) / _seams.size()
		for seam in _seams[level]:
			(seam as MeshInstance3D).visible = lit
	_seam_material.emission_energy_multiplier = lerpf(SEAM_GLOW_MIN, SEAM_GLOW_MAX, depth)


# The guard as cracks: one more level at each quarter, sealing as the guard drains.
func _update_guard_seams() -> void:
	var guard: float = warden.posture()
	for level in _seams.size():
		var lit := guard >= SEAM_STEP * (level + 1)
		for seam in _seams[level]:
			(seam as MeshInstance3D).visible = lit
	_seam_material.emission_energy_multiplier = lerpf(POSTURE_SEAM_GLOW_MIN, POSTURE_SEAM_GLOW_MAX, clampf(guard / BossPosture.FULL, 0.0, 1.0))
