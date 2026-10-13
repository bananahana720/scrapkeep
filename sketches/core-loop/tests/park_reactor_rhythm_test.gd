# smoke: solo timeout=180s
extends SceneTree
const Game = preload("res://src/game.gd")
const Intent = preload("res://src/movement/intent.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Warden = preload("res://src/combat/warden.gd")
const Posture = preload("res://src/combat/boss_posture.gd")
const Run = preload("res://src/core/run_state.gd")
const Tuning = preload("res://src/movement/tuning.gd")
const Combat = preload("res://src/combat/combat.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_rhythm_test")
var game
func _initialize() -> void: _run.call_deferred()
func _setup(heft: float) -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.player.source = Intent.Scripted.new()
	game.ctx.spawner.heft_override = heft
	for i in 40: await physics_frame
func _run() -> void:
	await _setup(Run.HEFT_CLASS_AT[2])
	var w = game.flow.warden
	var sheet = w.mount_driver
	var p = w._posture
	p.posture = Posture.FULL * 0.5
	p.idle = Posture.DRAIN_DELAY + Warden.PULSE_CYCLE
	sheet.on_pulse(w, false)
	var before: float = p.posture
	for i in roundi(Reactor.SHEET_SECONDS * Engine.physics_ticks_per_second) - 2: await physics_frame
	t.near("posture never regenerates during live sheet", p.posture, before)
	for i in roundi((Posture.DRAIN_DELAY + 0.5) * Engine.physics_ticks_per_second): await physics_frame
	t.check("dry state retains regeneration", p.posture < before, str(p.posture))
	game.free()
	await physics_frame
	var grown: Dictionary = await _cycles(Run.HEFT_CLASS_AT[2], "grown")
	var small: Dictionary = await _cycles(Run.HEFT_CLASS_AT[0], "small")
	t.eq("three landed sheet rams break grown Warden", grown.rams, 3)
	t.check("grown Warden breaks on third sheet ram", grown.broken and not grown.early, str(grown))
	t.check("small also breaks", small.broken, str(small))
	t.check("small takes at least twice grown time on dam", grown.seconds > 0.0 and small.seconds >= 2.0 * grown.seconds, "small %s, grown %s" % [small, grown])
	await _setup(Run.HEFT_CLASS_AT[2])
	w = game.flow.warden
	sheet = w.mount_driver
	var at: Vector3 = w.family_point_at() + Vector3.FORWARD * (w.FAMILY_POINT_RADIUS + Tuning.RADIUS + Tuning.RADIUS)
	game.player.reset_to(at, Vector3.BACK * game.player.tuning.f("cruise"))
	var dry_hits = []
	game.events.enemy_struck.connect(func(enemy, kind, force):
		if enemy == w and kind == "ram": dry_hits.append([force, w.posture()]))
	for i in 30:
		w._pulse_clock = 0.0
		await physics_frame
	t.check("dry-face solver ram occurred", not dry_hits.is_empty(), str(dry_hits))
	if not dry_hits.is_empty():
		var punch: float = (Combat.STRIKE_DAMAGE.ram[0] + dry_hits[0][0] * Combat.STRIKE_DAMAGE.ram[1]) * Run.HEFT_CLASS_AT[2]
		var expected: float = w._posture.base.ram * pow(clampf(punch / w.plating_for("ram", ""), w._posture.mult_min, w._posture.mult_max), w._posture.curve)
		t.near("dry-face contact keeps today's gain", w.posture(), expected)
	game.free()
	quit(t.verdict())
func _cycles(heft: float, label: String) -> Dictionary:
	await _setup(heft)
	var w = game.flow.warden
	var sheet = w.mount_driver
	var contacts = []
	var solved = []
	var result = {"broken": false, "early": false, "rams": 0, "seconds": 0.0}
	game.player.body().enemy_touched.connect(func(enemy, _normal):
		if enemy == w: solved.append(game.player.ball_position()))
	game.events.enemy_struck.connect(func(enemy, kind, force):
		if enemy == w and kind == "ram": contacts.append([force, game.player.ball_position()]))
	game.events.beacon_unsealed.connect(func(_stage): result.broken = true)
	var started: float = game.run.stage_time
	var last_cycle := -1
	for tick in roundi(Warden.PULSE_CYCLE * 20 * Engine.physics_ticks_per_second):
		if result.broken: break
		if sheet.sheet_live() and sheet.gates_opened != last_cycle:
			last_cycle = sheet.gates_opened
			var foot: Vector3 = w.home + sheet.sheet_dir * (Reactor.SHEET_RUN - Tuning.RADIUS)
			game.player.reset_to(game.ctx.terrain.drop_point(foot.x, foot.z, Tuning.RADIUS), -sheet.sheet_dir * game.player.tuning.f("cruise"))
		elif not sheet.sheet_live():
			var wait: Vector3 = w.home + Vector3.FORWARD * Reactor.SHEET_RUN
			game.player.reset_to(game.ctx.terrain.drop_point(wait.x, wait.z, Tuning.RADIUS), Vector3.ZERO)
		await physics_frame
		if result.broken and contacts.size() < 3: result.early = true
	result.rams = contacts.size()
	result.seconds = game.run.stage_time - started
	t.check(label + " sheet rams came from aligned solver contacts", not solved.is_empty() and contacts.all(func(row): return row[1].distance_to(w.family_point_at()) <= w.FAMILY_POINT_RADIUS + Tuning.RADIUS + 0.01), str(contacts))
	game.free()
	await physics_frame
	return result
