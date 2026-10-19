extends RefCounted

# Perch points for the Dispatcher (design-v3/ENEMY-PRIORITY.md 4a and 6): the top of a park post
# that stands PERCH_MIN to PERCH_MAX above the ground under it. The director asks for one within
# RANGE_M of the pack it spawns. The tops come from the park file's anchor fields (their rows and
# the same clear zones park_recipes.gd keeps posts out of), so no park JSON carries a perch list.
# A park with no such post answers INF, and the Dispatcher builds its own mast where it spawns.
#
# derive() runs once per stage and lists every top sorted by (x, z); pick() is a pure function of
# that list, the point, the blockers and a salt, so one seed always gets the same perch.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")

const RANGE_M := 40.0
const PERCH_MIN := 6.0
const PERCH_MAX := 10.0
# The Dispatcher's deck is 3.6 m square (dispatcher.gd DECK_SIZE): a landform footprint within this
# of a top counts as a collider the deck would sit in.
const DECK_CLEAR := 2.5
# A perch this far from the pack is preferred, so the pack does not stand under its own spawner.
const STAND_OFF := 12.0


# Every perch top of a park: [Vector3], sorted by x then z. ground: Callable(x, z) -> float.
static func derive(park: Dictionary, ground: Callable) -> Array:
	var tops: Array = []
	var zones := ParkRecipes.clear_zones(park)
	for row: Dictionary in park.get("park_rows", []):
		if not ParkRecipes.is_anchor_field(row):
			continue
		var rise := float(row["size"][1])
		if rise < PERCH_MIN or rise > PERCH_MAX:
			continue
		for post: Vector2 in ParkRecipes.anchor_posts(row, zones):
			tops.append(Vector3(post.x, float(ground.call(post.x, post.y)) + rise, post.y))
	tops.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x or (a.x == b.x and a.z < b.z))
	return tops


# The landform colliders a perch must stay out of: every built footprint of the park (the ground
# and anchor fields excepted, and the landmark), as clear_zones() lists them.
static func blockers(park: Dictionary) -> Array:
	return ParkRecipes.clear_zones(park).filter(func(z: Dictionary) -> bool: return not z.has("a"))


# Whether a top is in band over the ground under it and clear of every blocker.
static func valid(top: Vector3, ground: Callable, blocked: Array) -> bool:
	var rise := top.y - float(ground.call(top.x, top.z))
	if rise < PERCH_MIN - 0.001 or rise > PERCH_MAX + 0.001:
		return false
	return not ParkRecipes.in_clear(blocked, Vector2(top.x, top.z), DECK_CLEAR)


# One perch top within RANGE_M of `near` (flat distance), or Vector3.INF when none qualifies.
# Tops at least STAND_OFF away win when there are any; the salt and the point choose among them.
static func pick(tops: Array, near: Vector3, ground: Callable, blocked: Array, salt := 0) -> Vector3:
	var far: Array = []
	var close: Array = []
	var from := Vector2(near.x, near.z)
	for top: Vector3 in tops:
		var d := Vector2(top.x, top.z).distance_to(from)
		if d > RANGE_M or not valid(top, ground, blocked):
			continue
		(far if d >= STAND_OFF else close).append(top)
	var pool := far if not far.is_empty() else close
	if pool.is_empty():
		return Vector3.INF
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([salt, roundi(near.x), roundi(near.z)])
	return pool[rng.randi_range(0, pool.size() - 1)]
