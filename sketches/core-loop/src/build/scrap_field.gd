extends Node3D

const Palette := preload("res://src/core/palette.gd")

# Scrap laid along the terrain's scrap lines. The magnet grows with heft (6 m times the
# square root of heft, capped at 18 m) and reaches further again the faster you roll,
# and a piece it catches homes in faster than the ball can outrun it, so taking scrap
# never asks you to slow down or turn back (momentum is sacred). A caught piece stays
# caught until it lands on the ball. Pickups never touch the ball's velocity.

const MAGNET_PER_ROOT_HEFT := 6.0
const MAGNET_CAP := 18.0
# Extra magnet reach per m/s of ball speed, on top of the capped heft reach, so a fast
# ball still catches what it passes.
const MAGNET_PER_SPEED := 0.3
const COLLECT := 2.0
const HOME_SPEED := 16.0
const HOME_OVER_BALL := 1.4
const SPACING := 8.0
const MAX_PER_LINE := 14
# A caught piece swings in on a curve (v3 W11): sideways and up at this share of its
# homing speed while far, straight in as it closes, so the pull reads as a greedy
# swirl. The homing term is unchanged, so the pull takes as long as it did.
const ARC_SIDE := 0.6
const ARC_LIFT := 0.3

var magnet_scale := 1.0
# The run's heft; build sets it every tick.
var heft := 1.0

# Recovery clusters (the durability prototype): scrap a hit spilled, each worth several
# units, ahead of or beside the ball's outgoing line. They sit in _items like any piece, so
# the magnet and the arc pull work on them, but step() reports them apart in
# recovered_values, and one nobody reaches expires after RECOVERY_LIFE seconds.
const RECOVERY_LIFE := 20.0
const RECOVERY_MAX_CLUSTERS := 6
const RECOVERY_AHEAD := Vector2(6.0, 16.0)
const RECOVERY_SIDE := 4.5
# One cluster taken back, with its scrap value. Audio chimes on it; the mass is still
# credited by build from recovered_values, and this is no pickup (no scrap_collected).
signal recovered(value: int)
# What the last step() collected and let expire, as scrap values.
var recovered_values: Array[int] = []
var expired_values: Array[int] = []

var _value := {}
var _age := {}
var _cluster_material: StandardMaterial3D
var _cluster_mesh: BoxMesh
var _items: Array[MeshInstance3D] = []
var _caught := {}
var _material: StandardMaterial3D
var _mesh: BoxMesh
var _spin := 0.0


func setup() -> void:
	_material = Palette.solid(Palette.ARC, 1.6)
	_mesh = BoxMesh.new()
	_mesh.size = Vector3(0.8, 0.8, 0.8)
	_cluster_material = Palette.solid(Palette.AMBER, 2.2)
	_cluster_mesh = BoxMesh.new()
	_cluster_mesh.size = Vector3(1.4, 1.4, 1.4)


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
	_value.clear()
	_age.clear()


func count() -> int:
	return _items.size()


# Live recovery clusters, and the scrap they hold.
func recovery_count() -> int:
	return _value.size()


func recovery_value() -> int:
	var total := 0
	for v in _value.values():
		total += int(v)
	return total


# Lays `amount` out as at most `count` valued clusters ahead of and beside `heading`, on
# the ground. Never touches the ball: a spill is something to roll through, not a stop.
func drop_recovery(terrain, from: Vector3, heading: Vector3, amount: int, count: int, rng: RandomNumberGenerator) -> void:
	var n := clampi(mini(count, RECOVERY_MAX_CLUSTERS), 0, amount)
	if n <= 0:
		return
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	if flat.length() < 0.1:
		flat = Vector3.FORWARD
	var side := flat.cross(Vector3.UP).normalized()
	var base := amount / n
	var extra := amount - base * n
	for i in n:
		var t := (i + 0.5) / float(n)
		var ahead := lerpf(RECOVERY_AHEAD.x, RECOVERY_AHEAD.y, rng.randf())
		var lateral := (t * 2.0 - 1.0) * RECOVERY_SIDE + rng.randf_range(-1.0, 1.0)
		var spot := from + flat * ahead + side * lateral
		var item := _add(terrain.drop_point(spot.x, spot.z, 1.4) if terrain != null else spot, _cluster_mesh, _cluster_material)
		_value[item] = base + (1 if i < extra else 0)
		_age[item] = 0.0


