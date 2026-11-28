# smoke: timeout=300s
extends SceneTree

const T := preload("res://tests/support/t.gd")
const PinHash := preload("res://tests/support/pin_hash.gd")
const HeroSculptor := preload("res://src/presentation/craft/hero_kitbash_sculptor.gd")
const PilotGearKit := preload("res://src/presentation/pilot_gear_kit.gd")

const PIN := "res://tests/fixtures/pins/mesh_census.pin"
const VISTA := "res://src/presentation/craft/vista_megastructures.gd"
const BUILDERS: Array[String] = [
	"res://src/presentation/craft/camp_craft_meshes.gd",
	"res://src/presentation/craft/enemy_boss_craft.gd",
	"res://src/presentation/craft/experimental_setpiece_craft.gd",
	"res://src/presentation/craft/hero_kitbash_sculptor.gd",
	"res://src/presentation/craft_prop_meshes.gd",
	"res://src/presentation/crafted_ball_gear.gd",
	"res://src/presentation/pilot_gear_kit.gd",
	"res://src/presentation/world23_chunk_craft.gd",
]
const MIN_MESHES := 250
const FLOATS := [0.6, 0.9, 1.3, 0.45, 0.75, 1.1]
const W23_KINDS := [
	"dig_canyon_floor", "dig_crusher_lip", "dig_wall_ns", "dig_wall_ew", "dig_jump_pad", "dig_press_housing",
	"dig_coolant_tank", "dig_catwalk_ns", "dig_catwalk_ew", "dig_blast_shield", "dig_gantry_bridge", "dig_hoist_rail",
	"dig_catwalk_pier", "dig_bridge_stanchion", "dig_crane_portal", "dig_bore_derrick", "dig_derrick_beacon",
	"orbital_hull_floor", "orbital_relay_collar", "orbital_coaming_ns", "orbital_coaming_ew", "orbital_rib_arch",
	"orbital_jump_pad", "orbital_bulkhead_bay", "orbital_cryo_pod", "orbital_catwalk_ns", "orbital_catwalk_ew",
	"orbital_shield_fin", "orbital_gantry_bridge", "orbital_crane_beam", "orbital_catwalk_pier",
	"orbital_bridge_stanchion", "orbital_crane_portal", "orbital_choir_mast", "orbital_zenith_crown",
]
const SETPIECE_KINDS := [
	"basin_floor", "crucible_lip", "rim_bank_ns", "rim_bank_ew", "catwalk_span", "catwalk_side", "hard_bulkhead",
	"gantry_bridge", "crane_track", "spire_stack", "beacon_collar", "jump_pad", "compactor_housing", "cryo_pipe_tank",
]
const SHIPPED_ARGS := {
	"craft_prop_meshes.gd:gantry_column_mesh": [[1.8, 27.0, 1.8]],
	"craft_prop_meshes.gd:rescue_cage_bar": [[0.12, 3.0], [0.08, 3.0]],
	"craft_prop_meshes.gd:rescue_cage_post": [[0.3, 3.2]],
	"craft_prop_meshes.gd:rescue_cage_rail": [[3.1, 0.20], [2.8, 0.08]],
	"craft_prop_meshes.gd:survey_stake_pole": [[3.2]],
}
const PART_CALLS := [
	["cross_split", "stat"], ["spiral_wave", "stat"], ["chain_arc", "stat"], ["splice_tap", "stat"],
	["any", "weapon"], ["any", "mobility"], ["any", "class"], ["any", "milestone"], ["any", "stat"],
]

var _t := T.new("mesh_census_test")


func _initialize() -> void:
	_check_compare_fails_closed()
	var got := {}
	for path in BUILDERS:
		var before := got.size()
		_census_script(path, got)
		_t.check("census builds meshes from " + path.get_file(), got.size() > before, "%d meshes" % (got.size() - before))
	var before_vista := got.size()
	_census_vista(got)
	_t.check("census builds meshes from " + VISTA.get_file(), got.size() > before_vista, "%d meshes" % (got.size() - before_vista))
	_t.check("census builds at least %d meshes" % MIN_MESHES, got.size() >= MIN_MESHES, "%d meshes" % got.size())
	if OS.get_environment("PIN_RECORD") == "1":
		if not PinHash.can_record():
			_t.check("PIN_RECORD=1 needs %s=1 to rewrite %s" % [PinHash.ALLOW_RECORD_ENV, PIN], false)
		else:
			var out := FileAccess.open(PIN, FileAccess.WRITE)
			out.store_string(render(got))
			out.close()
			print("mesh_census: recorded %d meshes to %s" % [got.size(), PIN])
	var errors := compare(got, read_pin(PIN))
	_t.check("every crafted mesh matches the census pin byte for byte", errors.is_empty(),
		"%d differences: %s" % [errors.size(), ", ".join(errors.slice(0, 12))])
	quit(_t.verdict())


