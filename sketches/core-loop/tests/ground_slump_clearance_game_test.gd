extends "res://tests/ground_slump_game_test.gd"

func _run() -> void:
	t = T.new("ground_slump_clearance_game_test")
	await super._run()

func _geometry(state: Dictionary) -> void:
	var dstate: Dictionary = game.world.events._park_states.filter(func(s): return s.row.id == "tailings_slump")[0]
	var safe_position: Vector3 = game.player.ball_position()
	var partial := fill_s * 0.25
	await _advance_for(dstate, partial)
	_sample_geometry(state, "clear partial collapse", partial)
	for predicted in [false, true]:
		var vertices: PackedVector3Array = state.overlay.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var shape = state.overlay.get_child(1).shape
		var height: float = game.ctx.terrain.height(366, 110)
		var elapsed: float = state.elapsed_s
		var margin := float(dstate.row.hold_clear_m)
		var at := Vector3(366, low_tread + collapse_depth + 10, 110)
		var velocity := Vector3.ZERO
		if predicted:
			at.x = 354.0 - margin - 10.0
			velocity.x = (366.0 - at.x) / Director.PARK_TRAVEL_S
		game.player._rigid.global_position = at
		game.player.state.velocity = velocity
		await physics_frame
		await physics_frame
		t.near("real ball placed for clearance case %s" % predicted, game.player.ball_position().x, at.x, 0.001)
		t.eq("real ball predicted velocity case %s" % predicted, game.player.state.velocity, velocity)
		await _advance_for(dstate, fill_s + 0.5)
		t.near("unsafe collapse pauses transformation time case %s" % predicted, float(state.elapsed_s), elapsed)
		t.check("unsafe collapse keeps rendered vertices case %s" % predicted, state.overlay.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == vertices)
		t.check("unsafe collapse retains collider object case %s" % predicted, state.overlay.get_child(1).shape == shape)
		t.near("unsafe collapse retains height query case %s" % predicted, game.ctx.terrain.height(366, 110), height)
		t.check("unsafe permanent collapse retains capacity case %s" % predicted, not _capacity_available(dstate))
		game.player._rigid.global_position = safe_position
		game.player.state.velocity = Vector3.ZERO
		await physics_frame
		await physics_frame
		await _advance_for(dstate, fill_s * 0.25)
		partial += fill_s * 0.25
		_sample_geometry(state, "resumed safe collapse case %s" % predicted, partial)
		t.near("resumed collapse uses only safe elapsed case %s" % predicted, float(state.elapsed_s), partial)
	# Finish by safe elapsed, after the two held intervals exceeded authored duration.
	await _advance_for(dstate, fill_s - partial + 1.0 / Engine.physics_ticks_per_second)
	_sample_geometry(state, "completed after clearance holds", fill_s)
	t.check("completed permanent collapse releases capacity", _capacity_available(dstate))
	t.eq("completed permanent collapse stays LIVE", dstate.phase, Director.LIVE)
	await _real_ray("completed after clearance holds", 1.0)

func _capacity_available(dstate: Dictionary) -> bool:
	# A proposed row uses all other slots; the tested collapse must retain the last one.
	var candidate: Dictionary = dstate.duplicate(true)
	candidate.phase = Director.ANNOUNCED
	var occupied: Array[Dictionary] = []
	for i in range(Director.PARK_GROUND_CAP - 1):
		var other: Dictionary = dstate.duplicate(true)
		other.row.live_s = fill_s * 100.0
		occupied.append(other)
	var original: Array[Dictionary] = game.world.events._park_states
	var schedule: Array[Dictionary] = [dstate]
	schedule.append_array(occupied)
	game.world.events._park_states = schedule
	var allowed: bool = game.world.events._park_capacity(candidate)
	game.world.events._park_states = original
	return allowed

func _advance_for(dstate: Dictionary, seconds: float) -> void:
	var target := float(dstate.live_elapsed_s) + seconds
	game.world.set_physics_process(true)
	while float(dstate.live_elapsed_s) < target - 0.000001:
		await physics_frame
	game.world.set_physics_process(false)
