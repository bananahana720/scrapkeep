extends SceneTree
# 2026-10-22 (MOTION-SPEC row 217): the frame-strip options of tools/look_harness.gd and
# tools/look_subjects.gd, headless: --frames/--fps and the pose overrides parse and refuse what they
# should, each frame's record carries index, time and the overrides, and on a booted game the strip
# step advances the roll, the gyro and the squash between consecutive frames while the held pose
# (pod yaw, contact normal, hooked anchor) stays applied. The planted control runs the same measure
# on a strip whose steps are skipped and requires it to report "not advanced".
const Subjects := preload("res://tools/look_subjects.gd")
const Harness := preload("res://tools/look_harness.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("look_frames_test")
var _game
var _ticks := 0


func _initialize() -> void:
	_run.call_deferred()


func _physics_process(_delta: float) -> bool:
	_ticks += 1
	return false


func _run() -> void:
	_parse_checks()
	await _game_checks()
	quit(_t.verdict())


func _parse_checks() -> void:
	var still := Subjects.frame_options(["--out=/x", "--subject=a"])
	_t.eq("no strip flag is a still", [Subjects.is_strip(still), still["problems"]], [false, []])
	var o := Subjects.frame_options(["--frames=60", "--fps=60", "--speed=30", "--dir=1,0,0", "--pod-yaw=45", "--contact-normal=0,0,1",
		"--anchor-rel=0,6,-8", "--squash-tick=3", "--squash=0.4"])
	_t.eq("a full strip parses clean", o["problems"], [])
	_t.eq("frames, fps, speed, yaw, squash", [o["frames"], o["fps"], o["speed"], o["pod_yaw"], o["squash_tick"], o["squash"]], [60, 60.0, 30.0, 45.0, 3, 0.4])
	_t.eq("vectors parse", [o["dir"], o["contact_normal"], o["anchor_rel"]], [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 6, -8)])
	_t.check("an override without --frames is refused", not Subjects.frame_options(["--speed=30"])["problems"].is_empty())
	_t.check("--fps without --frames is refused", not Subjects.frame_options(["--fps=60"])["problems"].is_empty())
	_t.check("--frames=0 alone is a still", Subjects.frame_options(["--frames=0"])["problems"].is_empty())
	_t.check("a negative count is refused", not Subjects.frame_options(["--frames=-2"])["problems"].is_empty())
	_t.check("a count over the cap is refused", not Subjects.frame_options(["--frames=601"])["problems"].is_empty())
	_t.check("fps 0 is refused", not Subjects.frame_options(["--frames=3", "--fps=0"])["problems"].is_empty())
	_t.check("a two-part vector is refused", not Subjects.frame_options(["--frames=3", "--dir=1,2"])["problems"].is_empty())
	_t.check("a zero normal is refused", not Subjects.frame_options(["--frames=3", "--contact-normal=0,0,0"])["problems"].is_empty())
	_t.check("--squash without --squash-tick is refused", not Subjects.frame_options(["--frames=3", "--squash=0.2"])["problems"].is_empty())
	_t.check("both anchors are refused", not Subjects.frame_options(["--frames=3", "--anchor=1,2,3", "--anchor-rel=1,2,3"])["problems"].is_empty())
	var tangent := Subjects.travel_dir({"dir": Vector3(0, 0, -1), "contact_normal": Vector3(1, 0, -1)})
	_t.near("travel along a wall is tangent to its normal", tangent.dot(Vector3(1, 0, -1).normalized()), 0.0)
	var rows: Array = []
	for i in 60:
		rows.append(Subjects.frame_row(o, i))
	var times_rise := true
	for i in range(1, rows.size()):
		times_rise = times_rise and rows[i]["time"] > rows[i - 1]["time"] and rows[i]["index"] == i
	_t.check("N rows with rising time and index", rows.size() == 60 and times_rise)
	_t.near("frame 59 is 59/60 s", rows[59]["time"], 59.0 / 60.0, 0.00001)
	_t.near("squash ticks advance 1.5 per 60 fps frame", rows[2]["overrides"]["squash_ticks_since"], 3.0 + 3.0)
	_t.eq("row records the applied overrides", [rows[0]["overrides"]["pod_yaw"], rows[0]["overrides"]["speed"], rows[0]["fps"]], [45.0, 30.0, 60.0])
	var json: Variant = JSON.parse_string(JSON.stringify(rows[0]))
	_t.check("a row survives JSON as plain data", json is Dictionary and json["overrides"]["dir"] is Array)
	var turn := Subjects.spin_step({"speed": 30.0, "fps": 60.0}, 1.0 / 60.0)
	_t.near("a 30 m/s frame turns v dt / r", turn.get_rotation_quaternion().get_angle(), 30.0 / 60.0 / Tuning.RADIUS, 0.0001)
	_t.eq("no speed, no spin", Subjects.spin_step({"fps": 60.0}, 1.0 / 60.0), Basis.IDENTITY)
	_t.check("rolling forward (-Z) on a floor turns about -X", (turn * Vector3.UP).z < 0.0 and absf(turn.get_euler().x) > 0.0, str(turn * Vector3.UP))