func _check_compare_fails_closed() -> void:
	var one := {"a.gd:m()": "1\tx=aa"}
	var pinned := render(one)
	_t.eq("an identical census passes", compare(one, pinned), [] as Array[String])
	_t.check("a census that built nothing fails", not compare({}, pinned).is_empty())
	_t.check("an empty pin fails", not compare(one, "").is_empty())
	_t.check("a pin of only blank lines fails", not compare(one, "\n\n").is_empty())
	_t.check("a missing pin file fails", not compare(one, read_pin("res://tests/fixtures/pins/no_such_census.pin")).is_empty())
	_t.check("a changed surface hash fails", not compare({"a.gd:m()": "1\tx=ab"}, pinned).is_empty())
	_t.check("a mesh missing from the census fails", not compare({"b.gd:m()": "1\tx=aa"}, pinned).is_empty())
	_t.check("a mesh missing from the pin fails", not compare({"a.gd:m()": "1\tx=aa", "b.gd:m()": "1\tx=aa"}, pinned).is_empty())
	_t.check("a malformed pin line fails", not compare(one, "a.gd:m()\n").is_empty())


static func read_pin(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


static func render(got: Dictionary) -> String:
	var keys := got.keys()
	keys.sort()
	var lines := PackedStringArray()
	for key in keys:
		lines.append("%s\t%s" % [key, got[key]])
	return "\n".join(lines) + "\n"


static func compare(got: Dictionary, pin_text: String) -> Array[String]:
	var errors: Array[String] = []
	if got.is_empty():
		errors.append("the census built no mesh")
	var want := {}
	for line in pin_text.split("\n", false):
		var cut := line.find("\t")
		if cut <= 0:
			errors.append("malformed pin line " + line)
			continue
		want[line.substr(0, cut)] = line.substr(cut + 1)
	if want.is_empty():
		errors.append("the pin holds no mesh")
	for key in want:
		if not got.has(key):
			errors.append("not built " + key)
		elif got[key] != want[key]:
			errors.append("changed " + key)
	for key in got:
		if not want.has(key):
			errors.append("not pinned " + key)
	return errors


func _census_script(path: String, got: Dictionary) -> void:
	var script: GDScript = load(path)
	if script == null:
		_t.check("census loads " + path, false)
		return
	for method in script.get_script_method_list():
		var name: String = method["name"]
		if name.begins_with("_") or not (int(method["flags"]) & METHOD_FLAG_STATIC):
			continue
		if not String(method["return"]["class_name"]) in ["ArrayMesh", "Mesh"]:
			continue
		for args in _arg_sets(path, method):
			var mesh = script.callv(name, args)
			_t.check("census builds %s%s" % [name, str(args)], mesh is ArrayMesh, path)
			if mesh is ArrayMesh:
				got["%s:%s%s" % [path.get_file(), name, str(args)]] = surface_line(mesh)


func _arg_sets(path: String, method: Dictionary) -> Array:
	var name: String = method["name"]
	var file := path.get_file()
	if name == "get_chunk_mesh":
		return (W23_KINDS if file == "world23_chunk_craft.gd" else SETPIECE_KINDS).map(func(k: String) -> Array: return [k])
	if name == "part_mesh":
		return PART_CALLS
	if name == "build_hero":
		return HeroSculptor.HERO_IDS.map(func(id: StringName) -> Array: return [id])
	if name == "build_gear":
		return PilotGearKit.GEAR_IDS.map(func(id: StringName) -> Array: return [id])
	var args: Array = method["args"]
	var required := args.size() - (method["default_args"] as Array).size()
	var sets := [[]]
	for k in required:
		var values := []
		match int(args[k]["type"]):
			TYPE_FLOAT:
				values = [FLOATS[k % FLOATS.size()]]
			TYPE_INT:
				values = [k + 3]
			TYPE_BOOL:
				values = [false, true]
			TYPE_VECTOR3:
				values = [Vector3(1.4, 0.9, 0.7)]
			_:
				_t.check("census has an argument for %s:%s %s" % [file, name, args[k]["name"]], false)
				return []
		var grown := []
		for prefix in sets:
			for v in values:
				grown.append(prefix + [v])
		sets = grown
	return sets + SHIPPED_ARGS.get("%s:%s" % [file, name], [])


func _census_vista(got: Dictionary) -> void:
	var vista: Node3D = load(VISTA).new()
	vista.build_all()
	for node in vista.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh is ArrayMesh:
			got["%s:%s" % [VISTA.get_file(), vista.get_path_to(mi)]] = surface_line(mi.mesh)
	vista.free()


static func surface_line(mesh: ArrayMesh) -> String:
	var parts := PackedStringArray()
	for s in mesh.get_surface_count():
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(var_to_bytes([mesh.surface_get_primitive_type(s), mesh.surface_get_format(s), mesh.surface_get_arrays(s), mesh.surface_get_blend_shape_arrays(s)]))
		parts.append("%s=%s" % [mesh.surface_get_name(s), ctx.finish().hex_encode()])
	return "%d\t%s" % [mesh.get_surface_count(), " ".join(parts)]
