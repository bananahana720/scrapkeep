extends SceneTree

const T := preload("res://tests/support/t.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const Synth := preload("res://src/presentation/synth.gd")

# A live game bakes the rest of the band on a worker (audio.gd's "presentation band bake"), and
# --warm-band=1 bots then baked it again on the main thread, both cold and in step: a 4080 bot run
# died in _prepare_wobble (scrapkeep#587). Here the worker bakes from a cold cache while the main
# thread asks for the same bake: the main thread waits for the worker's pass, never runs beside it.

var _t := T.new("rest_bake_threaded_test")


func _initialize() -> void:
	_t.check("the cache starts cold", _wobbles() == 0, "%d wobbles before the bake" % _wobbles())
	var task := WorkerThreadPool.add_task(MusicPrebake.prepare_rest, true, "presentation band bake")
	var held := false
	while not WorkerThreadPool.is_task_completed(task):
		if not MusicPrebake._rest_lock.try_lock():
			held = true
			break
		MusicPrebake._rest_lock.unlock()
	_t.check("the worker holds the bake while it runs", held, "never saw the worker inside prepare_rest")
	MusicPrebake.prepare_rest()
	_t.check("a second caller waits for the worker's pass", WorkerThreadPool.is_task_completed(task),
		"the main thread's prepare_rest returned while the worker was still baking")
	WorkerThreadPool.wait_for_task_completion(task)
	_t.check("the threaded bake renders Brindle's wobbles", _wobbles() > 0, "no wob: buffer after the bake")
	quit(_t.verdict())


func _wobbles() -> int:
	return Synth._notes.keys().filter(func(key: String) -> bool: return key.begins_with("wob:")).size()
