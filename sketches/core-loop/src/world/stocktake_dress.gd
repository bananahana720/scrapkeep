extends Node3D

const ModelKit := preload("res://src/world/model_kit.gd")

# The stocktake yard's furniture (BACKLOG W1-101): the clerk's stand beside the ring and the gate on the ring's edge
# on the side the ride goes on. The gate stands shut while a count stands and sinks into the ground while the floor
# is clear, which is when rolling out banks. Both are solid. The ring itself is not fenced: the ball can still leave
# anywhere, and the gate marks which way is out.

const STAND := "res://assets/models/world_one/poi_tally_stand.glb"
const GATE := "res://assets/models/world_one/poi_yard_gate.glb"
# The models' sizes: the stand's footprint and height, and the gate's depth, height and width (wide along its Z).
const STAND_SIZE := Vector3(3.0, 4.0, 3.0)
const GATE_SIZE := Vector3(2.3, 4.0, 8.0)
# The stand sits this far outside the ring, this far round it from the gate (radians).
const STAND_OUT_M := 4.0
const STAND_ROUND := 0.4
# The gate sinks this far, in this long, and does not rise while the ball is this close to it.
const SINK_M := 4.3
const SINK_S := 0.6
const RISE_CLEAR_M := 7.0

var _gate: Node3D
var _up := 0.0


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


# Called every tick the yard runs: the gate sinks while `open`, and stands otherwise once the ball is clear of it.
func step(delta: float, open: bool, ball: Vector3) -> void:
	var near: bool = Vector2(ball.x - _gate.global_position.x, ball.z - _gate.global_position.z).length() < RISE_CLEAR_M
	if open or not near:
		_gate.position.y = move_toward(_gate.position.y, _up - (SINK_M if open else 0.0), SINK_M / SINK_S * delta)


func gate_shut() -> bool:
	return is_equal_approx(_gate.position.y, _up)


func _build(centre: Vector3, ring: float, out: Vector2, ground: Callable) -> bool:
	_gate = _piece(GATE, GATE_SIZE)
	var stand := _piece(STAND, STAND_SIZE)
	if _gate == null or stand == null:
		return false
	var gate_at: Vector2 = out * ring
	_up = float(ground.call(centre.x + gate_at.x, centre.z + gate_at.y)) - centre.y
	_gate.position = Vector3(gate_at.x, _up, gate_at.y)
	# The gate's width (its Z) lies along the ring: its X points out.
	_gate.rotation.y = atan2(-out.y, out.x)
	var stand_at: Vector2 = out.rotated(STAND_ROUND) * (ring + STAND_OUT_M)
	stand.position = Vector3(stand_at.x, float(ground.call(centre.x + stand_at.x, centre.z + stand_at.y)) - centre.y, stand_at.y)
	# The stand's front (its X) faces the ring's centre.
	stand.rotation.y = atan2(stand_at.y, -stand_at.x)
	return true


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
