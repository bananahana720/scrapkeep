extends SceneTree

const Spillway := preload("res://src/world/map_spillway.gd")
const Dig := preload("res://src/world/map_dig.gd")
const RescueSites := preload("res://src/world/rescue_site.gd")

# ST5-2: each rescue cage's prompt comes from its map's site row: the Spillway frees the
# runner, the Dig frees the digger. The cage's terms and its HUD words read that row.

const WANT := {"rivet": "free the runner", "dig": "free the digger"}

var _t := preload("res://tests/support/t.gd").new("rescue_prompt_test")


func _initialize() -> void:
	for map in [Spillway.new(), Dig.new()]:
		_t.eq("%s has one rescue site" % map.get_script().resource_path.get_file(), map.rescue_sites.size(), 1)
		for row in map.rescue_sites:
			var quest := String(row["quest"])
			_t.eq("%s row prompt" % quest, String(row.get("prompt", "")), WANT.get(quest, "?"))
			var cage = RescueSites.Cage.new()
			cage.spec = row
			_t.eq("%s cage terms" % quest, cage.terms(), WANT.get(quest, "?"))
			_t.check("%s cage words carry it" % quest, cage.words().contains(WANT.get(quest, "?")), cage.words())
			cage.free()
	quit(_t.verdict())
