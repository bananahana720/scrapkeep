extends RefCounted

const Palette := preload("res://src/core/palette.gd")


const FACT := "breach_opened"
const ROW := {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "breach_crack", "sound_next": "plate_crack_rubble_fall", "hud": "", "objective": "", "priority": 1}

var plates: Array = []
var broken: Array[String] = []


func _init(map_plates: Array) -> void:
	plates = map_plates


func slam(at: Vector3) -> Array[String]:
	var hit: Array[String] = []
	for plate in plates:
		var id: String = plate["id"]
		var r: Rect2 = plate["rect"]
		if not breached(id) and at.x >= r.position.x and at.x <= r.end.x and at.z >= r.position.y and at.z <= r.end.y:
			broken.append(id)
			hit.append(id)
	return hit


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
