extends Node3D

const Palette := preload("res://src/core/palette.gd")

# Scrap laid along the terrain's scrap lines, pulled in by a short magnet and taken on
# contact, so collecting never asks you to slow down.

const MAGNET := 6.0
const COLLECT := 1.8
const PULL := 26.0
const SPACING := 8.0
const MAX_PER_LINE := 14

var _items: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _mesh: BoxMesh
var _spin := 0.0


func setup() -> void:
	_material = Palette.solid(Palette.ARC, 1.6)
	_mesh = BoxMesh.new()
	_mesh.size = Vector3(0.8, 0.8, 0.8)


func lay_out(terrain, lines: Array, density: float, rng: RandomNumberGenerator) -> void:
	clear()
	for line in lines:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var n := clampi(int(from.distance_to(to) / SPACING * density), 4, int(MAX_PER_LINE * density))
		for i in n:
			var t := (i + 0.5) / float(n)
			var spot := from.lerp(to, t)
			spot += Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
			_add(terrain.drop_point(spot.x, spot.y, 1.4))


func clear() -> void:
	for item in _items:
		item.queue_free()
	_items.clear()


func count() -> int:
	return _items.size()


func drop(at: Vector3, amount: int, rng: RandomNumberGenerator) -> void:
	for i in amount:
		_add(at + Vector3(rng.randf_range(-2.0, 2.0), 1.2, rng.randf_range(-2.0, 2.0)))


# Returns where each piece was taken this tick; the run state owns the total.
func step(ball: Vector3, delta: float) -> Array[Vector3]:
	_spin += delta * 2.4
	var taken: Array[Vector3] = []
	var i := _items.size() - 1
	while i >= 0:
		var item := _items[i]
		var offset := ball - item.global_position
		var distance := offset.length()
		if distance <= COLLECT:
			taken.append(item.global_position)
			_items.remove_at(i)
			item.queue_free()
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
