# smoke: timeout=300s
extends SceneTree

const T := preload("res://tests/support/t.gd")
const PinHash := preload("res://tests/support/pin_hash.gd")
const HeroSculptor := preload("res://src/presentation/craft/hero_kitbash_sculptor.gd")
const PilotGearKit := preload("res://src/presentation/pilot_gear_kit.gd")
const CraftedGear := preload("res://src/presentation/crafted_ball_gear.gd")

const PIN := "res://tests/fixtures/pins/mesh_census.pin"
const PLATFORM_LINE := "# recorded on "
const RECORDING_PLATFORMS: Array[String] = ["macOS arm64"]
const OTHER_PLATFORMS: Array[String] = ["Linux x86_64"]
const NO_INDEX := "none"
const TOLERANCE := {
	Mesh.ARRAY_VERTEX: 0.0001,
	Mesh.ARRAY_NORMAL: 0.0001,
	Mesh.ARRAY_TANGENT: 0.003,
	Mesh.ARRAY_COLOR: 0.0001,
	Mesh.ARRAY_TEX_UV: 0.0001,
	Mesh.ARRAY_TEX_UV2: 0.0001,
}
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
const SUMMED: Array[int] = [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]
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
	var meshes := {}
	for path in BUILDERS:
		var before := got.size()
		_census_script(path, got, meshes)
		_t.check("census builds meshes from " + path.get_file(), got.size() > before, "%d meshes" % (got.size() - before))
	var before_vista := got.size()
	_census_vista(got, meshes)
	_t.check("census builds meshes from " + VISTA.get_file(), got.size() > before_vista, "%d meshes" % (got.size() - before_vista))
	_t.check("census builds at least %d meshes" % MIN_MESHES, got.size() >= MIN_MESHES, "%d meshes" % got.size())
	if OS.get_environment("PIN_RECORD") == "1":
		_record(got)
	var pin_text := read_pin(PIN)
	var recorded_on := pin_platform(pin_text)
	_t.check("the census pin names the platform it was recorded on", recorded_on != "", PIN)
	var mode := comparison_mode(recorded_on, platform())
	_t.check("the census pin was recorded on a known platform and is read on a known platform", mode != "",
		"the pin's first line names %s and this is %s; a pin recorded on one of %s must be read there, or on one of %s"
		% [recorded_on, platform(), str(RECORDING_PLATFORMS), str(OTHER_PLATFORMS)])
	if mode == "exact":
		var exact := compare(got, pin_text, true)
		_t.check("every crafted mesh matches the census pin byte for byte (recorded on %s)" % recorded_on, exact.is_empty(),
			"%d differences: %s" % [exact.size(), ", ".join(exact.slice(0, 12))])
	elif mode == "tolerant":
		_t.skip("every crafted mesh matches the census pin byte for byte", "the pin was recorded on %s and this is %s" % [recorded_on, platform()])
	var worst := {}
	var close := compare(got, pin_text, false, worst)
	_t.check("every crafted mesh matches the census pin's counts, and its sums within the tolerance of each array", close.is_empty(),
		"%d differences: %s" % [close.size(), ", ".join(close.slice(0, 12))])
	var spread := PackedStringArray()
	for a in SUMMED:
		spread.append("array %d %.9f of %s" % [a, worst.get(a, 0.0), TOLERANCE[a]])
	print("mesh_census: largest sum difference from the pin on %s: %s" % [platform(), ", ".join(spread)])
	_check_real_changes_fail(got, meshes, pin_text, mode)
	quit(_t.verdict())


func _record(got: Dictionary) -> void:
	if not PinHash.can_record():
		_t.check("PIN_RECORD=1 needs %s=1 to rewrite %s" % [PinHash.ALLOW_RECORD_ENV, PIN], false)
		return
	if not platform() in RECORDING_PLATFORMS:
		_t.check("the census pin is recorded only on one of %s" % str(RECORDING_PLATFORMS), false, "this is " + platform())
		return
	var out := FileAccess.open(PIN, FileAccess.WRITE)
	if out == null:
		_t.check("census pin opens for writing", false, "%s: error %d" % [PIN, FileAccess.get_open_error()])
		return
	out.store_string(render(got, platform()))
	out.close()
	print("mesh_census: recorded %d meshes on %s to %s" % [got.size(), platform(), PIN])


static func platform() -> String:
	return "%s %s" % [OS.get_name(), Engine.get_architecture_name()]


