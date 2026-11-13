# smoke: solo timeout=360s (seven capped park lines, traced and untraced)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")
const Counter := preload("res://src/combat/counter.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")
const TICKS := 900
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon", "floor"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("trace_readonly_test")
	_check_observer(t)
	_check_actor_sides(t)
	var base := OS.get_user_data_dir().path_join("trace-readonly-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(base)
	_check_actor_wiring(t, base)
	if t.failures > 0:
		quit(t.verdict())
		return
	var jobs := []
	for pilot in PILOTS:
		for mode in ["plain", "trace"]:
			var args := ["--table=park", "--stage=0", "--pilot=" + ("rivet" if pilot == "floor" else pilot),
				"--seeds=7", "--ticks=%d" % TICKS, "--child-timeout=65", "--out=" + base.path_join(pilot + "-" + mode)]
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

	func aim_origin() -> Vector3:
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

	game["events"].free()
	sampler.game = null
	game.clear()
	camera.free()
	player._rigid.free()


# The real Counter consumes the metadata in setup. Opposite object IDs form the
# planted control; retaining unrelated objects changes allocation history only.
func _check_actor_sides(t) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var actors: Array = []
	var noise: Array = []
	var first = Counter.new()
	actors.append(first)
	var opposite = null
	for i in 16:
		noise.append(RefCounted.new())
		var candidate = Counter.new()
		actors.append(candidate)
		if candidate.get_instance_id() % 2 != first.get_instance_id() % 2:
			opposite = candidate
			break
	t.check("actor allocation control found opposite object-ID parities", opposite != null)
	if opposite != null:
		for actor in [first, opposite]:
			world.add_child(actor)
			actor.setup(null, null, world, func(): return false, 1.0)
		t.check("unseeded Counter setup exposes allocation-dependent opposite directions", first._strafe != opposite._strafe)
		for actor in [first, opposite]:
			TraversalLine.replay_side(actor, "bot_strafe", 0, 7)
			actor.setup(null, null, world, func(): return false, 1.0)
		t.check("the same seed and spawn order give the real Counter the same direction", first._strafe == opposite._strafe)
		var scrap_a := Node.new()
		var scrap_b := Node.new()
		TraversalLine.replay_side(scrap_a, "bot_side", 0, 7)
		TraversalLine.replay_side(scrap_b, "bot_side", 0, 7)
		t.check("scrap side uses the same replay contract", scrap_a.has_meta("bot_side") and scrap_b.has_meta("bot_side") and scrap_a.get_meta("bot_side") == scrap_b.get_meta("bot_side"))
		scrap_a.free()
		scrap_b.free()
	for actor in actors:
		actor.free()
	world.free()


func _check_actor_wiring(t, base: String) -> void:
	var launcher := base.path_join("actor-wiring.gd")
	var file := FileAccess.open(launcher, FileAccess.WRITE)
	file.store_string("""extends "res://tools/traversal_line.gd"
const T := preload("res://tests/support/t.gd")
const Counter := preload("res://src/combat/counter.gd")
func _physics_process(_delta: float) -> bool:
	if _game == null or _game.build == null:
		return false
	var t := T.new("trace_actor_wiring")
	var ordinal := _counter_serial
	# Seed 7 alternates minus/plus from spawn zero, independently of replay_side.
	var expected: float = [-1.0, 1.0][ordinal % 2]
	var world := Node3D.new()
	root.add_child(world)
	var actor := Counter.new()
	world.add_child(actor)
	t.check("production node-added supplies bot_strafe before Counter.setup", actor.has_meta("bot_strafe"))
	t.eq("production node-added supplies the seed/spawn sign", actor.get_meta("bot_strafe", 0.0), expected)
	actor.setup(null, null, world, func(): return false, 1.0)
	t.eq("Counter.setup consumes the production node-added sign", actor._strafe, expected)
	world.free()
	quit(t.verdict())
	return true
""")
	file.close()
	var result: Dictionary = ChildRuns.run([{"script": launcher, "args": [
		"--child", "--table=park", "--stage=0", "--pilot=sable", "--seeds=7",
		"--ticks=1", "--out=" + base.path_join("actor-wiring")]}], 65.0)[0]
	print(String(result["log"]).strip_edges())
	var summary := ChildRuns.summary(result)
	t.check("production actor wiring child passes without a direct replay_side call", result["code"] == 0
		and not result["timed_out"] and summary["errors"].is_empty()
		and summary["verdict"] == "trace_actor_wiring: PASS",
		"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], summary["errors"]])
