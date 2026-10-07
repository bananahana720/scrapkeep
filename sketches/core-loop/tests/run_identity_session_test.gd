extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const RunState := preload("res://src/core/run_state.gd")
const T := preload("res://tests/support/t.gd")

# The run id's suffix seeds device and activity luck (Interact.luck_seed). It must repeat
# when the session's global seed repeats (seeded bots and tests call seed() before the game
# exists) and differ when it does not (a player's session starts from Godot's randomized
# global stream), while nothing drawn later can move it.


func _initialize() -> void:
	var t := T.new("run_identity_session_test")
	seed(42)
	var a := _first_suffix()
	seed(42)
	var b := _first_suffix()
	seed(43)
	var c := _first_suffix()
	t.check("the same session seed repeats the first run's id suffix", a == b, "%s vs %s" % [a, b])
	t.check("a different session seed gives a different first run id suffix", a != c, "%s vs %s" % [a, c])
	seed(42)
	var run = RunState.new()
	for i in 50:
		randf()
	run.begin(ClassDef.all()[0])
	t.check("global draws after the run state exists do not move the suffix", _suffix(run.run_id) == a, "%s vs %s" % [_suffix(run.run_id), a])
	quit(t.verdict())


func _first_suffix() -> String:
	var run = RunState.new()
	run.begin(ClassDef.all()[0])
	return _suffix(run.run_id)


func _suffix(run_id: String) -> String:
	return run_id.get_slice("-", run_id.get_slice_count("-") - 1)
