extends SceneTree

const Game := preload("res://src/game.gd")
const Sequence := preload("res://src/ui/ending_sequence.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("pol_ui_ending_framing_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var seq := Sequence.new()
	game.screens.add_child(seq)
	seq.start(game)
	seq.set_process(false)
	_check_frames(seq)
	var uncached := Node3D.new()
	seq._scene.add_child(uncached)
	seq._build_uncached(uncached, 1, 1)
	_t.check("uncached Spillway includes its dam dressing", uncached.find_child("SpillwayScenery", true, false) != null)
	_t.eq("sequence duration stays 54 seconds", Sequence.TOTAL_SECONDS, 54.0)
	seq.free()
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.flow.enter_stage(4, Vector3.ZERO, false)
	game.flow.enter_stage(6, Vector3.ZERO, false)
	seq = Sequence.new()
	game.screens.add_child(seq)
	seq.start(game)
	seq.set_process(false)
	_t.eq("resumed ending uses the cached deep Dig and crown", seq.stages, [1, 4, 6])
	_check_frames(seq)
	seq.free()
	game.free()
	quit(_t.verdict())

func _check_frames(seq: Control) -> void:
	for world in 3:
		for local in [1.0, 2.5, 6.0, 11.0]:
			seq.elapsed = world * Sequence.WORLD_SECONDS + local
			seq.advance(0.0)
			var cam: Camera3D = seq.camera
			if local == 1.0:
				_t.check("world %d ending lens capped at 48 degrees" % [world + 1], cam.fov <= 48.0, str(cam.fov))
			var at: Vector3 = seq.shell.global_position
			var map = seq.game.ctx.terrain.map_for(seq.stages[world])
			_t.check("world %d camera stays above terrain" % [world + 1], cam.position.y > float(map.sample(cam.position.x, cam.position.z)[0]) + 0.5)
			var diameter: float = cam.unproject_position(at + Vector3.UP).distance_to(cam.unproject_position(at - Vector3.UP))
			_t.check("world %d time %.1f crew reads at 60 pixels or more" % [world + 1, local], diameter >= 60.0, str(diameter))
			for crew in [seq.shell, seq.companion]:
				var pixel: Vector2 = cam.unproject_position(crew.global_position)
				_t.check("world %d crew clear of caption bars" % [world + 1], not cam.is_position_behind(crew.global_position)
					and pixel.x > 80.0 and pixel.x < 1520.0 and pixel.y > 145.0 and pixel.y < 630.0, str(pixel))
			var landmark := _landmark(seq, world)
			var mark: Vector2 = cam.unproject_position(landmark)
			_t.check("world %d landmark clear of caption bars" % [world + 1], not cam.is_position_behind(landmark)
				and mark.x > 40.0 and mark.x < 1560.0 and mark.y > 130.0 and mark.y < 640.0, "%s landmark %s shell %s" % [mark, landmark, at])
			for target in [at, seq.companion.global_position, landmark]:
				var clear := true
				for step in range(1, 10):
					var ray: Vector3 = cam.position.lerp(target, step / 10.0)
					clear = clear and ray.y > float(map.sample(ray.x, ray.z)[0]) + 0.05
				_t.check("world %d terrain does not cover the subject centre" % [world + 1], clear)

func _landmark(seq: Control, world: int) -> Vector3:
	if world == 0:
		return Vector3(0.0, 66.0, 236.0)
	if world == 1:
		var stage: int = seq.stages[1]
		var source: Node = seq.game.ctx.terrain.geometry_root(stage) if seq.game.ctx.terrain.is_built(stage) else seq.worlds[1]
		var pattern := "intake_throat_*" if String(seq.game.ctx.stages.of(stage).map) == "dig_deep" else "impeller_hub_*"
		for view in source.find_children(pattern, "MultiMeshInstance3D", true, false):
			# Headless placements come from metadata, in stage coordinates before parking.
			var origins: PackedVector3Array = view.get_meta("origins")
			return origins[0] + view.multimesh.mesh.get_aabb().get_center()
		_t.check("Dig landmark exists", false)
		return Vector3.ZERO
	var map = seq.game.ctx.terrain.map_for(seq.stages[2])
	var mouth: Vector2 = map.spawn + Vector2(map.heading.x, map.heading.z) * 18.0
	return Vector3(mouth.x, float(map.sample(mouth.x, mouth.y)[0]), mouth.y)
