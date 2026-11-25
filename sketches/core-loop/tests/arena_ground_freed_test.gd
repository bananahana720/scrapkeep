extends SceneTree

# The Slag Bowl's ground query (arena.gd Ground) outlives the arena: a Brindle drone's brass
# "shift over" tag (enemy_motion.gd ShiftOverTag) holds it after exit_arena frees the bowl.
#   - while the bowl lives the query reads its ground and its rim;
#   - once the bowl is freed the query reads no floor (-INF) and contains nothing, with no call on
#     a freed object;
#   - a tag popped on that query falls through and frees itself.
# Found by the wave 46 stage integration review 3.

const Arena := preload("res://src/boss/arena.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const T := preload("res://tests/support/t.gd")


class Bowl:
	extends Node3D

	func ground(_at: Vector3) -> float:
		return 2.0

	func contains(_point: Vector3) -> bool:
		return true


var _t := T.new("arena_ground_freed_test")


func _initialize() -> void:
	await _run()
	quit(_t.verdict())


func _run() -> void:
	await process_frame
	var bowl := Bowl.new()
	root.add_child(bowl)
	var query = Arena.Ground.new(bowl)
	_t.eq("a live bowl's ground is read", query.height(1.0, 1.0), 2.0)
	_t.check("a live bowl contains its point", query.contains(Vector3.ZERO))

	var machine := Node3D.new()
	root.add_child(machine)
	machine.global_position = Vector3(0.0, 6.0, 0.0)
	var tag := EnemyMotion.pop_shift_tag(machine, "lobber", Vector3.FORWARD, Callable(query, "height"))
	_t.check("a downed drone pops its tag on the bowl's query", tag != null)
	machine.free()

	bowl.free()
	_t.check("a freed bowl reads no floor", is_inf(query.height(1.0, 1.0)) and query.height(1.0, 1.0) < 0.0, str(query.height(1.0, 1.0)))
	_t.check("a freed bowl contains nothing", not query.contains(Vector3.ZERO))

	for i in 240:
		await physics_frame
	_t.check("the tag falls through and frees itself", tag == null or not is_instance_valid(tag))
