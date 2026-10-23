extends RefCounted

# A park's baked ground as a (x, z) -> float Callable, read from assets/park/<map>/ without a Terrain or a scene
# (the same heights terrain.gd's height() reads: park_terrain.gd's ground.bin, hole floors from under.bin).
# Also the pack points the director's ring would draw around a ball on the park's authored lines.

const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Terrain := preload("res://src/world/terrain.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const Director := preload("res://src/world/director.gd")


# The ground Callable of park map `id` (e.g. "park_dam"), or an invalid Callable when it has no bake.
static func ground(id: String) -> Callable:
	if not ParkTerrain.has_bake(id):
		return Callable()
	var dir := ParkTerrain.bake_dir(id)
	var heights := _zstd(dir + "/ground.bin", ParkTerrain.SIDE * ParkTerrain.SIDE * 4).to_float32_array()
	var holes := FileAccess.get_file_as_bytes(dir + "/holes.bin")
	var floors := FileAccess.get_file_as_bytes(dir + "/under.bin").to_float32_array()
	var under := PackedFloat32Array()
	under.resize(ParkTerrain.CELLS * ParkTerrain.CELLS)
	var n := 0
	for k in holes.size():
		if holes[k] == 1:
			under[k] = floors[n]
			n += 1
	return Terrain._park_floor_at.bind(heights, holes, under)


static func _zstd(path: String, size: int) -> PackedByteArray:
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(size)
	file.close()
	return bytes


# `count` pack points: a ball is put at a seeded spot on a seeded authored line (the park's lane legs:
# the waymark chain and every route leg), and the director's ring is drawn around it as spawn_spot draws
# it (director.gd AHEAD_SHARE, AHEAD_CONE, AHEAD_RANGE and FLANK_RANGE, heading along the leg, clamped
# to the play rect, at least MIN_GAP from the ball). [Vector3] at y 0.
static func pack_points(park: Dictionary, count: int, seed_value := 1) -> Array:
	var legs: Array = []
	for zone: Dictionary in ParkRecipes.clear_zones(park):
		if zone.has("a"):
			legs.append(zone)
	var r: Array = park["play_rect"]
	var play := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	var guard := 0
	while out.size() < count and guard < count * 50 and not legs.is_empty():
		guard += 1
		var leg: Dictionary = legs[rng.randi_range(0, legs.size() - 1)]
		var a: Vector2 = leg["a"]
		var b: Vector2 = leg["b"]
		var ball := a.lerp(b, rng.randf())
		var heading := (b - a).normalized() if a.distance_to(b) > 0.1 else Vector2.RIGHT
		var ahead := rng.randf() < Director.AHEAD_SHARE
		var angle: float
		var dist: float
		if ahead:
			angle = rng.randf_range(-Director.AHEAD_CONE, Director.AHEAD_CONE)
			dist = rng.randf_range(Director.AHEAD_RANGE.x, Director.AHEAD_RANGE.y)
		else:
			angle = rng.randf_range(Director.AHEAD_CONE, PI) * (1.0 if rng.randf() < 0.5 else -1.0)
			dist = rng.randf_range(Director.FLANK_RANGE.x, Director.FLANK_RANGE.y)
		var spot := ball + heading.rotated(angle) * dist
		spot.x = clampf(spot.x, play.position.x, play.end.x)
		spot.y = clampf(spot.y, play.position.y, play.end.y)
		if spot.distance_to(ball) >= Director.MIN_GAP:
			out.append(Vector3(spot.x, 0.0, spot.y))
	return out
