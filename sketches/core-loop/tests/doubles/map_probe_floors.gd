extends "res://src/world/stage_map.gd"

# The Dig probe (ALPHA-PLAN P1): the smallest ZoneSchema-valid map with a flat lower
# floor and one raised overlay floor, 8 m up over a 20 m square at the origin. The
# overlay is a height (overlay_height, as map_gorge.gd) and its collider is a finished
# body the map parks or restores, as map_gorge.gd apply_swap does for a cave-in.

const FLOOR_Y := 0.0
const RAISE := 8.0
const SQUARE_HALF := 10.0
const SWAP_PARK := 400.0

var start_overlays: Array[String] = ["probe_floor"]
# id -> {"before": [Node3D], "after": [Node3D]}, the map_gorge.gd shape.
var swaps := {}


func _init() -> void:
	title = "Probe floors"
	spawn = Vector2(0.0, -60.0)
	beacon = Vector2(0.0, 60.0)
	vault = Vector2(40.0, 0.0)
	gate_slots = [{"at": Vector2(-40.0, 0.0), "facing": Vector3(0.0, 0.0, 1.0)}]


func sample(_x: float, _z: float) -> Array:
	return [FLOOR_Y, Palette.SAND]


func overlay_height(id: String, x: float, z: float, ground: float) -> float:
	if id == "probe_floor" and absf(x) <= SQUARE_HALF and absf(z) <= SQUARE_HALF:
		return ground + RAISE
	return -INF


func build_props(parent: Node3D, _ground: Callable) -> void:
	var deck := box(parent, Vector3(2.0 * SQUARE_HALF, RAISE, 2.0 * SQUARE_HALF), Vector3(0.0, FLOOR_Y + RAISE * 0.5, 0.0),
		PaletteMaterials.solid(Palette.SANDSTONE))
	deck.name = "ProbeFloor"
	deck.set_meta("home", deck.position)
	swaps = {"probe_floor": {"before": [deck], "after": []}}


func apply_swap(id: String, changed: bool) -> void:
	if not swaps.has(id):
		return
	for node in swaps[id]["after"]:
		var home: Vector3 = node.get_meta("home")
		node.position = home if changed else home + Vector3.DOWN * SWAP_PARK
		node.visible = changed
	for node in swaps[id]["before"]:
		var home: Vector3 = node.get_meta("home")
		node.position = home + Vector3.DOWN * SWAP_PARK if changed else home
		node.visible = not changed


# Keeps every swap's collider in step with the live overlay list: an overlay id that is
# gone has changed. world.gd _swap writes the two separately; this reads one from the other.
func refresh(live: Array) -> void:
	for id in swaps:
		apply_swap(id, not live.has(id))
