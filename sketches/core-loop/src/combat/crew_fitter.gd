extends "res://src/combat/enemy.gd"

const Roster := preload("res://src/combat/roster.gd")
const SwarmRemnant := preload("res://src/combat/swarm_remnant.gd")

# One of the Waking's crew (challenge lane, weak points step 2b): a seam fitter that flies to an open hatch and
# holds a plate over it. It wears the swarm drone's casting and hover (swarm_remnant.gd's shared parts and
# stripe), but no swarm drives it: it never forms, locks or dives and is harmless to touch. The pressure is time,
# not HP. The boss (waking.gd) owns the fit: it books the fit with the weak rule when this fitter arrives, calls
# dislodge() when a reel impact lands on it, and retire() when its hatch closes. This body only flies.
#
# inbound   flying to its slot at the hatch
# fitting   holding the plate in its slot
# knocked   thrown off with its plate dropped; returns to inbound after KNOCK_SECONDS
# retiring  its hatch closed; gone without a kill (retire())

# The body is the swarm drone's casting (SwarmRemnant._parts loads this file); named here so the dress coverage
# scan reads this kind's model.
const MODEL := "res://assets/models/world_one/enemy_swarm_remnant.glb"
const HP := 12.0
const SIZE := SwarmRemnant.SIZE
const FLY_SPEED := 24.0
const SLOT_GAIN := 5.0
# Within this of its slot a fitter is on the hatch.
const ARRIVE := 1.2
const KNOCK_SECONDS := 1.5
const DISLODGE_FORCE := 14.0
const PLATE_SIZE := Vector3(1.1, 0.12, 0.8)
const PLATE_COLOR := Color(0.62, 0.55, 0.42)

enum State { INBOUND, FITTING, KNOCKED, RETIRING }

var point_id := ""
# 0 to 1 of the hatch's fit clock, kept current by the boss: the read surface for the fitting cue and sound.
var seal_progress := 0.0
var slot := Vector3.ZERO
var fit_state := State.INBOUND
var _knocked_left := 0.0
var _plate: MeshInstance3D
var _slab: Node3D
# Kept for the fitting cue (step 2c): _seam is the casting's seam strip the cue lights with seal_progress.
var _body: MeshInstance3D
var _seam: MeshInstance3D


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "crew_fitter"
	faction = Roster.SWARM
	_set_health(HP * threat)
	scrap_value = 0
	weight = 0.4
	radius = SIZE
	half_height = 0.3
	# A flyer: it holds its slot in the air and never meets the arena's walls.
	collision_mask = 0
	_build_body()


func state_name() -> String:
	return ["inbound", "fitting", "knocked", "retiring"][fit_state]


# Sent to a hatch: fly to this slot until retired.
func assign(id: String, at: Vector3) -> void:
	point_id = id
	slot = at
	fit_state = State.INBOUND
	_show_plate(true)


func hatch_id() -> String:
	return point_id


func arrived() -> bool:
	return global_position.distance_to(slot) <= ARRIVE


# The boss books the fit and calls this when the fitter is on its slot.
func start_fit() -> void:
	if fit_state == State.INBOUND:
		fit_state = State.FITTING


# Only a reel impact moves a fitter off its plate (dislodge). Any other shove leaves a fitting fitter seated, so its
# counted fit and its place stay in step.
func knock(direction: Vector3, force: float) -> void:
	if fit_state == State.FITTING:
		return
	super(direction, force)


# A reel impact: off the hatch, the plate falls, a short throw away from the slot.
func dislodge(away: Vector3) -> void:
	if fit_state != State.FITTING:
		return
	fit_state = State.KNOCKED
	_knocked_left = KNOCK_SECONDS
	_show_plate(false)
	var flat := Vector3(away.x, 0.0, away.z)
	var dir := flat.normalized() if flat.length_squared() > 0.0001 else Vector3.RIGHT
	_knock = dir * DISLODGE_FORCE
	_knock.y = DISLODGE_FORCE * 0.3


# Its hatch closed: gone with no kill. This is the same no-reward path as Mind._free_hands (a plain free); died is
# never emitted, so combat.gd's handler books no kill, scrap or retirement.
func retire() -> void:
	if fit_state == State.RETIRING:
		return
	fit_state = State.RETIRING
	_dead = true
	collision_layer = 0
	collision_mask = 0
	_clear_telegraph()
	remove_from_group("enemy")
	visible = false
	set_physics_process(false)
	queue_free()


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if fit_state == State.RETIRING:
		return
	if fit_state == State.KNOCKED:
		_knocked_left -= delta
		if _knocked_left <= 0.0:
			fit_state = State.INBOUND
			_show_plate(true)
	var desired := Vector3.ZERO
	if _in_play() and fit_state != State.KNOCKED:
		var to_slot := slot - global_position
		desired = (to_slot * SLOT_GAIN).limit_length(FLY_SPEED)
	_fly(delta, desired)


func _fly(delta: float, desired: Vector3) -> void:
	var horizontal := Vector3(_knock.x, 0.0, _knock.z)
	if horizontal.length() < 1.0:
		horizontal = Vector3(desired.x, 0.0, desired.z)
	var vertical := desired.y if _knock.y <= 0.0 else _knock.y
	velocity = Vector3(horizontal.x, vertical, horizontal.z)
	_knock.y = 0.0
	move_and_slide()
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)
	if horizontal.length() > 0.5:
		rotation.y = atan2(horizontal.x, horizontal.z)


func _show_plate(on: bool) -> void:
	if _plate != null:
		_plate.visible = on


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE * 2.0, 0.6, SIZE * 2.0)
	shape.shape = box
	add_child(shape)
	_slab = Node3D.new()
	_slab.name = "Slab"
	_visual_parent().add_child(_slab)
	var parts := SwarmRemnant._parts()
	if not parts.is_empty():
		_base_color = Color.WHITE
		_material = Palette.solid(Color.WHITE)
		_material.vertex_color_use_as_albedo = true
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_slab.add_child(mi)
			if part.name == "RemnantBody":
				_body = mi
			elif part.name == "RemnantSeam":
				_seam = mi
	else:
		_base_color = Roster.ANCIENT_ENAMEL
		_material = Palette.solid(Roster.ANCIENT_ENAMEL)
		var prism := CylinderMesh.new()
		prism.radial_segments = 3
		prism.top_radius = SIZE
		prism.bottom_radius = SIZE
		prism.height = 0.22
		_body = MeshInstance3D.new()
		_body.mesh = prism
		_body.material_override = _material
		_slab.add_child(_body)
	var plate := BoxMesh.new()
	plate.size = PLATE_SIZE
	_plate = MeshInstance3D.new()
	_plate.name = "SeamPlate"
	_plate.mesh = plate
	_plate.material_override = Palette.solid(PLATE_COLOR)
	_plate.position = Vector3(0.0, 0.5, 0.0)
	_slab.add_child(_plate)
