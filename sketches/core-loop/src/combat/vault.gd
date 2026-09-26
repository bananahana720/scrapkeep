extends "res://src/combat/enemy.gd"

# A vault: a static plated cache off the fall line (DEMO-SPEC, SHOULD tier). It never
# moves and never attacks. Its plating is the next stage's Warden plating, so cracking
# it early says your build is ahead of the curve; below that it chips 20% like any
# plated target. Breaking it publishes enemy_killed with kind "vault"; build and world
# pay out the part and the bonus core from that fact.

const HALF_HEIGHT := 1.3
const RADIUS := 1.7
const SIZE := Vector3(3.2, 2.6, 3.2)


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, _threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "vault"
	var stage: int = spec.get("stage", 1)
	plating = spec.get("plating", 60.0)
	_set_health(spec.get("hp", 400.0 * stage))
	scrap_value = 10 * stage
	weight = 1000.0
	radius = RADIUS
	half_height = HALF_HEIGHT
	global_position = Vector3(global_position.x, terrain.height(global_position.x, global_position.z) + HALF_HEIGHT, global_position.z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)
	_base_color = Palette.COPPER
	_material = Palette.solid(_base_color, 0.2)
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = SIZE * 0.9
	body.mesh = mesh
	body.material_override = _material
	add_child(body)
	# Two plating bands wrap the crate; they carry the amber or slate tint.
	var band_mat := _plate_material()
	for y in [-0.6, 0.6]:
		var band := MeshInstance3D.new()
		var ring := BoxMesh.new()
		ring.size = Vector3(SIZE.x, 0.35, SIZE.z)
		band.mesh = ring
		band.material_override = band_mat
		band.position = Vector3.UP * y
		add_child(band)


func knock(_direction: Vector3, _force: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	_update_flash(delta)
