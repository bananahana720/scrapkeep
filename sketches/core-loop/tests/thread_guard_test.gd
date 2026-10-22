extends SceneTree

# The worker-race fixes (scrapkeep#241, 6343074031) keep meshes and Terrain3D regions on the main thread, behind
# ThreadGuard. Checked: on the main thread the guarded paths build and count nothing. The planted control runs this
# script again in a child with --planted, where a worker calls the park props mesh read (which instantiates a GLB)
# and the region maker: each must fail the guard's assert, count a violation and make nothing. The child is its own
# process because the assert prints a SCRIPT ERROR, which fails any test that prints it.

const T := preload("res://tests/support/t.gd")
const ThreadGuard := preload("res://src/core/thread_guard.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")

const GLB := "res://assets/models/highdraft/prop_bench.glb"
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
	var region := ParkTerrain._make_region(_maps())
	_t.check("the region maker builds on the main thread", region != null and region.get_location() == Vector2i(1, -1))
	# set_height_map works out the range itself (_make_region no longer calls calc_height_range after it).
	_t.eq("the region's height range spans its height map", region.get_height_range() if region != null else Vector2.ZERO, Vector2(LOW_M, HIGH_M))
	_t.eq("no violation on the main thread", ThreadGuard.violations, 0)
	ParkProps.release_shared()


func _child() -> void:
	var output := []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/thread_guard_test.gd", "--", PLANTED_ARG]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	var mesh_assert := text.contains("Assertion failed: thread_guard: park_props mesh " + GLB)
	var region_assert := text.contains("Assertion failed: thread_guard: park_terrain region")
	var nothing_made := text.contains("planted violations=2 mesh=null region=null cached=false")
	# The child's output only on a failure, quoted, so its SCRIPT ERROR lines never start a line of this test's own.
	var detail := "" if mesh_assert and region_assert and nothing_made else \
		"\n".join(Array(text.split("\n")).map(func(line: String): return "  > " + line))
	_t.eq("the planted child exits cleanly", code, 0)
	_t.check("a worker's park props mesh read (it instantiates the GLB) fails the assert", mesh_assert, detail)
	_t.check("a worker's region maker fails the assert", region_assert, detail)
	_t.check("both count, and neither makes or caches anything", nothing_made, detail)


# Child only: the planted worker calls.
func _planted() -> void:
	ParkProps.release_shared()
	var out := {}
	var maps := _maps()
	var task := WorkerThreadPool.add_task(func():
		out["mesh"] = ParkProps._mesh(GLB)
		out["region"] = ParkTerrain._make_region(maps), false, "thread_guard_test planted")
	WorkerThreadPool.wait_for_task_completion(task)
	print("planted violations=%d mesh=%s region=%s cached=%s" % [ThreadGuard.violations, "null" if out.get("mesh") == null else "made",
		"null" if out.get("region") == null else "made", str(ParkProps._meshes.has(GLB))])
	quit(0)


static func _maps() -> Array:
	var size := ParkTerrain.REGION_SIZE
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	heights[7] = LOW_M
	heights[size * size - 9] = HIGH_M
	return [Vector2i(1, -1), Image.create_from_data(size, size, false, Image.FORMAT_RF, heights.to_byte_array()),
		Image.create_empty(size, size, false, Image.FORMAT_RF)]
