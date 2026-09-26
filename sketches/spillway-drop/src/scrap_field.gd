extends Node3D

const Terrain := preload("res://src/terrain.gd")
const Materials := preload("res://src/materials.gd")

const MAGNET := 6.0
const COLLECT := 1.8
const PULL := 26.0
const SPACING := 8.0
const MAX_PER_LINE := 14

var _items: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _mesh: BoxMesh
var _spin := 0.0


func setup(rng: RandomNumberGenerator) -> void:
	_material = Materials.solid(Materials.ARC, 1.6)
	_mesh = BoxMesh.new()
	_mesh.size = Vector3(0.8, 0.8, 0.8)
	for line in Terrain.SCRAP_LINES:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var n := clampi(int(from.distance_to(to) / SPACING), 4, MAX_PER_LINE)
		for i in n:
			var t := (i + 0.5) / float(n)
			var spot := from.lerp(to, t)
			spot += Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
			_add(Terrain.at(spot, 1.4))


func count() -> int:
	return _items.size()


func item_position(index: int) -> Vector3:
	return _items[index].global_position


func drop(at: Vector3, amount: int, rng: RandomNumberGenerator) -> void:
	for i in amount:
		_add(at + Vector3(rng.randf_range(-2.0, 2.0), 1.2, rng.randf_range(-2.0, 2.0)))


# Returns how many were taken this tick; the run state owns the running total.
func step(ball: Vector3, delta: float) -> int:
	_spin += delta * 2.4
	var taken := 0
	var i := _items.size() - 1
	while i >= 0:
		var item := _items[i]
		var offset := ball - item.global_position
		var distance := offset.length()
		if distance <= COLLECT:
			_items.remove_at(i)
			item.queue_free()
			taken += 1
		else:
			if distance < MAGNET:
				var pull := PULL * (1.0 - distance / MAGNET)
				item.global_position += offset / distance * pull * delta
			item.rotation = Vector3(_spin * 0.7, _spin, 0.0)
		i -= 1
	return taken


func _add(at: Vector3) -> void:
	var item := MeshInstance3D.new()
	item.mesh = _mesh
	item.material_override = _material
	item.position = at
	add_child(item)
	_items.append(item)
