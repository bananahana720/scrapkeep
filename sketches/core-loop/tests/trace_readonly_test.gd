# smoke: solo timeout=360s (seven capped park lines, traced and untraced)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")
const TICKS := 6000
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon", "floor"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("trace_readonly_test")
	_check_observer(t)
	if t.failures > 0:
		quit(t.verdict())
		return
	var base := OS.get_user_data_dir().path_join("trace-readonly-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(base)
	var jobs := []
	for pilot in PILOTS:
		for mode in ["plain", "trace"]:
			var args := ["--table=park", "--stage=0", "--pilot=" + ("rivet" if pilot == "floor" else pilot),
				"--seeds=7", "--ticks=%d" % TICKS, "--out=" + base.path_join(pilot + "-" + mode)]
			if pilot == "floor":
				args.append("--floor")
			if mode == "trace":
				args.append("--trace")
			jobs.append({"script": "res://tools/traversal_line.gd", "args": args})
	# Four children at a time keep this fixture check within its shared CPU allocation.
	var results := []
	for i in range(0, jobs.size(), 4):
		results.append_array(ChildRuns.run(jobs.slice(i, i + 4), 85.0))
	for i in PILOTS.size():
		var pilot: String = PILOTS[i]
		var rows := []
		for j in 2:
			var mode := "plain" if j == 0 else "trace"
			var result: Dictionary = results[i * 2 + j]
			var errors: Array = ChildRuns.summary(result)["errors"]
			t.check("%s %s child completed" % [pilot, mode], result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
				"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors])
			var path := base.path_join(pilot + "-" + mode).path_join(pilot + ".json")
			var doc = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
			var runs: Array = doc.get("runs", []) if doc is Dictionary else []
			var row: Dictionary = runs[0] if runs.size() == 1 else {}
			t.check("%s %s measured every capped tick" % [pilot, mode], (int(row.get("ticks", 0)) == TICKS and row.get("outcome") == "ticks_done") or (int(row.get("ticks", 0)) > 0 and row.get("outcome") == "engaged"))
			rows.append(row)
		t.check("%s tracing leaves the full result byte-identical" % pilot, not rows[0].is_empty() and JSON.stringify(rows[0]) == JSON.stringify(rows[1]),
			"plain %s, trace %s; evidence %s" % [JSON.stringify(rows[0]).sha256_text(), JSON.stringify(rows[1]).sha256_text(), base])
	quit(t.verdict())


class ProbeTuning extends RefCounted:
	func f(_key: String) -> float:
		return 28.0


class ProbePlayer extends RefCounted:
	var state := {"velocity": Vector3.ZERO}
	var kit := {"mounted": false}
	var tuning := ProbeTuning.new()
	var _rigid: RigidBody3D

	func shown_position() -> Vector3:
		return Vector3.ZERO

	func planar_velocity() -> Vector3:
		return Vector3.ZERO

	func speed_tier() -> int:
		return 0

	func frozen() -> bool:
		return false


class ProbeContext extends RefCounted:
	var camera: ChaseCamera
	var origin_reads := 0

	func aim_origin() -> Vector3:
		origin_reads += 1
		return camera.aim_origin()

	func aim_forward() -> Vector3:
		return camera.aim_forward()


class ProbeFlow extends RefCounted:
	func state_name() -> String:
		return "travel"


# A trace must not draw global randomness even when a capped line has not used it yet.
# No physics or animation advances between the expected draw and the trace call.
func _check_observer(t) -> void:
	var player := ProbePlayer.new()
	player._rigid = RigidBody3D.new()
	player._rigid.contact_monitor = true
	root.add_child(player._rigid)
	var camera := ChaseCamera.new()
	root.add_child(camera)
	camera.setup(player, player.tuning)
	camera.set_process(false)
	var ctx := ProbeContext.new()
	ctx.camera = camera
	var game := {"player": player, "camera": camera, "ctx": ctx, "flow": ProbeFlow.new(),
		"run": {"stage_time": 0.0}, "events": GameEvents.new()}
	var sampler := TraversalLine.Sampler.new(game)
	seed(1234)
	var expected := randf()
	seed(1234)
	sampler._record_tick(player, Vector3.ZERO, true)
	t.eq("recording a trace leaves the next global RNG draw unchanged", randf(), expected)
	t.eq("the observer avoids the cache-filling gameplay aim origin accessor", ctx.origin_reads, 0)
	camera.position = Vector3(10, 4, -9)
	camera.rotation = Vector3(0.2, 0.25, -0.1)
	camera.scale = Vector3(1.2, 0.8, 1.5)
	camera.arm.rotation = Vector3(-0.3, 0.15, 0.2)
	camera.arm.scale = Vector3(1.1, 1.05, 0.95)
	(camera.cam.get_parent() as Node3D).position = Vector3(0, 0, 6.5)
	t.near("observed lens origin agrees with the composed rig pose", camera.peek_aim_origin().distance_to(camera.aim_origin()), 0.0, 0.00001)
	game["events"].free()
	sampler.game = null
	game.clear()
	camera.free()
	player._rigid.free()
