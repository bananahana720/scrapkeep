extends SceneTree

const Context := preload("res://src/core/context.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const T := preload("res://tests/support/t.gd")

# Context.heading() is the one call simulation code makes for the level direction the player
# faces. It returns the camera's own -yaw_basis().z bit for bit, so a caller moved onto it plays
# the same run, and the scan keeps the camera's basis out of every module but the camera, the
# spine and the context.

const ALLOWED := ["res://src/movement/chase_camera.gd", "res://src/game.gd", "res://src/core/context.gd"]
const PATTERN := "\\byaw_basis\\s*\\("

var _t := T.new("context_heading_test")


func _initialize() -> void:
	var ctx := Context.new()
	_t.eq("no camera faces forward", ctx.heading(), Vector3.FORWARD)
	var camera := ChaseCamera.new()
	ctx.camera = camera
	for yaw in [PI, 0.0, 0.5, -1.25, 2.6, 7.0]:
		camera.yaw = yaw
		var want: Vector3 = -camera.yaw_basis().z
		var got := ctx.heading()
		_t.check("yaw %s matches the camera bit for bit" % yaw, var_to_bytes(got) == var_to_bytes(want), "got %s, want %s" % [got, want])
		_t.near("yaw %s is unit length" % yaw, got.length(), 1.0)
		_t.check("yaw %s is level" % yaw, got.y == 0.0, "y %s" % got.y)
	# Pitch tilts the view, never the heading.
	camera.yaw = 0.5
	var level := ctx.heading()
	camera.pitch = -1.1
	_t.eq("pitch leaves the heading alone", ctx.heading(), level)
	# The read side of snap(heading): the yaw snap() computes for a direction reads back as it.
	for dir: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-3, 5, 4)]:
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		camera.yaw = atan2(-flat.x, -flat.z)
		_t.check("the yaw snap() sets toward %s reads back" % dir, ctx.heading().distance_to(flat) < 0.00001, "got %s, want %s" % [ctx.heading(), flat])
	camera.free()

	var re := RegEx.create_from_string(PATTERN)
	_t.check("scan self-check: a planted camera read is caught", re.search("var f := -ctx.camera.yaw_basis().z\n") != null, "planted line")
	_t.check("scan self-check: ctx.heading() passes", re.search("var f := ctx.heading()\n") == null, "the call")
	var files := 0
	var reads: Array = []
	for path in _gd_files("res://src"):
		files += 1
		if path in ALLOWED:
			continue
		var number := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			if not line.strip_edges().begins_with("#") and re.search(line) != null:
				reads.append("%s:%d" % [path, number])
	_t.check("no module reads the camera's basis; they ask ctx.heading()", reads.is_empty(), "reads %s" % [reads])
	_t.check("the scan saw files", files > 200, "%d files" % files)
	quit(_t.verdict())


func _gd_files(dir: String) -> Array:
	var out: Array = []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(sub)))
	return out