static func comparison_mode(recorded_on: String, here: String) -> String:
	if not recorded_on in RECORDING_PLATFORMS:
		return ""
	if here == recorded_on:
		return "exact"
	return "tolerant" if here in OTHER_PLATFORMS else ""


func _check_compare_fails_closed() -> void:
	var base := {"name": "x", "sha": "aa", "index": "ab12", "counts": [4, 1, 3, 3, 0], "sums":{Mesh.ARRAY_VERTEX: [1.0, 2.0, 3.0], Mesh.ARRAY_TANGENT: [0.5, 0.25]}}
	var one := {"a.gd:m()": [base]}
	var pinned := render(one, "Here arm")
	for exact in [true, false]:
		var mode := "byte-for-byte" if exact else "tolerant"
		_t.eq("%s: an identical census passes" % mode, compare(one, pinned, exact), [] as Array[String])
		_t.check("%s: a census that built nothing fails" % mode, not compare({}, pinned, exact).is_empty())
		_t.check("%s: an empty pin fails" % mode, not compare(one, "", exact).is_empty())
		_t.check("%s: a pin of only blank lines fails" % mode, not compare(one, "\n\n", exact).is_empty())
		_t.check("%s: a pin with no platform line fails" % mode, not compare(one, pinned.substr(pinned.find("\n") + 1), exact).is_empty())
		_t.check("%s: a missing pin file fails" % mode, not compare(one, read_pin("res://tests/fixtures/pins/no_such_census.pin"), exact).is_empty())
		_t.check("%s: a mesh missing from the census fails" % mode, not compare({"b.gd:m()": [base]}, pinned, exact).is_empty())
		_t.check("%s: a mesh missing from the pin fails" % mode, not compare({"a.gd:m()": [base], "b.gd:m()": [base]}, pinned, exact).is_empty())
		_t.check("%s: a malformed pin line fails" % mode, not compare(one, PLATFORM_LINE + "Here arm\na.gd:m()\n", exact).is_empty())
		_t.check("%s: a changed count fails" % mode, not compare({"a.gd:m()": [_with(base, "counts", [4, 1, 3, 6, 0])]}, pinned, exact).is_empty())
		_t.check("%s: a lost surface fails" % mode, not compare({"a.gd:m()": []}, pinned, exact).is_empty())
		_t.check("%s: a renamed surface fails" % mode, not compare({"a.gd:m()": [_with(base, "name", "y")]}, pinned, exact).is_empty())
		_t.check("%s: a position sum moved by 0.001 fails" % mode, not compare({"a.gd:m()": [_with(base, "sums", {Mesh.ARRAY_VERTEX: [1.001, 2.0, 3.0], Mesh.ARRAY_TANGENT: [0.5, 0.25]})]}, pinned, exact).is_empty())
		_t.check("%s: a tangent sum moved by 0.05 fails" % mode, not compare({"a.gd:m()": [_with(base, "sums", {Mesh.ARRAY_VERTEX: [1.0, 2.0, 3.0], Mesh.ARRAY_TANGENT: [0.55, 0.25]})]}, pinned, exact).is_empty())
		_t.check("%s: a lost array fails" % mode, not compare({"a.gd:m()": [_with(base, "sums", {Mesh.ARRAY_VERTEX: [1.0, 2.0, 3.0]})]}, pinned, exact).is_empty())
		_t.check("%s: a changed index array fails" % mode, not compare({"a.gd:m()": [_with(base, "index", "ab13")]}, pinned, exact).is_empty())
		_t.check("%s: an index array lost fails" % mode, not compare({"a.gd:m()": [_with(base, "index", NO_INDEX)]}, pinned, exact).is_empty())
	_t.eq("a pin recorded on macOS arm64 is read byte for byte there", comparison_mode("macOS arm64", "macOS arm64"), "exact")
	_t.eq("a pin recorded on macOS arm64 is read by its counts and sums on Linux x86_64", comparison_mode("macOS arm64", "Linux x86_64"), "tolerant")
	_t.eq("a pin recorded on macOS arm64 read on an unknown platform fails", comparison_mode("macOS arm64", "macOS x86_64"), "")
	_t.eq("a pin recorded on macOS arm64 read on a renamed platform fails", comparison_mode("macOS arm64", "Linux x86_64 v2"), "")
	_t.eq("a pin whose first line has a typo fails on the recording platform", comparison_mode("macos arm64", "macOS arm64"), "")
	_t.eq("a pin whose first line has a typo fails on Linux", comparison_mode("macos arm64", "Linux x86_64"), "")
	_t.eq("a pin recorded on Linux fails, read there or elsewhere", [comparison_mode("Linux x86_64", "Linux x86_64"), comparison_mode("Linux x86_64", "macOS arm64")], ["", ""])
	_t.eq("a pin with no platform line fails", comparison_mode("", "Linux x86_64"), "")
	_t.check("byte-for-byte: a changed surface hash fails", not compare({"a.gd:m()": [_with(base, "sha", "ab")]}, pinned, true).is_empty())
	var noise := {Mesh.ARRAY_VERTEX: [1.0 + 1e-7, 2.0 - 3e-7, 3.0 + 2e-6], Mesh.ARRAY_TANGENT: [0.5 + 8e-4, 0.25 - 1e-6]}
	_t.check("byte-for-byte: sums off by last-bit noise fail", not compare({"a.gd:m()": [_with(base, "sums", noise)]}, pinned, true).is_empty())
	_t.eq("tolerant: a changed surface hash alone passes", compare({"a.gd:m()": [_with(base, "sha", "ab")]}, pinned, false), [] as Array[String])
	_t.eq("tolerant: sums off by last-bit noise pass", compare({"a.gd:m()": [_with(base, "sums", noise)]}, pinned, false), [] as Array[String])
	_t.eq("pin_platform reads the platform line", pin_platform(pinned), "Here arm")


