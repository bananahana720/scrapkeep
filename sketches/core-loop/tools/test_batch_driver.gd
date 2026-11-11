extends RefCounted

const ChallengeDials := preload("res://src/core/challenge_dials.gd")
const SHIM_EXTENDS := 'extends "res://tools/test_batch_shim.gd"'

var tree: SceneTree
var paths: Array
var index := -1
var started := 0
var worst := 0
var current := ""
var quit_call := RegEx.create_from_string("(?<![\\w.])quit\\(")
var frame_func := RegEx.create_from_string("(?m)^func _(physics_)?process\\(")


var physics_ticks := Engine.physics_ticks_per_second
var max_steps := Engine.max_physics_steps_per_frame
var max_fps := Engine.max_fps


func _init(owner: SceneTree, list: Array) -> void:
	tree = owner
	paths = list


func finish(code: int) -> void:
	_close.call_deferred(code)


# A solo run frees the test's nodes as the process exits, and what they print then (an await
# resumed on a freed node, say) is that test's output. The batch frees them the same way,
# without removing them first, before it closes the test's output.
func _close(code: int) -> void:
	_reset()
	print("BATCH END %s exit=%d ms=%d" % [current, code, Time.get_ticks_msec() - started])
	worst = maxi(worst, code)
	next.call_deferred()


func next() -> void:
	index += 1
	if index >= paths.size():
		tree.set_script(null)
		print("BATCH DONE %d tests" % paths.size())
		tree.quit(worst)
		return
	current = paths[index]
	var source := FileAccess.get_file_as_string("res://" + current)
	var script := GDScript.new()
	var text := source.replace("extends SceneTree", SHIM_EXTENDS)  # the first line, checked by sketch-fast
	text = frame_func.sub(quit_call.sub(text, "_batch_quit(", true), "func _batch_$1process(", true)
	script.source_code = text
	print("BATCH START %s" % current)
	started = Time.get_ticks_msec()
	if script.reload() != OK:
		finish(70)
		return
	tree.set_script(script)
	if tree.has_method("_initialize"):
		tree.call("_initialize")


func _reset() -> void:
	for child in tree.root.get_children():
		child.free()
	# The process-wide settings a test may change, back to how the process started.
	tree.paused = false
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = physics_ticks
	Engine.max_physics_steps_per_frame = max_steps
	Engine.max_fps = max_fps
	ChallengeDials.reset()
