extends SceneTree

# The worker-race fixes (scrapkeep#241, 6343074031) keep meshes and Terrain3D regions on the main thread, behind
# ThreadGuard. Checked: on the main thread the guarded paths build and count nothing. The planted control runs this
# script again in a child with --planted, where a worker calls the park props mesh read (which instantiates a GLB)
# and the region maker: each must fail the guard's assert, count a violation and make nothing. The region's color map,
# made on the worker, must equal the one sanitize_maps would make on the main thread, and the worker's height range the one
# calc_height_range works out (on park_test's baked maps, holes included), since set_data keeps it as given, and on park_test's
# tinted ground the worker's color map must equal the setter path's, byte for byte (_tinted_color_maps). The child is its own
# process because the assert prints a SCRIPT ERROR, which fails any test that prints it.

const T := preload("res://tests/support/t.gd")
const ThreadGuard := preload("res://src/core/thread_guard.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

const GLB := "res://assets/models/highdraft/prop_bench.glb"
const PARK := "park_test"
const PLANTED_ARG := "--planted"
const LOW_M := -3.5
const HIGH_M := 12.25

var _t := T.new("thread_guard_test")


func _initialize() -> void:
	if PLANTED_ARG in OS.get_cmdline_user_args():
		_planted()
		return
	_main_thread()
	_child()
	quit(_t.verdict())


func _main_thread() -> void:
	_t.check("the main thread passes the guard", ThreadGuard.main_only("thread_guard_test main"))
	ParkProps.release_shared()
	_t.check("the park props mesh read builds on the main thread", ParkProps._mesh(GLB) != null)
	var maps := _maps()
	var region := ParkTerrain._make_region(maps)
	_t.check("the region maker builds on the main thread", region != null and region.get_location() == Vector2i(1, -1))
	# Without a range the setters work it out (set_height_map runs calc_height_range).
	_t.eq("the setters' region works out the height range of its height map", ParkTerrain._make_region(maps.slice(0, 4)).get_height_range(), Vector2(LOW_M, HIGH_M))
	_worker_ranges()
	_tinted_color_maps()
	# The worker's color map is the one sanitize_maps makes for a region without one, so the main thread's sanitize keeps it.
	var bare := ParkTerrain._make_region(_maps().slice(0, 3))
	bare.sanitize_maps()
	var given: Image = region.get_color_map() if region != null else null
	var given_data := given.get_data() if given != null else PackedByteArray()
	if region != null:
		region.sanitize_maps()
	var made: Image = bare.get_color_map()
	_t.check("the worker's color map equals the one sanitize_maps makes (format, mipmaps, every byte)", given != null and made != null
		and given.get_format() == made.get_format() and given.has_mipmaps() == made.has_mipmaps() and given_data == made.get_data(),
		"%s / %s" % [str(given), str(made)])
	# Made in the form the region keeps: one without mipmaps gets them from set_color_map, on the main thread (45 ms on the cloud).
	var fresh := ParkTerrain.color_map()
	_t.check("the worker makes the color map with its mipmaps, in the region's format", fresh.has_mipmaps() and made != null
		and fresh.get_format() == made.get_format(), "mipmaps %s, format %d" % [fresh.has_mipmaps(), fresh.get_format()])
	_t.check("the region keeps the worker's color map as given, and the sanitize keeps it", region != null and given == maps[3]
		and region.get_color_map() == given)
	# set_data leaves the region as the setters do: every field the same, the maps the very images the worker made.
	var setters := ParkTerrain._make_region(maps.slice(0, 4))
	setters.sanitize_maps()
	var differ := []
	var want: Dictionary = setters.get_data()
	var got: Dictionary = region.get_data() if region != null else {}
	for key in want:
		var same: bool = got.get(key) is Image and got[key].get_format() == want[key].get_format() and got[key].has_mipmaps() == want[key].has_mipmaps() \
			and got[key].get_data() == want[key].get_data() if want[key] is Image else got.get(key) == want[key]
		if not same:
			differ.append("%s: %s, setters %s" % [key, str(got.get(key)), str(want[key])])
	_t.check("the set_data region holds what the setters' region holds, field by field", region != null and differ.is_empty()
		and got.keys() == want.keys(), "; ".join(differ))
	_t.check("the set_data region keeps the worker's maps as given", region != null and region.get_height_map() == maps[1]
		and region.get_control_map() == maps[2])
	var map := ParkMap.new()
	map.line_within(Vector2.ZERO, 8.0)
	_t.check("park_map line_within fills its ride-line cache on the main thread", map._ride_lines != null)
	_t.eq("no violation on the main thread", ThreadGuard.violations, 0)
	ParkProps.release_shared()


# park_test's baked ground, built region by region as the worker builds it: each range it hands set_data must be the one
# calc_height_range works out from the same height map, or the region's bounds are wrong and nothing says so.
func _worker_ranges() -> void:
	var park = ParkTerrain.new()
	park.map_id = PARK
	park.baked = ParkTerrain.has_bake(PARK)
	park._load()
	var holes := 0
	var misses := []
	for location in ParkTerrain.REGIONS:
		var maps: Array = park._build_region(location)
		var control: PackedInt32Array = maps[2].get_data().to_int32_array()
		for word in control:
			holes += 1 if word & ParkTerrain.HOLE_BIT else 0
		var worked_out: Vector2 = ParkTerrain._make_region(maps.slice(0, 4)).get_height_range()
		if maps.size() < 5 or maps[4] != worked_out:
			misses.append("%s: worker %s, calc_height_range %s" % [location, str(maps[4] if maps.size() > 4 else null), worked_out])
	var baked: bool = park.baked
	park.free()
	_t.check("park_test is baked, with holes in its regions", baked and holes > 0, "%d hole pixels" % holes)
	_t.check("the worker's height range is calc_height_range's, on every region of park_test", misses.is_empty(), "; ".join(misses))


# park_test's tinted ground (surface.bin slots and the pylon-bite slopes, feathered into _tints): each region's color map
# made on the worker, as _attach_step keeps it after its sanitize, must equal byte for byte the one the setter path makes
# (the white map with the tints blitted, set_color_map, sanitize_maps). The planted control is the worker's map without
# the blit, which must differ.
func _tinted_color_maps() -> void:
	var park = ParkTerrain.new()
	park.map_id = PARK
	park.baked = ParkTerrain.has_bake(PARK)
	park._load()
	var tints: Image = park._tints
	var tinted := 0
	var misses := []
	var planted_misses := 0
	for location in ParkTerrain.REGIONS:
		var maps: Array = park._build_region(location)
		var worker := ParkTerrain._make_region(maps)
		worker.sanitize_maps()
		var setters := ParkTerrain._make_region(maps.slice(0, 3))
		setters.set_color_map(_blitted(tints, location))
		setters.sanitize_maps()
		var got: Image = worker.get_color_map()
		var want: Image = setters.get_color_map()
		if got.get_format() != want.get_format() or got.has_mipmaps() != want.has_mipmaps() or got.get_data() != want.get_data():
			misses.append("%s: %s, setters %s" % [location, str(got), str(want)])
		if want.get_data() != ParkTerrain.color_map().get_data():
			tinted += 1
		var bare := ParkTerrain._make_region(maps.slice(0, 3) + [ParkTerrain.color_map()] + maps.slice(4))
		bare.sanitize_maps()
		if bare.get_color_map().get_data() != want.get_data():
			planted_misses += 1
	park.free()
	_t.check("park_test carries tints in its regions' color maps", tints != null and tinted > 0, "%d tinted regions" % tinted)
	_t.check("the worker's tinted color map equals the setter path's, byte for byte, on every region of park_test", tints != null
		and misses.is_empty(), "; ".join(misses))
	_t.check("planted: a worker map without the blit differs from the setter path's on the tinted regions", planted_misses == tinted
		and tinted > 0, "%d of %d tinted regions differ" % [planted_misses, tinted])


# The setter path's color map for a region: white at the default alpha with the feathered tints blitted, no mipmaps
# (sanitize_maps makes them), as park_terrain.gd's _build_region made it on the stage before the worker took it.
static func _blitted(tints: Image, location: Vector2i) -> Image:
	var size := ParkTerrain.REGION_SIZE
	var inner := int(ParkTerrain.HALF)
	var color := Image.create(size, size, false, Image.FORMAT_RGBA8)
	color.fill(Color(1.0, 1.0, 1.0, float(ParkTerrain.COLOR_ALPHA_BYTE) / 255.0))
	color.blit_rect(tints, Rect2i(Vector2i.ZERO, tints.get_size()),
		Vector2i(-inner - ParkTerrain.FEATHER_MARGIN - location.x * size, -inner - ParkTerrain.FEATHER_MARGIN - location.y * size))
	return color


func _child() -> void:
	var output := []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/thread_guard_test.gd", "--", PLANTED_ARG]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	var mesh_assert := text.contains("Assertion failed: thread_guard: park_props mesh " + GLB)
	var region_assert := text.contains("Assertion failed: thread_guard: park_terrain region")
	var map_assert := text.contains("Assertion failed: thread_guard: park_map line_within")
	var nothing_made := text.contains("planted violations=3 mesh=null region=null cached=false map_cached=false")
	var detail := "" if mesh_assert and region_assert and map_assert and nothing_made else \
		"\n".join(Array(text.split("\n")).map(func(line: String): return "  > " + line))
	_t.eq("the planted child exits cleanly", code, 0)
	_t.check("a worker's park props mesh read (it instantiates the GLB) fails the assert", mesh_assert, detail)
	_t.check("a worker's region maker fails the assert", region_assert, detail)
	_t.check("a worker's park_map line_within read fails the assert", map_assert, detail)
	_t.check("all three count, and none makes or caches anything", nothing_made, detail)


func _planted() -> void:
	ParkProps.release_shared()
	var out := {}
	var maps := _maps()
	var map := ParkMap.new()
	var task := WorkerThreadPool.add_task(func():
		out["mesh"] = ParkProps._mesh(GLB)
		out["region"] = ParkTerrain._make_region(maps)
		out["line"] = map.line_within(Vector2.ZERO, 8.0), false, "thread_guard_test planted")
	WorkerThreadPool.wait_for_task_completion(task)
	print("planted violations=%d mesh=%s region=%s cached=%s map_cached=%s" % [ThreadGuard.violations, "null" if out.get("mesh") == null else "made",
		"null" if out.get("region") == null else "made", str(ParkProps._meshes.has(GLB)), str(map._ride_lines != null)])
	quit(0)


static func _maps() -> Array:
	var size := ParkTerrain.REGION_SIZE
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	heights[7] = LOW_M
	heights[size * size - 9] = HIGH_M
	return [Vector2i(1, -1), Image.create_from_data(size, size, false, Image.FORMAT_RF, heights.to_byte_array()),
		Image.create_empty(size, size, false, Image.FORMAT_RF), ParkTerrain.color_map(), Vector2(LOW_M, HIGH_M)]
