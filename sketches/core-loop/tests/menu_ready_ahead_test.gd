extends SceneTree

const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Terrain := preload("res://src/world/terrain.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const T := preload("res://tests/support/t.gd")

# The setup work taken off the menu-ready path (MENU-READY, cloud exported build): the workshop sky
# painted on a worker (PaletteMaterials.workshop_sky_later) is the panorama a direct paint makes, and the park
# table's files read on worker threads together (Terrain._read_parks_together) are the maps a read
# one after another makes.

var _t := T.new("menu_ready_ahead_test")


func _initialize() -> void:
	_check_sky.call_deferred()


func _check_sky() -> void:
	var later := PaletteMaterials.workshop_sky_later()
	var second := PaletteMaterials.workshop_sky_later()
	_t.check("the boot's sky comes back before its panorama is painted, on a 1 px horizon colour",
		later.panorama != null and later.panorama.get_width() == 1)
	_t.check("a second ask while painting shares the one paint", PaletteMaterials._sky_waiting.size() == 2 and PaletteMaterials._sky_task >= 0)
	for frame in 600:
		await process_frame
		if later.panorama.get_width() > 1:
			break
	_t.check("the worker's panorama fills the waiting skies", later.panorama.get_width() == 1024 and second.panorama == later.panorama)
	var direct := PaletteMaterials._paint_workshop_sky()
	var painted: Image = later.panorama.get_image() if later.panorama != null else null
	_t.check("the worker painted the same image a direct paint makes",
		painted != null and painted.get_data() == direct.get_data(), "sizes %s / %s" % [painted.get_size() if painted != null else null, direct.get_size()])
	_t.check("workshop_sky hands out the painted panorama", PaletteMaterials.workshop_sky().panorama == later.panorama)
	_check_parks()
	quit(_t.verdict())


func _check_parks() -> void:
	var together := Terrain._read_parks_together(ParkDefs)
	var ids := []
	for row in ParkDefs.DEFS:
		if not ids.has(row["map"]):
			ids.append(row["map"])
	_t.eq("every park file of the table is read together", together.size(), ids.size())
	for id: String in ids:
		var map = together.get(id)
		var alone = Terrain.map_named(id, 1)
		var differ := _differ(alone, map) if map != null else ["missing"]
		_t.check("%s read together equals a read on its own" % id, map != null and map.ok and differ.is_empty(), "differ: %s" % [differ])
	var terrain := Terrain.new(ParkDefs)
	var distinct := {}
	for map in terrain.maps:
		distinct[map.get_instance_id()] = true
	_t.check("Terrain.new gives each stage row its own park map", terrain.maps.size() == ParkDefs.DEFS.size() and distinct.size() == terrain.maps.size())
	_t.check("a table with one park reads it on its own", Terrain._read_parks_together(_OnePark).is_empty())


class _OnePark:
	const DEFS := [{"stage": 1, "map": "park_dam", "world": 1}]


func _differ(a, b) -> Array:
	var out := []
	for property in a.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and str(a.get(property.name)) != str(b.get(property.name)):
			out.append(property.name)
	return out
