extends Node3D

const Layout := preload("res://src/layout.gd")
const Materials := preload("res://src/materials.gd")
const Palette := preload("res://src/palette.gd")
const Rules := preload("res://src/rules.gd")

# Pickups are plain meshes with a position, not bodies: a hundred physics probes
# would cost more than the whole rest of the stage and buy nothing.
var run
var target
var rng := RandomNumberGenerator.new()

var _items: Array[MeshInstance3D] = []
var _material: StandardMaterial3D


func setup(run_ref, target_ref, seed_value: int) -> void:
	run = run_ref
	target = target_ref
	rng.seed = seed_value
	_material = Materials.solid(Palette.AMBER, 1.4)


func remaining() -> int:
	return _items.size()


# Scrap sits on the lines you would take anyway: the sidings, the switchback roads
# and the high benches, so collecting it never asks you to stop rolling.
func scatter(count: int) -> void:
	var spots: Array[Vector2] = []
	while spots.size() < count:
		var roll := rng.randf()
		if roll < 0.55:
			var sz: float = Layout.SIDING_Z[rng.randi_range(0, Layout.SIDING_Z.size() - 1)]
			spots.append(Vector2(rng.randf_range(-152.0, 152.0), sz + rng.randf_range(-5.0, 5.0)))
		elif roll < 0.85:
			var k := rng.randi_range(0, Layout.CLIFF_Z.size() - 1)
			var cliff: float = Layout.CLIFF_Z[k]
			spots.append(Vector2(
				Layout.ROAD_X[k] + rng.randf_range(-14.0, 14.0),
				cliff + rng.randf_range(-4.0, Layout.ROAD_RUN)))
		else:
			var m: Dictionary = Layout.MESAS[rng.randi_range(0, Layout.MESAS.size() - 1)]
			var centre: Vector2 = m["centre"]
			spots.append(centre + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0)))
	for spot in spots:
		_add(Layout.drop_at(spot, 1.1))


func drop(at: Vector3, count: int) -> void:
	for i in count:
		_add(at + Vector3(rng.randf_range(-2.0, 2.0), 1.0, rng.randf_range(-2.0, 2.0)))


func _add(at: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.55, 0.55)
	mesh.mesh = box
	mesh.material_override = _material
	mesh.position = at
	add_child(mesh)
	_items.append(mesh)


func _physics_process(delta: float) -> void:
	if target == null or run == null or not run.live():
		return
	var ball: Vector3 = target.ball_position()
	var taken := 0
	var index := _items.size() - 1
	while index >= 0:
		var item := _items[index]
		var offset: Vector3 = ball - item.position
		var gap := offset.length()
		if gap < Rules.PICKUP_RANGE:
			_items.remove_at(index)
			item.queue_free()
			taken += Rules.SCRAP_PER_PICKUP
		elif gap < Rules.MAGNET_RANGE:
			# Pull hard enough that a fast pass still sweeps the line clean.
			item.position += offset.normalized() * minf(gap, 26.0 * delta)
			item.rotate_y(delta * 6.0)
		index -= 1
	if taken > 0:
		run.add_scrap(taken)
