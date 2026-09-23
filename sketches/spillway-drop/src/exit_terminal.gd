extends Node3D

const Materials := preload("res://src/materials.gd")
const ExitCharge := preload("res://src/exit_charge.gd")

const REACH := 8.0
const BOARD_RADIUS := 4.0

signal used(node: Node3D)

var charge := ExitCharge.new()

var _material: StandardMaterial3D
var _glow: OmniLight3D
var _gate: MeshInstance3D
var _gate_material: StandardMaterial3D


func setup(at: Vector3) -> void:
	position = at
	_material = Materials.solid(Materials.ARC, 1.0)

	var console := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 2.4, 1.6)
	console.mesh = box
	console.material_override = _material
	console.position = Vector3.UP * 1.2
	add_child(console)

	_gate = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = BOARD_RADIUS - 0.4
	ring.outer_radius = BOARD_RADIUS
	_gate.mesh = ring
	_gate_material = Materials.solid(Materials.VERDIGRIS, 0.4)
	_gate.material_override = _gate_material
	_gate.position = Vector3(0.0, 0.4, 6.0)
	_gate.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(_gate)

	_glow = OmniLight3D.new()
	_glow.light_color = Materials.ARC
	_glow.omni_range = 26.0
	_glow.light_energy = 2.5
	_glow.position = Vector3.UP * 3.0
	add_child(_glow)


func board_point() -> Vector3:
	return global_position + Vector3(0.0, 0.4, 6.0)


func interact_point() -> Vector3:
	return global_position


func interact_radius() -> float:
	return REACH


func prompt(_run_state) -> String:
	match charge.phase:
		ExitCharge.IDLE:
			return "E  start the 60 s pump-house charge (stay within %d m)" % int(ExitCharge.RADIUS)
		ExitCharge.CHARGING:
			return "charging %d%%  ·  hold the pump house" % int(charge.fraction() * 100.0)
		_:
			return "charged  ·  roll into the gate"


func interact(_run_state) -> void:
	if charge.begin():
		used.emit(self)


func step(delta: float, ball: Vector3) -> void:
	charge.advance(delta, Vector2(ball.x, ball.z).distance_to(Vector2(global_position.x, global_position.z)))
	var ready := charge.phase == ExitCharge.READY
	_material.emission_energy_multiplier = 1.0 + charge.fraction() * 4.0
	_glow.light_energy = 2.5 + charge.fraction() * 7.0
	_gate_material.albedo_color = Materials.ARC if ready else Materials.VERDIGRIS
	_gate_material.emission_energy_multiplier = 3.0 if ready else 0.4


func boarded(ball: Vector3) -> bool:
	return charge.phase == ExitCharge.READY and ball.distance_to(board_point()) < BOARD_RADIUS + 1.4