func _check_real_changes_fail(got: Dictionary, meshes: Dictionary, pin_text: String, mode: String) -> void:
	var key := "crafted_ball_gear.gd:bolt_dart_mesh[]"
	var mesh: ArrayMesh = meshes.get(key)
	if not _t.check("the census holds %s to change" % key, mesh != null):
		return
	var moved := mesh.surface_get_arrays(0)
	if not _t.check("%s is indexed" % key, moved[Mesh.ARRAY_INDEX] != null):
		return
	var index: PackedInt32Array = moved[Mesh.ARRAY_INDEX]
	var vertices: PackedVector3Array = moved[Mesh.ARRAY_VERTEX]
	vertices[index[0]] += Vector3(0.001, 0.0, 0.0)
	moved[Mesh.ARRAY_VERTEX] = vertices
	_check_change_fails(got, mesh, key, moved, "a vertex moved by 0.001", " sum ", pin_text, mode)
	var flipped := mesh.surface_get_arrays(0)
	var winding: PackedInt32Array = flipped[Mesh.ARRAY_INDEX]
	var second := winding[1]
	winding[1] = winding[2]
	winding[2] = second
	flipped[Mesh.ARRAY_INDEX] = winding
	_check_change_fails(got, mesh, key, flipped, "its first triangle's winding flipped", " index ", pin_text, mode)


func _check_change_fails(got: Dictionary, mesh: ArrayMesh, key: String, arrays: Array, change: String, why: String, pin_text: String, mode: String) -> void:
	var records := surface_records(mesh)
	records[0] = surface_record(mesh.surface_get_name(0), mesh.surface_get_primitive_type(0), mesh.surface_get_format(0),
		arrays, mesh.surface_get_blend_shape_arrays(0))
	var census := got.duplicate()
	census[key] = records
	if mode == "exact":
		_t.eq("%s with %s fails the byte-for-byte comparison" % [key, change], compare(census, pin_text, true), ["changed " + key] as Array[String])
	var close := compare(census, pin_text, false)
	_t.check("%s with %s fails the tolerant comparison, on its %s" % [key, change, why.strip_edges()],
		close.size() == 1 and close[0].begins_with("changed " + key) and close[0].contains(why), str(close))


static func _with(record: Dictionary, field: String, value) -> Dictionary:
	var out := record.duplicate(true)
	out[field] = value
	return out


