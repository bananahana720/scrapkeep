extends RefCounted
# One rule for every test that checks a granted cosmetic id: it is either in Cosmetics.PENDING_ART
# or its row's asset is registered in assets/registry.json with ships true, or it is a paint,
# which is a tint and needs no art. No test names which ids are pending, so delivering art never
# breaks a grant test.

const Cosmetics := preload("res://src/core/cosmetics.gd")
const REGISTRY := "res://assets/registry.json"

static var _shipping := {}


static func reset_for_tests() -> void:
	_shipping = {}

# Ids the rule must refuse: an unregistered id, and a real ROWS id whose asset has no ships:true
# registry entry. A rule that only asks "is it a row" accounts the second and fails.
const NEGATIVE_ROW := "companion_paint_night"
const NEGATIVES := ["trail_unregistered_probe", NEGATIVE_ROW]


static func shipping_ids() -> Dictionary:
	if _shipping.is_empty():
		var registry = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
		if registry is Dictionary:
			for entry in registry.get("assets", []):
				if entry is Dictionary and entry.has("id") and entry.get("ships", false) == true:
					_shipping[entry["id"]] = true
	return _shipping


static func accounted(id: String) -> bool:
	if Cosmetics.PENDING_ART.has(id):
		return true
	var row := Cosmetics.row(id)
	if row.get("slot", "") == "paint":
		return true
	return shipping_ids().has(String(row.get("asset", "-")))


# The ids in `ids` that are neither pending nor shipping; empty means the rule holds.
static func unaccounted(ids: Array) -> Array:
	return ids.filter(func(id): return not accounted(String(id)))
