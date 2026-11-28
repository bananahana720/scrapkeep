extends SceneTree

const Context := preload("res://src/core/context.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")
const T := preload("res://tests/support/t.gd")

# Context.heading() is the one call simulation code makes for the level direction the player
# faces. It returns the camera's own -yaw_basis().z bit for bit, so a caller moved onto it plays
# the same run, and the scan keeps yaw_basis() calls out of the simulation folders.

# The simulation folders, as profile_purity_test lists them, plus core. View code (presentation,
# ui) and the spine (game.gd) may read the camera; these may not.
const DIRS := ["src/movement", "src/combat", "src/build", "src/world", "src/boss", "src/core"]
const ALLOWED := ["res://src/movement/chase_camera.gd", "res://src/core/context.gd"]
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
	# The read side of snap(heading): face the camera down a direction and it reads back level.
	# snap() also places the camera, which needs the tree: the root is in it from the first frame.
	await process_frame
	camera.target = _Ball.new()
	get_root().add_child(camera)
	for dir: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-3, 5, 4)]:
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		camera.snap(dir)
		_t.check("snap toward %s reads back" % dir, ctx.heading().distance_to(flat) < 0.00001, "got %s, want %s" % [ctx.heading(), flat])
	get_root().remove_child(camera)
	camera.free()

	_t.check("scan self-check: a planted camera read is caught", not SourceScan.search(_t, "var f := -ctx.camera.yaw_basis().z\n", PATTERN).is_empty(), "planted line")
	_t.check("scan self-check: ctx.heading() passes", SourceScan.search(_t, "var f := ctx.heading()\n", PATTERN).is_empty(), "the call")
	var sources := SourceScan.sources(_t, DIRS.map(func(dir: String) -> String: return "res://" + dir))
	var reads: Array = []
	for path in sources:
		if path in ALLOWED:
			continue
		var number := 0
		for line in String(sources[path]).split("\n"):
			number += 1
			if not line.strip_edges().begins_with("#") and not SourceScan.search(_t, line, PATTERN).is_empty():
				reads.append("%s:%d" % [path, number])
	_t.check("no simulation module calls yaw_basis(); they ask ctx.heading()", reads.is_empty(), "reads %s" % [reads])
	_t.check("the scan saw files", sources.size() > 200, "%d files" % sources.size())
	quit(_t.verdict())


# What snap() reads of the ball.
class _Ball:
	extends RefCounted
	var state := {"velocity": Vector3.ZERO}

	func shown_position() -> Vector3:
		return Vector3.ZERO