static func read_pin(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


static func pin_platform(pin_text: String) -> String:
	var first := pin_text.get_slice("\n", 0)
	return first.trim_prefix(PLATFORM_LINE).strip_edges() if first.begins_with(PLATFORM_LINE) else ""


static func render(got: Dictionary, recorded_on: String) -> String:
	var keys := got.keys()
	keys.sort()
	var lines := PackedStringArray([PLATFORM_LINE + recorded_on])
	for key in keys:
		lines.append(_render_line(key, got[key]))
	return "\n".join(lines) + "\n"


static func _render_line(key: String, surfaces: Array) -> String:
	var parts := PackedStringArray()
	for record in surfaces:
		var counts := PackedStringArray()
		for c in record["counts"]:
			counts.append(str(c))
		var arrays := PackedStringArray()
		var by_array: Dictionary = record["sums"]
		var ids := by_array.keys()
		ids.sort()
		for a in ids:
			var sums := PackedStringArray()
			for x in by_array[a]:
				sums.append("%.9f" % x)
			arrays.append("%d:%s" % [a, ",".join(sums)])
		parts.append("%s=%s=%s=%s=%s" % [record["name"], record["sha"], record["index"], ",".join(counts), ";".join(arrays)])
	return "%s\t%d\t%s" % [key, surfaces.size(), " ".join(parts)]


static func _parse_line(line: String) -> Variant:
	var cells := line.split("\t")
	if cells.size() != 3 or cells[0] == "" or not cells[1].is_valid_int():
		return null
	var surfaces := []
	for part in cells[2].split(" ", false):
		var fields := part.split("=")
		if fields.size() != 5 or fields[2] == "":
			return null
		var counts := []
		for c in fields[3].split(",", false):
			if not c.is_valid_int():
				return null
			counts.append(int(c))
		var sums := {}
		for block in fields[4].split(";", false):
			var head := block.get_slice(":", 0)
			if block.get_slice_count(":") != 2 or not head.is_valid_int():
				return null
			var values := []
			for x in block.get_slice(":", 1).split(",", false):
				if not x.is_valid_float():
					return null
				values.append(float(x))
			sums[int(head)] = values
		surfaces.append({"name": fields[0], "sha": fields[1], "index": fields[2], "counts": counts, "sums": sums})
	if surfaces.size() != int(cells[1]):
		return null
	return [cells[0], surfaces]


static func compare(got: Dictionary, pin_text: String, exact: bool, worst := {}) -> Array[String]:
	var errors: Array[String] = []
	if got.is_empty():
		errors.append("the census built no mesh")
	if pin_platform(pin_text) == "":
		errors.append("the pin names no platform")
	var want := {}
	var raw := {}
	var lines := pin_text.split("\n", false)
	for i in range(1, lines.size()):
		var parsed = _parse_line(lines[i])
		if parsed == null:
			errors.append("malformed pin line " + lines[i].left(80))
			continue
		want[parsed[0]] = parsed[1]
		raw[parsed[0]] = lines[i]
	if want.is_empty():
		errors.append("the pin holds no mesh")
	for key in want:
		if not got.has(key):
			errors.append("not built " + key)
		elif exact:
			if _render_line(key, got[key]) != raw[key]:
				errors.append("changed " + key)
		else:
			var why := _close(got[key], want[key], worst)
			if why != "":
				errors.append("changed %s (%s)" % [key, why])
	for key in got:
		if not want.has(key):
			errors.append("not pinned " + key)
	return errors


static func _close(have: Array, want: Array, worst: Dictionary) -> String:
	if have.size() != want.size():
		return "%d surfaces, pinned %d" % [have.size(), want.size()]
	var why := ""
	for s in have.size():
		var a: Dictionary = have[s]
		var b: Dictionary = want[s]
		if a["name"] != b["name"]:
			return "surface %d is named %s, pinned %s" % [s, a["name"], b["name"]]
		if a["counts"] != b["counts"]:
			return "surface %d counts %s, pinned %s" % [s, str(a["counts"]), str(b["counts"])]
		if a["index"] != b["index"]:
			return "surface %d index array hashes to %s, pinned %s" % [s, a["index"], b["index"]]
		var sa: Dictionary = a["sums"]
		var sb: Dictionary = b["sums"]
		var ka := sa.keys()
		var kb := sb.keys()
		ka.sort()
		kb.sort()
		if ka != kb:
			return "surface %d sums arrays %s, pinned %s" % [s, str(ka), str(kb)]
		for id in ka:
			var va: Array = sa[id]
			var vb: Array = sb[id]
			if va.size() != vb.size():
				return "surface %d array %d has %d sums, pinned %d" % [s, id, va.size(), vb.size()]
			for k in va.size():
				var d := absf(float(va[k]) - float(vb[k]))
				worst[id] = maxf(float(worst.get(id, 0.0)), d)
				if why == "" and not d <= float(TOLERANCE.get(id, 0.0)):
					why = "surface %d array %d sum %d differs by %.9f" % [s, id, k, d]
	return why


static func surface_records(mesh: ArrayMesh) -> Array:
	var out := []
	for s in mesh.get_surface_count():
		out.append(surface_record(mesh.surface_get_name(s), mesh.surface_get_primitive_type(s), mesh.surface_get_format(s),
			mesh.surface_get_arrays(s), mesh.surface_get_blend_shape_arrays(s)))
	return out


static func surface_record(surface_name: String, primitive: int, format: int, arrays: Array, blend_shapes: Array) -> Dictionary:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([primitive, format, arrays, blend_shapes]))
	var vertex_count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var index = arrays[Mesh.ARRAY_INDEX]
	var corners := PackedInt32Array()
	var index_hash := NO_INDEX
	if index != null:
		corners = index
		var index_ctx := HashingContext.new()
		index_ctx.start(HashingContext.HASH_SHA256)
		index_ctx.update(corners.to_byte_array())
		index_hash = index_ctx.finish().hex_encode()
	else:
		corners.resize(vertex_count)
		for c in vertex_count:
			corners[c] = c
	var sums := {}
	for a in SUMMED:
		if arrays[a] != null:
			sums[a] = _corner_sums(arrays[a], corners)
	return {
		"name": surface_name,
		"sha": ctx.finish().hex_encode(),
		"index": index_hash,
		"counts": [primitive, format, vertex_count, corners.size(), blend_shapes.size()],
		"sums": sums,
	}


