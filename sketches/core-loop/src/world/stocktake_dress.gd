extends Node3D

const ModelKit := preload("res://src/world/model_kit.gd")

# The stocktake yard's furniture (BACKLOG W1-101): the clerk's stand and the gate, both just outside the ring on the
# side the ride goes on (machines climb in on the ring itself, so nothing arrives inside either). The gate stands shut
# while a count stands and sinks into the ground while the floor is clear, which is when rolling out banks; when the
# yard is over it sinks for good. Both are solid. The ring itself is not fenced: the ball can still leave anywhere,
# and the gate marks which way is out. Marker flags stand round the ring's edge, clear of the gate; they are not solid
# and stand only where their model is. A muster, which comes to the ball, has no furniture but the siren mast that
# stands where it is called (mast()).

const STAND := "res://assets/models/world_one/poi_tally_stand.glb"
const GATE := "res://assets/models/world_one/poi_yard_gate.glb"
const FLAG := "res://assets/models/world_one/poi_ring_flag.glb"
const MAST := "res://assets/models/world_one/poi_siren_mast.glb"
# The models' sizes: the stand's footprint and height, and the gate's depth, height and width (wide along its Z).
const STAND_SIZE := Vector3(3.0, 4.0, 3.0)
const GATE_SIZE := Vector3(2.3, 4.0, 8.0)
# The gate's near face stands this far outside the ring. The stand sits this far outside it, this far round it from
# the gate (radians).
const GATE_OUT_M := 2.0
const STAND_OUT_M := 5.0
const STAND_ROUND := 0.4
# The gate sinks this far, in this long, and does not rise while the ball is this close to it.
const SINK_M := 4.3
const SINK_S := 0.6
const RISE_CLEAR_M := 7.0
# Marker flags: this many round the ring, none within this angle of the gate (radians).
const FLAGS := 14
const FLAG_GATE_CLEAR := 0.35

var _gate: Node3D
var _up := 0.0
var _over := false


# The furniture of a yard whose ring of `ring` metres is centred on `site`, with the way out along `out` (plan);
# `ground` gives the ground's height at a plan x and z. Null when the models are missing: the yard stays a ring.
static func attach(site: Node3D, ring: float, out: Vector2, ground: Callable) -> Node3D:
	var dress := new()
	dress.name = "StocktakeDress"
	site.add_child(dress)
	if not dress._build(site.global_position, ring, out.normalized() if out.length() > 0.01 else Vector2.DOWN, ground):
		dress.free()
		return null
	return dress


# Called every tick the yard runs: the gate sinks while `open`, and stands otherwise once nothing in `near` (the ball
# and the machines, world positions) is beside it.
func step(delta: float, open: bool, near: Array) -> void:
	if not open:
		for at: Vector3 in near:
			if Vector2(at.x - _gate.global_position.x, at.z - _gate.global_position.z).length() < RISE_CLEAR_M:
				return
	_move(delta, open)


# The yard is over, banked or forfeited: the gate sinks and stays down, leaving the way on open.
func stand_down() -> void:
	_over = true
	set_physics_process(true)


func gate_shut() -> bool:
	return is_equal_approx(_gate.position.y, _up)


func gate_sunk() -> bool:
	return is_equal_approx(_gate.position.y, _up - SINK_M)


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_move(delta, true)
	if gate_sunk():
		set_physics_process(false)


func _move(delta: float, open: bool) -> void:
	_gate.position.y = move_toward(_gate.position.y, _up - (SINK_M if open or _over else 0.0), SINK_M / SINK_S * delta)


func _build(centre: Vector3, ring: float, out: Vector2, ground: Callable) -> bool:
	_gate = _piece(GATE, GATE_SIZE)
	var stand := _piece(STAND, STAND_SIZE)
	if _gate == null or stand == null:
		return false
	# World positions and turns, so a site that is itself turned changes nothing.
	var gate_at: Vector2 = out * (ring + GATE_OUT_M + GATE_SIZE.x * 0.5)
	_gate.global_position = Vector3(centre.x + gate_at.x, float(ground.call(centre.x + gate_at.x, centre.z + gate_at.y)), centre.z + gate_at.y)
	# The gate's width (its Z) lies along the ring: its X points out.
	_gate.global_rotation = Vector3(0.0, atan2(-out.y, out.x), 0.0)
	_up = _gate.position.y
	var stand_at: Vector2 = out.rotated(STAND_ROUND) * (ring + STAND_OUT_M)
	stand.global_position = Vector3(centre.x + stand_at.x, float(ground.call(centre.x + stand_at.x, centre.z + stand_at.y)), centre.z + stand_at.y)
	# The stand's front (its X) faces the ring's centre.
	stand.global_rotation = Vector3(0.0, atan2(stand_at.y, -stand_at.x), 0.0)
	if ResourceLoader.exists(FLAG):
		var flags := Node3D.new()
		flags.name = "Flags"
		add_child(flags)
		for spot in flag_spots(ring, out):
			var flag := Node3D.new()
			flags.add_child(flag)
			ModelKit.whole(FLAG, flag)
			flag.global_position = Vector3(centre.x + spot.x, float(ground.call(centre.x + spot.x, centre.z + spot.y)), centre.z + spot.y)
			# The pennant flies along the ring.
			flag.global_rotation = Vector3(0.0, atan2(spot.x, spot.y) + PI * 0.5, 0.0)
	return true


# Where a ring's marker flags stand, as offsets from its centre in plan: FLAGS evenly round a ring of `ring` metres,
# less any within FLAG_GATE_CLEAR of the way out, where the gate stands.
static func flag_spots(ring: float, out: Vector2) -> PackedVector2Array:
	var spots := PackedVector2Array()
	for i in FLAGS:
		var spot := out.normalized().rotated(TAU * (i + 0.5) / FLAGS) * ring
		if absf(spot.angle_to(out)) >= FLAG_GATE_CLEAR:
			spots.append(spot)
	return spots


# The siren mast that stands where a muster is called, under `parent` at plan point `at`, its horn toward `face`.
# Not solid. Null where the model is missing.
static func mast(parent: Node3D, at: Vector2, face: Vector2, ground: Callable) -> Node3D:
	if not ResourceLoader.exists(MAST):
		return null
	var pole := Node3D.new()
	pole.name = "SirenMast"
	parent.add_child(pole)
	ModelKit.whole(MAST, pole)
	pole.global_position = Vector3(at.x, float(ground.call(at.x, at.y)), at.y)
	# The model's horn points along its +X.
	pole.global_rotation = Vector3(0.0, atan2(-face.y, face.x), 0.0)
	return pole


# A solid body the size of the model, with the model on it, base at the body's origin.
func _piece(path: String, size: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	if ModelKit.whole(path, body) == null:
		body.free()
		return null
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3.UP * size.y * 0.5
	body.add_child(shape)
	add_child(body)
	return body
