extends Node3D

const Palette := preload("res://src/core/palette.gd")

# Scrap laid along the terrain's scrap lines. The magnet reaches further the faster you
# roll, and a piece it catches homes in faster than the ball can outrun it, so taking
# scrap never asks you to slow down or turn back (momentum is sacred). A caught piece
# stays caught until it lands on the ball.

const MAGNET := 7.0
# Extra magnet reach per m/s of ball speed: at 30 m/s the reach is about 16 m.
const MAGNET_PER_SPEED := 0.3
const COLLECT := 2.0
const HOME_SPEED := 16.0
const HOME_OVER_BALL := 1.4
const SPACING := 8.0
const MAX_PER_LINE := 14

var magnet_scale := 1.0

var _items: Array[MeshInstance3D] = []
var _caught := {}
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
	_caught.clear()


func count() -> int:
	return _items.size()


func drop(at: Vector3, amount: int, rng: RandomNumberGenerator) -> void:
	for i in amount:
		_add(at + Vector3(rng.randf_range(-2.0, 2.0), 1.2, rng.randf_range(-2.0, 2.0)))


func magnet_reach(ball_speed: float) -> float:
	return (MAGNET + MAGNET_PER_SPEED * ball_speed) * magnet_scale


# Returns where each piece was taken this tick; the run state owns the total.
func step(ball: Vector3, ball_speed: float, delta: float) -> Array[Vector3]:
	_spin += delta * 2.4
	var taken: Array[Vector3] = []
	var reach := magnet_reach(ball_speed)
	var home := HOME_SPEED + ball_speed * HOME_OVER_BALL
	var i := _items.size() - 1
	while i >= 0:
		var item := _items[i]
		var offset := ball - item.global_position
		var distance := offset.length()
		if distance <= COLLECT or (_caught.has(item) and distance <= home * delta):
			taken.append(item.global_position)
			_items.remove_at(i)
			_caught.erase(item)
			item.queue_free()
		else:
			if distance < reach:
				_caught[item] = true
			if _caught.has(item):
				item.global_position += offset / distance * home * delta
				item.scale = Vector3.ONE * clampf(distance / reach, 0.45, 1.0)
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