static func _corner_sums(values, corners: PackedInt32Array) -> Array:
	var width := 1
	match typeof(values):
		TYPE_PACKED_VECTOR3_ARRAY:
			width = 3
		TYPE_PACKED_VECTOR2_ARRAY:
			width = 2
		TYPE_PACKED_COLOR_ARRAY:
			width = 4
		TYPE_PACKED_FLOAT32_ARRAY:
			width = 4
	var plain := []
	var weighted := []
	plain.resize(width)
	plain.fill(0.0)
	weighted.resize(width)
	weighted.fill(0.0)
	var flat := typeof(values) == TYPE_PACKED_FLOAT32_ARRAY
	var n := float(maxi(corners.size(), 1))
	for c in corners.size():
		var v := corners[c]
		var w := float(c + 1) / n
		for k in width:
			var x: float = values[v * width + k] if flat else values[v][k]
			plain[k] += x
			weighted[k] += x * w
	return plain + weighted


func _census_script(path: String, got: Dictionary, meshes: Dictionary) -> void:
	var script: GDScript = load(path)
	if script == null:
		_t.check("census loads " + path, false)
		return
	for method in script.get_script_method_list():
		var name: String = method["name"]
		if name.begins_with("_") or not (int(method["flags"]) & METHOD_FLAG_STATIC):
			continue
		var ret: Dictionary = method["return"]
		if int(ret["type"]) == TYPE_NIL and int(ret["usage"]) & PROPERTY_USAGE_NIL_IS_VARIANT:
			_t.check("%s:%s declares a return type, so the census can tell whether it builds a mesh" % [path.get_file(), name], false)
			continue
		if not String(ret["class_name"]) in ["ArrayMesh", "Mesh"]:
			continue
		for args in _arg_sets(path, method):
			var mesh = script.callv(name, args)
			_t.check("census builds %s%s" % [name, str(args)], mesh is ArrayMesh, path)
			if mesh is ArrayMesh:
				var key := "%s:%s%s" % [path.get_file(), name, str(args)]
				got[key] = surface_records(mesh)
				meshes[key] = mesh


func _arg_sets(path: String, method: Dictionary) -> Array:
	var name: String = method["name"]
	var file := path.get_file()
	if name == "get_chunk_mesh":
		return (W23_KINDS if file == "world23_chunk_craft.gd" else SETPIECE_KINDS).map(func(k: String) -> Array: return [k])
	if name == "part_mesh":
		return PART_CALLS
	if name == "chunk_mesh" and file == "crafted_ball_gear.gd":
		return range(CraftedGear.CHUNK_VARIANTS.size()).map(func(i: int) -> Array: return [i])
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


func _census_vista(got: Dictionary, meshes: Dictionary) -> void:
	var vista: Node3D = load(VISTA).new()
	vista.build_all()
	for node in vista.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh is ArrayMesh:
			var key := "%s:%s" % [VISTA.get_file(), vista.get_path_to(mi)]
			got[key] = surface_records(mi.mesh)
			meshes[key] = mi.mesh
	vista.free()
