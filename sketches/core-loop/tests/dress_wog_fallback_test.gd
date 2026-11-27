extends "res://tests/dress_wog_test.gd"

class Warnings extends Logger:
	var lines: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		var message := code + rationale
		if error_type == Logger.ERROR_TYPE_WARNING and message.begins_with("spillway_scenery: missing or invalid prop finish"):
			lines.append(message)


const REACH_GREYBOX := 40


func _run() -> void:
	var warning_log := Warnings.new()
	OS.add_logger(warning_log)
	var healthy: String = Scenery.prop_shader_path
	Scenery.prop_shader_path = "res://assets/materials/wog_missing.gdshader"
	await _boot()
	var physics := []
	if game.flow != null:
		for stage in [1, 2]:
			game.flow.enter_stage(stage, Vector3.ZERO, false)
			await process_frame
			var stage_root: Node3D = game.ctx.terrain.geometry_root(stage)
			var counts := _counts(stage_root, stage)
			# 2026-10-09 swap-wave 12-F: the valve's wheel and safety ring are recipe views now (contraptions.gd _build_valve),
			# which the greybox finish skips, so Reach's greybox count is 50, not 52 (see dress_wog_test's matching re-pin).
			# 2026-11-13 W1-22 (77a2e2375) and W1-23 (PR 952, af7d9b56a): the Reach cache pocket wears cracked_cache.glb
			# (50 to 47), then the valve door and cracked walls wear their models (47 to 42); models skip the finish too.
			_require(counts.greybox == (12 if stage == 1 else REACH_GREYBOX) and counts.white == 0, "missing asset keeps today's exact greybox count")
			_snapshot(stage_root, "Stage%d" % stage, physics)
			for view in stage_root.find_children("*", "MeshInstance3D", true, false):
				_require(not view.has_meta("spillway_finish"), "missing asset never partly dresses props")
		game.world.contraptions[2].reset()
		_require(_counts(game.ctx.terrain.geometry_root(2), 2).greybox == REACH_GREYBOX, "fallback survives cache reset")
	var expected = JSON.parse_string(FileAccess.get_file_as_string(PHYSICS_BASELINE))
	_require(JSON.parse_string(JSON.stringify(physics)) == expected, "fallback keeps base collision ordering and transforms")
	_require(warning_log.lines.size() == 1, "both stages and repeated cache resets emit one warning")
	if not warning_log.lines.is_empty():
		print("wog fallback warning: " + warning_log.lines[0])
	Scenery.prop_shader_path = healthy
	var stage_root: Node3D = game.ctx.terrain.geometry_root(2)
	Scenery.dress_props(stage_root)
	var counts := _counts(stage_root, 2)
	_require(counts.greybox == 0 and counts.white == 0, "healthy path recovers without rebuilding physics")
	# Wrong resource type must take the same safe path as a missing shader.
	Scenery.prop_shader_path = "res://src/core/palette.gd"
	_require(Scenery._prop_shader() == null, "malformed asset type returns fallback")
	_require(Scenery._prop_shader() == null and warning_log.lines.size() == 2, "invalid resource also warns only once")
	Scenery.prop_shader_path = healthy
	_require(error_log.errors == 0, "fallback has no engine or script errors")
	game.free()
	OS.remove_logger(warning_log)
	OS.remove_logger(error_log)
	print("dress_wog_fallback_test: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
