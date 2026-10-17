extends SceneTree

const Ctx := preload("res://src/core/context.gd")
const Flow := preload("res://src/core/flow.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Audio := preload("res://src/presentation/audio.gd")
const RunState := preload("res://src/core/run_state.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# Audio's startup jobs must finish and let the process quit on a small worker pool. The
# parent writes a scratch project whose override.cfg caps the pool, runs this same script
# in it as a child under `timeout`, and reads the exit code. At base the bake held the one
# low-priority slot, the ACE load queued behind it, and the process hung at quit (124).

const CHILD_FLAG := "--audio-pool-child"
const POOL_SIZES := [2, 4]
const CHILD_TIMEOUT_SECONDS := 60

var _t := T.new("audio_pool_small_test")


func _initialize() -> void:
	if OS.get_cmdline_user_args().has(CHILD_FLAG):
		quit(_child())
		return
	for size in POOL_SIZES:
		_run_parent(size)
	quit(_t.verdict())


# Starts Audio the way a game does, leaves the tree before the bake lands, and quits.
func _child() -> int:
	var events := GameEvents.new()
	root.add_child(events)
	var ctx := Ctx.new()
	ctx.events = events
	ctx.run = RunState.new(events)
	ctx.tuning = Tuning.new()
	ctx.stages = StageDefs
	ctx.flow = Flow.new()
	var audio := Audio.new()
	root.add_child(audio)
	audio.setup(ctx)
	audio.free()
	events.free()
	ctx.flow.free()
	return 0


func _run_parent(size: int) -> void:
	var dir := OS.get_user_data_dir().path_join("audio_pool_%d_%d" % [size, OS.get_process_id()])
	DirAccess.make_dir_recursive_absolute(dir)
	var project := FileAccess.get_file_as_string("res://project.godot")
	var out := FileAccess.open(dir.path_join("project.godot"), FileAccess.WRITE)
	out.store_string(project)
	out.close()
	var cfg := FileAccess.open(dir.path_join("override.cfg"), FileAccess.WRITE)
	cfg.store_string("[threading]\n\nworker_pool/max_threads=%d\n" % size)
	cfg.close()
	var root_dir := ProjectSettings.globalize_path("res://")
	for link in ["src", "tests", "assets", "addons"]:
		if DirAccess.dir_exists_absolute(root_dir.path_join(link)):
			OS.execute("ln", ["-s", root_dir.path_join(link), dir.path_join(link)])
	var output: Array = []
	var code := OS.execute("timeout", ["-k", "5", str(CHILD_TIMEOUT_SECONDS), OS.get_executable_path(),
			"--headless", "--path", dir, "--script", "res://tests/audio_pool_small_test.gd", "--", CHILD_FLAG], output, true)
	_t.eq("a %d-thread pool: the child quits with exit 0, not the timeout's 124" % size, code, 0)
	# Links and files only; remove_absolute on a link drops the link, never its target.
	for entry in DirAccess.get_files_at(dir) + DirAccess.get_directories_at(dir):
		DirAccess.remove_absolute(dir.path_join(entry))
	DirAccess.remove_absolute(dir)
