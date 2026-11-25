extends Node3D

const ModelKit := preload("res://src/world/model_kit.gd")


const STAND := "res://assets/models/world_one/poi_tally_stand.glb"
const GATE := "res://assets/models/world_one/poi_yard_gate.glb"
const FLAG := "res://assets/models/world_one/poi_ring_flag.glb"
const MAST := "res://assets/models/world_one/poi_siren_mast.glb"
const STAND_SIZE := Vector3(3.0, 4.0, 3.0)
const GATE_SIZE := Vector3(2.3, 4.0, 8.0)
const GATE_OUT_M := 2.0
const STAND_OUT_M := 5.0
const STAND_ROUND := 0.4
const SINK_M := 4.3
const SINK_S := 0.6
const RISE_CLEAR_M := 7.0
const FLAGS := 14
const FLAG_GATE_CLEAR := 0.35

var _gate: Node3D
var _up := 0.0
var _over := false


static func attach(site: Node3D, ring: float, out: Vector2, ground: Callable) -> Node3D:
	var dress := new()
	dress.name = "StocktakeDress"
	site.add_child(dress)
	if not dress._build(site.global_position, ring, out.normalized() if out.length() > 0.01 else Vector2.DOWN, ground):
		dress.free()
		return null
	return dress


func step(delta: float, open: bool, near: Array) -> void:
	if not open:
		for at: Vector3 in near:
			if Vector2(at.x - _gate.global_position.x, at.z - _gate.global_position.z).length() < RISE_CLEAR_M:
				return
	_move(delta, open)


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
	var gate_at: Vector2 = out * (ring + GATE_OUT_M + GATE_SIZE.x * 0.5)
	_gate.global_position = Vector3(centre.x + gate_at.x, float(ground.call(centre.x + gate_at.x, centre.z + gate_at.y)), centre.z + gate_at.y)
	_gate.global_rotation = Vector3(0.0, atan2(-out.y, out.x), 0.0)
	_up = _gate.position.y
	var stand_at: Vector2 = out.rotated(STAND_ROUND) * (ring + STAND_OUT_M)
	stand.global_position = Vector3(centre.x + stand_at.x, float(ground.call(centre.x + stand_at.x, centre.z + stand_at.y)), centre.z + stand_at.y)
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
			flag.global_rotation = Vector3(0.0, atan2(spot.x, spot.y) + PI * 0.5, 0.0)
	return true


static func flag_spots(ring: float, out: Vector2) -> PackedVector2Array:
	var spots := PackedVector2Array()
	for i in FLAGS:
		var spot := out.normalized().rotated(TAU * (i + 0.5) / FLAGS) * ring
		if absf(spot.angle_to(out)) >= FLAG_GATE_CLEAR:
			spots.append(spot)
	return spots


static func mast(parent: Node3D, at: Vector2, face: Vector2, ground: Callable) -> Node3D:
	if not ResourceLoader.exists(MAST):
		return null
	var pole := Node3D.new()
	pole.name = "SirenMast"
	parent.add_child(pole)
	ModelKit.whole(MAST, pole)
	pole.global_position = Vector3(at.x, float(ground.call(at.x, at.y)), at.y)
	pole.global_rotation = Vector3(0.0, atan2(-face.y, face.x), 0.0)
	return pole


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
