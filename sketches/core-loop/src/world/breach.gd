extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# The Dig's breakable floors as a rule: a slam landing inside an unbroken plate's rect
# breaks that plate, once per stage entry. No scene access; world.gd swaps the overlay
# and the cover box for each id slam() returns.
# plates: [{id: String, rect: Rect2(x, z, w, d), drop_to: float}] (map_dig.gd BREACH_PLATES).

# The world_fact a broken plate sends, and a copy of its WORLD_ROWS row (event_kinds.gd)
# so a test can compare them.
const FACT := "breach_opened"
const ROW := {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "breach_crack", "sound_next": "plate_crack_rubble_fall", "hud": "", "objective": "", "priority": 1}

var plates: Array = []
var broken: Array[String] = []


func _init(map_plates: Array) -> void:
	plates = map_plates


# The ids this slam breaks: every unbroken plate whose rect holds (at.x, at.z).
func slam(at: Vector3) -> Array[String]:
	var hit: Array[String] = []
	for plate in plates:
		var id: String = plate["id"]
		var r: Rect2 = plate["rect"]
		# Edges inclusive, as map_dig.gd _inside reads the cover's overlay.
		if not breached(id) and at.x >= r.position.x and at.x <= r.end.x and at.z >= r.position.y and at.z <= r.end.y:
			broken.append(id)
			hit.append(id)
	return hit


# The indices of positions whose (x, z) lies inside one of these plates' rects.
func under(ids: Array[String], positions: Array) -> Array[int]:
	var inside: Array[int] = []
	for i in positions.size():
		var at: Vector3 = positions[i]
		for plate in plates:
			var r: Rect2 = plate["rect"]
			if ids.has(plate["id"]) and at.x >= r.position.x and at.x <= r.end.x and at.z >= r.position.y and at.z <= r.end.y:
				inside.append(i)
				break
	return inside


func breached(id: String) -> bool:
	return broken.has(id)


func reset() -> void:
	broken.clear()