func drop(at: Vector3, amount: int, rng: RandomNumberGenerator) -> void:
	for i in amount:
		_add(at + Vector3(rng.randf_range(-2.0, 2.0), 1.2, rng.randf_range(-2.0, 2.0)))


# The heft part of the reach, monotonic in heft and capped at 18 m.
func heft_reach() -> float:
	return minf(MAGNET_CAP, MAGNET_PER_ROOT_HEFT * sqrt(maxf(1.0, heft)) * magnet_scale)


func magnet_reach(ball_speed: float) -> float:
	return heft_reach() + MAGNET_PER_SPEED * ball_speed


# Pull scales by the same factor as the reach.
func pull_scale() -> float:
	return heft_reach() / MAGNET_PER_ROOT_HEFT


# Scrap scattered along a line, for a Warden's payout thrown toward the gates.
func drop_line(at: Vector3, heading: Vector3, length: float, amount: int, rng: RandomNumberGenerator) -> void:
	var flat := Vector3(heading.x, 0.0, heading.z).normalized()
	for i in amount:
		var t := (i + 0.5) / float(maxi(1, amount))
		_add(at + flat * length * t + Vector3(rng.randf_range(-1.5, 1.5), 1.2, rng.randf_range(-1.5, 1.5)))


# Returns where each piece was taken this tick; the run state owns the total.
func step(ball: Vector3, ball_speed: float, delta: float) -> Array[Vector3]:
	_spin += delta * 2.4
	recovered_values.clear()
	expired_values.clear()
	var taken: Array[Vector3] = []
	var reach := magnet_reach(ball_speed)
	var home := (HOME_SPEED + ball_speed * HOME_OVER_BALL) * pull_scale()
	var i := _items.size() - 1
	while i >= 0:
		var item := _items[i]
		var offset := ball - item.global_position
		var distance := offset.length()
		if _value.has(item) and not _caught.has(item):
			_age[item] += delta
			if _age[item] >= RECOVERY_LIFE:
				expired_values.append(int(_value[item]))
				_forget(item)
				_items.remove_at(i)
				item.queue_free()
				i -= 1
				continue
		if distance <= COLLECT or (_caught.has(item) and distance <= home * delta):
			if _value.has(item):
				recovered_values.append(int(_value[item]))
				recovered.emit(int(_value[item]))
			else:
				taken.append(item.global_position)
			_forget(item)
			_items.remove_at(i)
			_caught.erase(item)
			item.queue_free()
		else:
			if distance < reach and not _caught.has(item):
				# The bot supplies a spawn-order sign; player runs retain their existing swirl.
				_caught[item] = float(item.get_meta("bot_side", 1.0 if item.get_instance_id() % 2 == 0 else -1.0))
			if _caught.has(item):
				var far := clampf(distance / reach, 0.0, 1.0)
				var side := offset.cross(Vector3.UP)
				side = side.normalized() * float(_caught[item]) if side.length() > 0.01 else Vector3.ZERO
				item.global_position += (offset / distance + side * ARC_SIDE * far + Vector3.UP * ARC_LIFT * far) * home * delta
				item.scale = Vector3.ONE * clampf(distance / reach, 0.45, 1.0)
			item.rotation = Vector3(_spin * 0.7, _spin, 0.0)
		i -= 1
	return taken


func _forget(item: MeshInstance3D) -> void:
	_value.erase(item)
	_age.erase(item)


func _add(at: Vector3, mesh: Mesh = null, material: Material = null) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh if mesh != null else _mesh
	item.material_override = material if material != null else _material
	item.position = at
	add_child(item)
	_items.append(item)
	return item
