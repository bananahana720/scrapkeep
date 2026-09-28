extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# The gorge's cost, beside the Spillway's (W6 performance note). Counts the colliders,
# collision shapes, mesh instances, distinct materials and lights each stage's geometry
# adds (stage 2 includes its contraptions, terrain-event views and Moss's bay), then
# plays each stage live (enemies on, the ball rolling downstream) and records each
# frame's wall time, process and physics together, from Time.get_ticks_usec() between
# frames (Performance TIME_PROCESS refreshes about once a second, so its p99 was just
# its max). Headless frames here pace at about 6.9 ms (both stages' medians sat on it),
# so the median is that floor and the p99 and max are where a stage's work shows. The
# stages alternate in short blocks so machine load drifts over both alike.
#
# Gate: a gross-regression guard only. Stage 2's median stays within twice stage 1's
# plus 2 ms. The 60 Hz budget (16.7 ms) is reported against p99, not asserted: on this
# shared machine (other worktrees' Godot runs, load average near 20 on 32 cores) one
# stage-2 block measured a 5 ms median and the next 24 ms with nothing changed, so an
# absolute gate would be a coin flip.
#
# Evidence limit: headless, so no GPU or draw-call time is measured (mesh instances are
# the draw proxy); a real-window profile on Andrew's machine is the frame-time truth.

const BLOCKS := 4
const BLOCK_FRAMES := 150
const WARMUP := 30
const BUDGET_MS := 16.7

var _game
var _failures := 0
var _source := Intent.Scripted.new()
var _phase := "boot"
var _stages: Array = []
var _stage := 0
var _frames := 0
var _samples := {1: [], 2: []}
var _counted := {}
var _last_usec := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	match _phase:
		"boot":
			_game.player.source = _source
			_game.flow.press_start()
			_game.flow.choose_class(0)
			for i in BLOCKS:
				_stages.append_array([1, 2])
			_phase = "next"
		"next":
			if _stages.is_empty():
				return _finish()
			_stage = _stages.pop_front()
			_game.flow.enter_stage(_stage, Vector3.ZERO, false)
			_game.ctx.calm = false
			_source.hold = {"move": Vector2(0.0, 1.0)}
			_frames = 0
			_phase = "run"
		"run":
			_frames += 1
			# Keep the ball upright and moving toward the beacon so the frame sees play.
			var to_beacon: Vector3 = _game.flow.beacon.global_position - _game.player.ball_position()
			_game.camera.yaw = atan2(-to_beacon.x, -to_beacon.z)
			_game.run.heal(_game.run.max_hp)
			if _frames > WARMUP:
				_samples[_stage].append((Time.get_ticks_usec() - _last_usec) / 1000.0)
			_last_usec = Time.get_ticks_usec()
			if _frames >= WARMUP + BLOCK_FRAMES:
				if not _counted.has(_stage):
					_counted[_stage] = _counts(_stage)
				_phase = "next"
	return false


func _counts(stage: int) -> Dictionary:
	var roots: Array = [_game.ctx.terrain.geometry_root(stage)]
	if stage == 2:
		roots.append(_game.world.contraptions[2])
		roots.append(_game.world.terrain_view)
		roots.append(_game.world.bay)
	var out := {"bodies": 0, "shapes": 0, "meshes": 0, "materials": 0, "lights": 0}
	var mats := {}
	for r in roots:
		if r == null:
			continue
		out["bodies"] += (r as Node).find_children("*", "CollisionObject3D", true, false).size()
		out["shapes"] += (r as Node).find_children("*", "CollisionShape3D", true, false).size()
		out["lights"] += (r as Node).find_children("*", "Light3D", true, false).size()
		for m in (r as Node).find_children("*", "GeometryInstance3D", true, false):
			out["meshes"] += 1
			var mat = (m as GeometryInstance3D).material_override
			if mat == null and m is MeshInstance3D and (m as MeshInstance3D).mesh != null and (m as MeshInstance3D).mesh.get_surface_count() > 0:
				mat = (m as MeshInstance3D).mesh.surface_get_material(0)
			if mat != null:
				mats[mat.get_instance_id()] = true
	out["materials"] = mats.size()
	return out


static func _stats(samples: Array) -> Dictionary:
	var s := samples.duplicate()
	s.sort()
	var n := s.size()
	return {"p50": s[n / 2], "p99": s[mini(n - 1, int(n * 0.99))], "max": s[n - 1], "n": n}


func _finish() -> bool:
	var times := {}
	for stage in [1, 2]:
		var c: Dictionary = _counted[stage]
		var t: Dictionary = _stats(_samples[stage])
		times[stage] = t
		_report("stage %d cost" % stage, true, "%d bodies, %d shapes, %d mesh instances, %d materials, %d lights; wall time per frame over %d frames: p50 %.2f ms, p99 %.2f ms, max %.2f ms"
			% [c["bodies"], c["shapes"], c["meshes"], c["materials"], c["lights"], t["n"], t["p50"], t["p99"], t["max"]])
	var t1: Dictionary = times[1]
	var t2: Dictionary = times[2]
	_report("stage 2 costs no more than twice stage 1", t2["p50"] <= t1["p50"] * 2.0 + 2.0,
		"median %.2f ms against stage 1's %.2f ms; p99 %.2f ms against the %.1f ms 60 Hz frame (reported, not gated: headless CPU on a shared machine)"
			% [t2["p50"], t1["p50"], t2["p99"], BUDGET_MS])
	print("stage_gorge_perf_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