# Boots the game as look_harness._boot does, then runs strips through the harness's own step.
func _game_checks() -> void:
	seed(280928)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	await process_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.player.source = Intent.Scripted.new()
	for i in 90:
		await physics_frame
	_game.player.body().freeze = true
	var player = _game.player
	var rig := {"player": player, "mesh": player.roll_node().get_parent(), "juice": _game.presentation.juice, "hero": _game.presentation.hero_assets,
		"line_view": _game.presentation.line_view, "pod": _game.presentation.hero_assets.shell_of(player).get("pod")}
	_t.check("the booted game has a pod to steer", rig["pod"] != null)
	var at: Vector3 = player.ball_position()
	paused = true

	var o := Subjects.frame_options(["--frames=8", "--fps=60", "--speed=30", "--dir=0,0,-1", "--pod-yaw=45", "--contact-normal=1,0,0",
		"--anchor-rel=0,6,-8", "--squash-tick=3", "--squash=0.4"])
	var live := _strip(rig, o, at, true)
	_t.eq("the strip records 8 frames", live["bases"].size(), 8)
	_t.check("consecutive frames advance the roll", _roll_advances(live["bases"], 30.0 / 60.0 / Tuning.RADIUS), "per-frame turns %s" % [live["turns"]])
	_t.check("the squash moves between frames", _varies(live["squash"]), str(live["squash"]))
	_t.check("the squash starts mid-swing, not at rest", absf(live["squash"][0]) > 0.001 and absf(live["squash"][0]) < 0.4, str(live["squash"][0]))
	_t.check("the pod yaw override holds on every frame", live["yaws"].all(func(y): return absf(y - deg_to_rad(45.0)) < 0.0001), str(live["yaws"]))
	_t.check("the contact normal is applied", player.state.contact_normal.is_equal_approx(Vector3(1, 0, 0)) and player.state.grounded)
	_t.check("the anchor is hooked at the offset", player.kit.hooked and player.kit.anchor.is_equal_approx(at + Vector3(0, 6, -8)), str(player.kit.anchor))
	_t.check("the lattice (core) turns between frames", _varies(live["gyro"]), str(live["gyro"]))

	var still_o := Subjects.frame_options(["--frames=8", "--fps=60"])
	var at_rest := _strip(rig, still_o, at, true)
	_t.check("no speed is no roll across the strip", not _roll_advances(at_rest["bases"], 0.001))

	# Planted control: the same strip with every step skipped must read as "not advanced".
	var frozen := _strip(rig, o, at, false)
	_t.check("PLANTED: a strip whose frames are not stepped fails the roll check", not _roll_advances(frozen["bases"], 30.0 / 60.0 / Tuning.RADIUS))
	_t.check("PLANTED: a strip whose frames are not stepped fails the squash check", not _varies(frozen["squash"]))
	_t.check("PLANTED: a strip whose frames are not stepped fails the lattice check", not _varies(frozen["gyro"]))
	paused = false
	_game.free()


# One strip on the harness's own begin and step. step=false is the planted control.
func _strip(rig: Dictionary, o: Dictionary, at: Vector3, step: bool) -> Dictionary:
	Harness.strip_begin(rig, o, at)
	var out := {"bases": [], "squash": [], "yaws": [], "gyro": [], "turns": []}
	var dt := 1.0 / float(o["fps"])
	var core = _game.presentation.hero_assets.shell_of(rig["player"]).get("core")
	for i in int(o["frames"]):
		if i > 0 and step:
			Harness.strip_step(rig, o, dt)
		out["bases"].append((rig["mesh"] as Node3D).basis)
		out["squash"].append(rig["juice"].squash_amount())
		out["yaws"].append((rig["pod"] as Node3D).rotation.y)
		out["gyro"].append((core as Node3D).global_basis.get_rotation_quaternion().get_angle() if core != null else 0.0)
		if i > 0:
			out["turns"].append(snappedf((out["bases"][i] * out["bases"][i - 1].inverse()).get_rotation_quaternion().get_angle(), 0.0001))
	return out


# True when every consecutive pair of frames turned by about `want` radians.
func _roll_advances(bases: Array, want: float) -> bool:
	for i in range(1, bases.size()):
		var a: float = (bases[i] * bases[i - 1].inverse()).get_rotation_quaternion().get_angle()
		if absf(a - want) > want * 0.05 + 0.0001:
			return false
	return bases.size() > 1


func _varies(values: Array) -> bool:
	for i in range(1, values.size()):
		if absf(values[i] - values[i - 1]) > 0.00001:
			return true
	return false
