extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SEED := 280928


func _initialize() -> void:
	call_deferred("_run")


func _xyz(at: Vector3) -> Array:
	return [at.x, at.y, at.z]


func _run() -> void:
	seed(SEED)
	var game := Game.new()
	game.table = "park"
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	if not game.ctx.tuning.sitting_earned():
		printerr("expected --profile=sitting-earned at game boot")
		quit(2)
		return
	game.ctx.rng.seed = SEED
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.run_seed = SEED
	game.run.set_max_hp(999999.0)
	for mode in ["sitting-earned", "both-options-on", "calm-with-both-on"]:
		if mode == "both-options-on":
			game.ctx.tuning.set_option("posts", "on")
			game.ctx.tuning.set_option("approach", "on")
		game.ctx.calm = mode == "calm-with-both-on"
		for stage in [1, 2]:
			game.flow.enter_stage(stage, Vector3.ZERO, false)
			for tick in 6:
				await physics_frame
			var survey = game.world.survey_posts
			var approach = game.world.bowl_approach
			var map = game.ctx.terrain.map_for(stage)
			var record := {"mode": mode, "stage": stage, "map": map.park.map,
				"run_seed": game.run.run_seed, "rng_seed": game.ctx.rng.seed,
				"posts_option": game.ctx.tuning.option("posts"), "approach_option": game.ctx.tuning.option("approach"),
				"post_rows": survey.standing.size(), "furnace": is_instance_valid(approach.furnace)}
			if not survey.standing.is_empty():
				var row: Dictionary = survey.standing[0]
				record["first_row_positions"] = row.posts.map(func(p: Node3D): return _xyz(p.global_position))
				record["route_heading_xz"] = [row.heading.x, row.heading.y]
			if record.furnace:
				record["furnace_home"] = _xyz(approach.furnace_home())
				if not approach.bridge.is_empty():
					record["weighbridge_on_approach"] = _xyz(approach.bridge.at)
					record["bridge_heading_xz"] = [approach.bridge.heading.x, approach.bridge.heading.y]
			print("PLACE_STATION ", JSON.stringify(record))
	game.free()
	quit()
