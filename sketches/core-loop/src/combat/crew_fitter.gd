extends "res://src/combat/enemy.gd"

const Roster := preload("res://src/combat/roster.gd")
const SwarmRemnant := preload("res://src/combat/swarm_remnant.gd")

const MODEL := "res://assets/models/world_one/enemy_swarm_remnant.glb"
const HP := 12.0
const SIZE := SwarmRemnant.SIZE
const FLY_SPEED := 24.0
const SLOT_GAIN := 5.0
const ARRIVE := 1.2
const KNOCK_SECONDS := 1.5
const DISLODGE_FORCE := 14.0
const PLATE_SIZE := Vector3(1.1, 0.12, 0.8)
const PLATE_COLOR := Color(0.62, 0.55, 0.42)
const SEAM_LIT := SwarmRemnant.SEAM_LIT
const SEAM_DIM := SwarmRemnant.SEAM_DIM
const SEAM_SEALING := 4.4
const SPARK_SIZE := 0.16
const SPARK_HZ := 18.0

enum State { INBOUND, FITTING, KNOCKED, RETIRING }

var point_id := ""
var seal_progress := 0.0
var slot := Vector3.ZERO
var fit_state := State.INBOUND
var _knocked_left := 0.0
var _plate: MeshInstance3D
var _slab: Node3D
var _body: MeshInstance3D
var _seam: MeshInstance3D
var _seam_material: StandardMaterial3D
var _spark: MeshInstance3D
var _contact := Vector3.INF
var _cue_clock := 0.0


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "crew_fitter"
	faction = Roster.SWARM
	_set_health(HP * threat)
	scrap_value = 0
	weight = 0.4
	radius = SIZE
	half_height = 0.3
	collision_mask = PhysicsLayers.NONE
	_build_body()


func state_name() -> String:
	return ["inbound", "fitting", "knocked", "retiring"][fit_state]


func assign(id: String, at: Vector3, contact := Vector3.INF) -> void:
	point_id = id
	slot = at
	_contact = contact
	fit_state = State.INBOUND
	_show_plate(true)


func hatch_id() -> String:
	return point_id


func arrived() -> bool:
	return global_position.distance_to(slot) <= ARRIVE


func start_fit() -> void:
	if fit_state == State.INBOUND:
		fit_state = State.FITTING
		_update_cue(0.0)


func knock(direction: Vector3, force: float) -> void:
	if fit_state == State.FITTING:
		return
	super(direction, force)


func absorbs_hit(_result: Dictionary) -> bool:
	return true


func take_damage(_amount: float) -> float:
	if not _dead:
		flash()
	return 0.0


func crushable() -> bool:
	return false


func takes_no_damage() -> bool:
	return true


func remove_for_test() -> void:
	super.take_damage(hp)


func dislodge(away: Vector3) -> void:
	if fit_state != State.FITTING:
		return
	fit_state = State.KNOCKED
	_knocked_left = KNOCK_SECONDS
	_show_plate(false)
	_update_cue(0.0)
	var flat := Vector3(away.x, 0.0, away.z)
	var dir := flat.normalized() if flat.length_squared() > 0.0001 else Vector3.RIGHT
	_knock = dir * DISLODGE_FORCE
	_knock.y = DISLODGE_FORCE * 0.3


func retire() -> void:
	if fit_state == State.RETIRING:
		return
	fit_state = State.RETIRING
	_dead = true
	collision_layer = PhysicsLayers.NONE
	collision_mask = PhysicsLayers.NONE
	_clear_telegraph()
	remove_from_group(GROUP)
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
	_update_cue(delta)
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


func seam_energy() -> float:
	if _seam_material == null:
		return 0.0
	return _seam_material.emission_energy_multiplier


func spark_visible() -> bool:
	return _spark != null and _spark.visible


func _update_cue(delta: float) -> void:
	if _seam_material == null:
		return
	_cue_clock += delta
	var dark := fit_state == State.KNOCKED
	var energy := SEAM_LIT
	if dark:
		energy = SEAM_DIM
	elif fit_state == State.FITTING:
		energy = lerpf(SEAM_LIT, SEAM_SEALING, clampf(seal_progress, 0.0, 1.0))
	_seam_material.emission_energy_multiplier = energy
	_seam_material.albedo_color = Roster.ANCIENT_LIGHT.darkened(0.6) if dark else Roster.ANCIENT_LIGHT
	var sparking := fit_state == State.FITTING
	if sparking and _spark == null:
		_build_spark()
	if _spark != null:
		_spark.visible = sparking and fposmod(_cue_clock * SPARK_HZ, 1.0) < 0.6
		if _contact != Vector3.INF:
			_spark.global_position = _contact


func _build_spark() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * SPARK_SIZE
	_spark = MeshInstance3D.new()
	_spark.name = "WeldSpark"
	_spark.mesh = mesh
	_spark.material_override = Palette.solid(Roster.ANCIENT_LIGHT, SEAM_SEALING, false)
	_spark.top_level = true
	add_child(_spark)
	_spark.visible = false


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
				_seam_material = (mi.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
				mi.set_surface_override_material(0, _seam_material)
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
		var edge := CylinderMesh.new()
		edge.radial_segments = 3
		edge.top_radius = SIZE * 0.55
		edge.bottom_radius = SIZE * 0.55
		edge.height = 0.24
		_seam = MeshInstance3D.new()
		_seam.mesh = edge
		_seam_material = Palette.solid(Roster.ANCIENT_LIGHT, SEAM_LIT)
		_seam.material_override = _seam_material
		_seam.position = Vector3.UP * 0.02
		_slab.add_child(_seam)
	var plate := BoxMesh.new()
	plate.size = PLATE_SIZE
	_plate = MeshInstance3D.new()
	_plate.name = "SeamPlate"
	_plate.mesh = plate
	_plate.material_override = Palette.solid(PLATE_COLOR)
	_plate.position = Vector3(0.0, 0.5, 0.0)
	_slab.add_child(_plate)
