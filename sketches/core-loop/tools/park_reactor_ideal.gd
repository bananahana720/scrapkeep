extends SceneTree

const Game = preload("res://src/game.gd")
const Intent = preload("res://src/movement/intent.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Warden = preload("res://src/combat/warden.gd")
const Run = preload("res://src/core/run_state.gd")
const Tuning = preload("res://src/movement/tuning.gd")
const SimClock = preload("res://src/core/sim_clock.gd")

class Observed extends Reactor.DamPosture:
	var records: Array = []
	func apply(result: Dictionary, frame: int) -> void:
		var before := posture
		super.apply(result, frame)
		var w = mounted_warden.get_ref()
		records.append({"t": w.fleet.ctx.run.stage_time, "frame": frame,
			"cycle": w.mount_driver.gates_opened, "sheet_ram": result.get("sheet_ram", false),
			"live": w.mount_driver.sheet_live(), "entered": w.mount_driver.entered_sheet_cycle,
			"solver_contact": w.target.body().get_colliding_bodies().has(w),
			"core": vec(w.family_point_at()), "kind": result.get("kind", "contact"),
			"gain": posture - before, "requested_gain": result.get("gain", 0.0),
			"posture": posture, "shatter": result.get("shatter", false),
			"heft": w.target.heft_of.call(), "punch": result.get("punch", 0.0), "plating": result.get("plating", 0.0),
			"position": vec(w.target.ball_position()), "velocity": vec(w.target.body().linear_velocity)})
	static func vec(v: Vector3) -> Array: return [v.x, v.y, v.z]

var game
var source = Intent.Scripted.new()
var out := ""
var seed_number := 1
var size := "grown"
var broken := false
var engaged_at := -1.0
var engaged_frame := -1
var breaking_frame := -1

func _initialize() -> void:
	SimClock.ticks = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--seed="): seed_number = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--size="): size = arg.trim_prefix("--size=")
	if out.is_empty() or size not in ["grown", "small"]:
		printerr("park_reactor_ideal: -- --out=DIR --size=grown|small --seed=N")
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.events.warden_engaged.connect(func(_stage):
		engaged_at = game.run.stage_time
		engaged_frame = Engine.get_physics_frames())
	game.ctx.rng.seed = 20260926 + seed_number * 7919
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.source = source
	var heft: float = Run.HEFT_CLASS_AT[2] if size == "grown" else Run.HEFT_CLASS_AT[0]
	game.run.grant_start_mass((heft - Run.HEFT_CLASS_AT[0]) / Run.HEFT_PER_MASS)
	for i in 40: await physics_frame
	var w = game.flow.warden
	var sheet = w.mount_driver
	var dir: Vector3 = sheet._face_heading(w)
	var foot: Vector3 = w.home + dir * (Reactor.SHEET_RUN - Tuning.RADIUS)
	game.player.reset_to(game.ctx.terrain.drop_point(foot.x, foot.z, Tuning.RADIUS), Vector3.ZERO)
	for i in 2: await physics_frame
	var observed = Observed.new(w.spec.get("posture", {}))
	for property in w._posture.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			observed.set(property.name, w._posture.get(property.name))
	w._posture = observed
	game.events.beacon_unsealed.connect(func(_stage):
		broken = true
		breaking_frame = Engine.get_physics_frames())
	var started: float = engaged_at
	assert(started >= 0.0 and game.flow.engaged())
	var trace = FileAccess.open(out.path_join("trace.ndjson"), FileAccess.WRITE)
	var sample_count := 0
	var first_frame := Engine.get_physics_frames()
	for tick in ceili(120.0 * Engine.physics_ticks_per_second):
		var ball: Vector3 = game.player.ball_position()
		var velocity: Vector3 = game.player.body().linear_velocity
		var has_ram: bool = observed.records.any(func(row): return row.sheet_ram and row.cycle == sheet.gates_opened)
		var until_pulse: float = w._charge_len - w._charge_time if w._charging else Warden.PULSE_CYCLE - w._pulse_clock
		var launching: bool = (sheet.sheet_live() and not has_ram) or (not sheet.sheet_live() and until_pulse <= 0.7)
		var target: Vector3 = w.family_point_at() if launching else foot
		var offset := Vector3(target.x - ball.x, 0.0, target.z - ball.z)
		var planar := Vector3(velocity.x, 0.0, velocity.z)
		var desired := offset.normalized() * minf(game.player.tuning.f("cruise"), offset.length() * 2.0)
		var change := desired - planar
		var wish := change.normalized() if change.length() > 0.5 else Vector3.ZERO
		var yaw: float = game.camera.yaw
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		source.hold = {"move": Vector2(wish.dot(right), wish.dot(forward))}
		if sheet.sheet_live() and not has_ram and ball.y >= w.family_point_at().y:
			source.hold["brake_held"] = true
		if game.player.state.grounded and offset.length() < Tuning.RADIUS * 2.0 and not launching:
			source.hold["brake_held"] = true
		if launching and -planar.dot(dir) >= game.player.tuning.f("cruise") * 0.35 and game.player.state.grounded and game.player.verb_ready("boost"):
			source.press["shift_pressed"] = true
		trace.store_line(JSON.stringify({"t": game.run.stage_time - started,
			"frame": Engine.get_physics_frames(), "broken": broken,
			"cycle": sheet.gates_opened, "live": sheet.sheet_live(), "riding": sheet.riding,
			"entered": sheet.entered_sheet_cycle, "rammed": has_ram,
			"inside": sheet.in_sheet(w, ball), "entry_speed": sheet._entry_speed,
			"until_pulse": until_pulse, "launching": launching,
			"p": Observed.vec(ball), "v": Observed.vec(velocity), "posture": w.posture(),
			"grounded": game.player.state.grounded, "pulse_clock": w._pulse_clock,
			"engaged": game.flow.engaged(), "move": [source.hold.move.x, source.hold.move.y]}))
		sample_count += 1
		if broken: break
		await physics_frame
	trace.close()
	var record := {"size": size, "seed": seed_number, "heft": game.run.heft(),
		"initial_heft": heft, "pilot": game.run.class_def.id, "calm": game.ctx.calm,
		"broken": broken, "seconds": game.run.stage_time - started,
		"started": started, "cycles": sheet.gates_opened, "contacts": observed.records,
		"first_frame": first_frame, "terminal_frame": Engine.get_physics_frames(), "sample_count": sample_count,
		"engaged_frame": engaged_frame, "breaking_frame": breaking_frame,
		"constants": {"pulse_cycle": Warden.PULSE_CYCLE, "sheet_seconds": Reactor.SHEET_SECONDS,
			"sheet_ram_breaks": Reactor.MOUNTED_POSTURE.sheet_ram_breaks,
			"grown_heft": Run.HEFT_CLASS_AT[2], "small_heft": Run.HEFT_CLASS_AT[0],
			"curve": observed.curve, "mult_min": observed.mult_min, "mult_max": observed.mult_max,
			"core_radius": Warden.FAMILY_POINT_RADIUS, "ball_radius": Tuning.RADIUS,
			"launch_lead": 0.7, "boost_closing_cruise_share": 0.35},
		"physics_hz": Engine.physics_ticks_per_second, "setup_resets": 1, "fight_resets": 0}
	var file = FileAccess.open(out.path_join("fight.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "  "))
	file.close()
	game.free()
	print("park_reactor_ideal: %s seed %d broken=%s seconds=%.6f contacts=%d" % [size, seed_number, broken, record.seconds, record.contacts.size()])
	quit(0 if broken else 1)
